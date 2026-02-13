import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:saber/components/theming/premium_confirmation_dialog.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/session_manager.dart';
import 'package:saber/data/services/offline_dashboard_cache.dart';
import 'package:saber/data/services/sync_outbox.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/data/supabase/supabase_dashboard_service.dart';
import 'package:saber/pages/home/dashboard/dashboard_skeleton.dart';
import 'package:saber/pages/home/dashboard/widgets/live_queue_card.dart';
import 'package:saber/pages/home/dashboard/widgets/live_queue_list.dart';
import 'package:saber/pages/home/dashboard/widgets/stat_card.dart';
import 'package:saber/pages/home/dashboard/widgets/welcome_header.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  var _doctorName = stows.userDisplayName.value;
  String? _avatarUrl = stows.userAvatarUrl.value;
  RealtimeChannel? _consultationsSubscription;
  AudioPlayer? _audioPlayer;
  var _wasBusy = false;
  var _isFetching = false;

  // Dashboard Data
  var _isLoading = true;
  var _stats = const DashboardStats(
    consultationsToday: 0,
    pendingConsultations: 0,
    completedSessions: 0,
    totalConsultationMinutes: 0,
  );
  List<QueueItem> _queue = [];
  QueueItem? _activeConsultation;
  List<Appointment> _appointments = [];
  var _isStaleData = false;
  DateTime? _lastCacheTime;
  var _pendingSyncCount = 0;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _loadDashboardData();
    _setupRealtimeSubscription();
    stows.isOnline.addListener(_onConnectivityChanged);
    SessionManager().addListener(_onSessionStateChanged);
  }

  void _initAudioPlayer() {
    // audioplayers 6.x initializes asynchronously in the constructor.
    // We use runZonedGuarded to catch the MissingPluginException that may be thrown
    // from an unawaited future inside the AudioPlayer constructor.
    runZonedGuarded(
      () {
        try {
          final player = AudioPlayer();
          _audioPlayer = player;
        } catch (e) {
          debugPrint('Dashboard: Synchronous AudioPlayer creation failed: $e');
        }
      },
      (error, stack) {
        if (error.toString().contains('audioplayers') ||
            error is MissingPluginException) {
          debugPrint('Dashboard: AudioPlayer plugin is not available: $error');
          _audioPlayer = null; // Ensure we don't try to use a broken player
        } else {
          debugPrint('Dashboard: Unexpected AudioPlayer error: $error');
        }
      },
    );
  }

  void _onConnectivityChanged() {
    if (stows.isOnline.value && mounted) {
      debugPrint('Dashboard: Internet restored, refreshing data...');
      _loadDashboardData();
      _setupRealtimeSubscription();
    }
  }

  void _onSessionStateChanged() {
    // When a session is terminated (e.g. offline "Finish & Exit"),
    // refresh all dashboard data to clear the stale active consultation.
    if (!SessionManager().hasActiveSession && mounted) {
      debugPrint('Dashboard: Session terminated, refreshing data...');
      _loadDashboardData();
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    stows.isOnline.removeListener(_onConnectivityChanged);
    SessionManager().removeListener(_onSessionStateChanged);
    if (_consultationsSubscription != null) {
      supabase.removeChannel(_consultationsSubscription!);
    }
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    // Clean up existing channel if any
    if (_consultationsSubscription != null) {
      try {
        supabase.removeChannel(_consultationsSubscription!);
      } catch (e) {
        debugPrint('Dashboard: Error removing old channel: $e');
      }
      _consultationsSubscription = null;
    }

    // Only subscribe if we believe we are online
    if (!stows.isOnline.value) {
      debugPrint('Dashboard: Skipping Realtime subscription (offline)');
      return;
    }

    _consultationsSubscription = supabase
        .channel('public:consultations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'consultations',
          callback: (payload) {
            debugPrint('Dashboard: Realtime update received: $payload');
            _fetchDashboardData();
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint(
              'Dashboard: Realtime subscription timed out, retrying...',
            );
            // Only retry if we are still online and mounted
            if (mounted && stows.isOnline.value) {
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted && stows.isOnline.value) {
                  _setupRealtimeSubscription();
                }
              });
            }
          } else if (status == RealtimeSubscribeStatus.closed ||
              status == RealtimeSubscribeStatus.channelError) {
            debugPrint('Dashboard: Realtime status: $status. Error: $error');
            // Improved Retry logic for channel errors
            if (mounted && stows.isOnline.value) {
              debugPrint('Dashboard: Retrying Realtime subscription in 10s...');
              Future.delayed(const Duration(seconds: 10), () {
                if (mounted && stows.isOnline.value) {
                  _setupRealtimeSubscription();
                }
              });
            }
          }
        });
  }

  Future<void> _loadDashboardData() async {
    debugPrint('Dashboard: Starting data load...');
    try {
      await Future.wait([_fetchProfile(), _fetchDashboardData()]);
    } catch (e) {
      debugPrint('Dashboard: Error in _loadDashboardData: $e');
    } finally {
      if (mounted) {
        debugPrint('Dashboard: Data load complete, setting isLoading = false');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchDashboardData() async {
    if (_isFetching) return;
    _isFetching = true;

    debugPrint('Dashboard: Fetching data from Supabase...');
    try {
      // Clean up past pending sessions first
      await SupabaseDashboardService.cancelPastPendingSessions();

      final results = await Future.wait([
        SupabaseDashboardService.getStats(),
        SupabaseDashboardService.getLiveQueue(),
        SupabaseDashboardService.getTodayAppointments(),
        SupabaseDashboardService.getActiveConsultations(),
      ]);

      if (!mounted) return;

      // Destructure the new record types
      final statsResult = results[0] as ({DashboardStats stats, bool isStale});
      final queueResult = results[1] as ({List<QueueItem> items, bool isStale});
      final appointmentsResult =
          results[2] as ({List<Appointment> items, bool isStale});

      final activeList = (results[3] as List).cast<QueueItem>();

      // Cross-reference with outbox: filter out consultations that were
      // locally completed but not yet synced to Supabase.
      final locallyCompleted =
          await SyncOutbox.getLocallyCompletedConsultationIds();

      QueueItem? effectiveActive;
      // Pick the first one that is NOT locally completed
      for (final item in activeList) {
        if (!locallyCompleted.contains(item.id)) {
          effectiveActive = item;
          break; // Only support one active session at a time in UI
        }
      }

      final isNowBusy = effectiveActive != null;

      // Play SFX if transitioning from Busy to Available in Reception Mode
      if (_wasBusy && !isNowBusy && stows.receptionMode.value) {
        debugPrint('Dashboard: Doctor is now available, playing SFX');
        _audioPlayer?.play(AssetSource('doc_available_sfx.mp3')).catchError((
          e,
        ) {
          debugPrint('Dashboard: Failed to play SFX: $e');
        });
      }
      _wasBusy = isNowBusy;

      // Determine if any data source returned stale (cached) data
      final anyStale =
          statsResult.isStale ||
          queueResult.isStale ||
          appointmentsResult.isStale;

      // Filter locally completed items from the waiting queue too
      final effectiveQueue = locallyCompleted.isEmpty
          ? queueResult.items
          : queueResult.items
                .where((q) => !locallyCompleted.contains(q.id))
                .toList();

      if (locallyCompleted.isNotEmpty) {
        debugPrint(
          'Dashboard: Filtered ${locallyCompleted.length} locally-completed '
          'consultations from server data',
        );
      }

      setState(() {
        _stats = statsResult.stats;
        _queue = effectiveQueue;
        _appointments = appointmentsResult.items;
        _activeConsultation = effectiveActive;
        _isStaleData = anyStale;
      });

      // Update last cache time if we're showing stale data
      if (anyStale) {
        final cacheTime = await OfflineDashboardCache.lastCacheTime();
        if (mounted) {
          setState(() => _lastCacheTime = cacheTime);
        }
      } else {
        if (mounted && _isStaleData) {
          setState(() => _isStaleData = false);
        }
      }

      // Fetch pending outbox count
      final pendingCount = await SyncOutbox.pendingCount();
      if (mounted) {
        setState(() => _pendingSyncCount = pendingCount);
      }
      debugPrint(
        'Dashboard: UI Update triggered with ${_queue.length} queue items'
        '${anyStale ? ' (stale data)' : ''}',
      );
    } catch (e, stack) {
      debugPrint('Dashboard: Error in _fetchDashboardData: $e\n$stack');
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('profiles')
          .select('full_name, avatar_url, role')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _doctorName = data['full_name'] as String? ?? '';
          _avatarUrl = data['avatar_url'] as String?;

          // Cache to stows for offline persistence
          stows.userDisplayName.value = _doctorName;
          stows.userAvatarUrl.value = _avatarUrl;
          if (data['role'] != null) {
            stows.userRole.value = data['role'] as String;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile for dashboard: $e');
    }
  }

  Future<void> _handleStartSession(QueueItem item) async {
    // 0. Check for existing active session
    if (SessionManager().hasActiveSession) {
      final activePatientId = SessionManager().patientId;
      final activePatientName = SessionManager().patientName;

      if (activePatientId == item.patientId) {
        // Offer to restore
        if (mounted) {
          final restore = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Session Already Active'),
              content: Text(
                'A session for ${item.patientName} is already active but was minimized.\n\nWould you like to continue the existing session?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('New Session'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Continue'),
                ),
              ],
            ),
          );

          if (restore ?? false) {
            SessionManager().restore();
            // Navigate to the existing session
            if (mounted) {
              final activeSession = SessionManager().activeSession;
              if (activeSession != null) {
                final relativePath = p.relative(
                  activeSession.filePath,
                  from: FileManager.documentsDirectory,
                );
                final pathForRoute = relativePath.startsWith('/')
                    ? relativePath
                    : '/$relativePath';
                final route = RoutePaths.editFilePath(pathForRoute);
                // Combine existing query parameters if any
                final routeWithConsultation =
                    '$route${route.contains('?') ? '&' : '?'}consultation_id=${SessionManager().consultationId}';
                context.push(routeWithConsultation);
                return;
              }
            }
          } else if (restore == null) {
            return; // Backed out of dialog
          }
          // If restore is false, we proceed to start a new session (the dialog says "New Session")
          // But first we should terminate the old one to avoid multiple active sessions
          SessionManager().terminate();
        }
      } else {
        if (mounted) {
          // If name is missing but we have an ID, try to look it up from the queue or appointments locally
          String displayPatientName = activePatientName ?? 'another patient';
          if (activePatientName == null && activePatientId != null) {
            // Try to find in queue
            final inQueue = _queue
                .where((q) => q.patientId == activePatientId)
                .firstOrNull;
            if (inQueue != null) {
              displayPatientName = inQueue.patientName;
            } else {
              // Try appointments
              final inAppt = _appointments
                  .where((a) => a.patientId == activePatientId)
                  .firstOrNull;
              if (inAppt != null) {
                displayPatientName = inAppt.patientName;
              }
            }
          }

          // If still unknown, and we have an ID, maybe async fetch?
          // For now, simpler UI that allows breaking the lock is better.

          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Session In Progress'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A session is already active for "$displayPatientName".',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You must end the current session before starting a new one.',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    // Resume the OTHER session
                    Navigator.pop(context);
                    SessionManager().restore();
                    final activeSession = SessionManager().activeSession;
                    if (activeSession != null) {
                      final relativePath = p.relative(
                        activeSession.filePath,
                        from: FileManager.documentsDirectory,
                      );
                      final pathForRoute = relativePath.startsWith('/')
                          ? relativePath
                          : '/$relativePath';
                      final route = RoutePaths.editFilePath(pathForRoute);
                      final routeWithConsultation =
                          '$route${route.contains('?') ? '&' : '?'}consultation_id=${SessionManager().consultationId}';
                      context.push(routeWithConsultation);
                    }
                  },
                  child: const Text('Resume Active'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // Terminate old, start new
                    SessionManager().terminate();
                    _handleStartSession(item); // Retry starting the new one
                  },
                  child: const Text('Terminate & Start New'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    // 0.5. Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => PremiumConfirmationDialog(
        title: 'Start Session',
        content: 'Start consultation for ${item.patientName}?',
        confirmLabel: 'Start',
        icon: Icons.medical_services_outlined,
        iconColor: Theme.of(context).colorScheme.primary,
      ),
    );

    if (confirm != true) return;

    try {
      // 1. Update status to in_progress
      await supabase
          .from('consultations')
          .update({
            'status': 'in_progress',
            'session_start_time': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', item.id);

      // 2. Create Session Files
      final patientId = item.patientId;

      final patientsDir = Directory(
        p.join(FileManager.documentsDirectory, 'patients', patientId),
      );
      if (!patientsDir.existsSync()) {
        await patientsDir.create(recursive: true);
      }

      final sessionNotesDir = Directory(
        p.join(patientsDir.path, 'session_notes'),
      );
      if (!sessionNotesDir.existsSync()) {
        await sessionNotesDir.create(recursive: true);
      }

      int nextSessionNumber = 1;
      try {
        final existing = sessionNotesDir.listSync();
        var maxNum = 0;
        for (final entity in existing) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            if (name.startsWith('session_')) {
              final num = int.tryParse(name.replaceAll('session_', ''));
              if (num != null && num > maxNum) maxNum = num;
            }
          }
        }
        nextSessionNumber = maxNum + 1;
      } catch (e) {
        // ignore
      }

      final sessionFolderName = 'session_$nextSessionNumber';
      final sessionDir = Directory(
        p.join(sessionNotesDir.path, sessionFolderName),
      );
      await sessionDir.create();

      final documentName = 'session_${nextSessionNumber}_notes';
      final fullPath = p.join(sessionDir.path, '$documentName.sbn');

      // Navigate to editor
      final relativePath = p.relative(
        fullPath,
        from: FileManager.documentsDirectory,
      );
      final pathForRoute = relativePath.startsWith('/')
          ? relativePath
          : '/$relativePath';

      if (mounted) {
        // Pass consultation ID as a query parameter
        final route = RoutePaths.editFilePath(
          pathForRoute,
          consultationId: item.id,
          patientName: item.patientName,
          patientId: item.patientId,
        );
        if (context.mounted) {
          context.push(route);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _handleCancelAppointment(String consultationId) async {
    try {
      // If the cancelled appointment is the currently active/minimized session, clean it up
      if (SessionManager().consultationId == consultationId) {
        await SessionManager().deleteActiveSessionFiles();
        SessionManager().terminate();
      }

      await SupabaseDashboardService.cancelAppointment(consultationId);
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Appointment cancelled')));
        // Realtime subscription should handle the update, but we can force fetch too
        _fetchDashboardData();
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _queue.removeAt(oldIndex);
      _queue.insert(newIndex, item);
    });

    try {
      // Prepare updates for the database
      final List<Map<String, dynamic>> updates = [];
      for (int i = 0; i < _queue.length; i++) {
        updates.add({'id': _queue[i].id, 'queue_order': i + 1});
      }
      await SupabaseDashboardService.updateQueueOrder(updates);
    } catch (e) {
      debugPrint('Error updating queue order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update queue order: $e')),
        );
        // Refresh to revert to server state
        _fetchDashboardData();
      }
    }
  }

  Widget _buildStaleDataBanner() {
    String timeAgo = '';
    if (_lastCacheTime != null) {
      final diff = DateTime.now().difference(_lastCacheTime!);
      if (diff.inMinutes < 1) {
        timeAgo = 'just now';
      } else if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes} min ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inDays}d ago';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.amber.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Showing cached data'
              '${timeAgo.isNotEmpty ? ' • Last synced $timeAgo' : ''}',
              style: TextStyle(
                color: Colors.amber.shade800,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            onTap: _loadDashboardData,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.refresh_rounded,
                color: Colors.amber.shade700,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSyncBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync_rounded, color: Colors.blue.shade600, size: 18),
          const SizedBox(width: 8),
          Text(
            '$_pendingSyncCount pending sync${_pendingSyncCount == 1 ? '' : 's'}',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: SafeArea(child: DashboardSkeleton()));
    }

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    WelcomeHeader(
                      doctorName: _doctorName,
                      avatarUrl: _avatarUrl,
                    ),
                    const SizedBox(height: 24),

                    // Stale data indicator (offline cache)
                    if (_isStaleData) _buildStaleDataBanner(),

                    // Pending sync indicator
                    if (_pendingSyncCount > 0) _buildPendingSyncBadge(),

                    // Doctor Status Indicator (for Reception Mode)
                    if (stows.receptionMode.value) ...[
                      _buildDoctorStatusIndicator(),
                      const SizedBox(height: 32),
                    ],

                    // Main Grid Layout
                    Builder(
                      builder: (context) {
                        final width = MediaQuery.of(context).size.width;
                        if (width >= 1100) {
                          return _buildDesktopLayout(
                            _stats,
                            _queue,
                            _appointments,
                          );
                        } else {
                          return _buildMobileLayout(
                            _stats,
                            _queue,
                            _appointments,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorStatusIndicator() {
    final isBusy = _activeConsultation != null;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isBusy
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
            : const Color(0xFFD1FAE5).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBusy
              ? theme.colorScheme.error.withValues(alpha: 0.2)
              : const Color(0xFF10B981).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isBusy ? theme.colorScheme.error : const Color(0xFF10B981),
              shape: BoxShape.circle,
              boxShadow: isBusy
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isBusy ? 'In Consultation' : 'Doctor Available',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isBusy
                      ? theme.colorScheme.onErrorContainer
                      : const Color(0xFF065F46),
                ),
              ),
              Text(
                isBusy
                    ? 'Consultation in progress with ${_activeConsultation?.patientName}'
                    : 'Ready for next patient',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isBusy
                      ? theme.colorScheme.onErrorContainer.withValues(
                          alpha: 0.7,
                        )
                      : const Color(0xFF047857).withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    DashboardStats stats,
    List<QueueItem> queue,
    List<Appointment> appointments,
  ) {
    final waitingCount =
        queue.length; // Queue only contains waiting patients now

    // Header Logic:
    // 1. If there is an active consultation, show it (Status: In Progress)
    // 2. Else if queue is not empty, show the next patient (Status: Waiting)
    // 3. Else null (Empty state)
    final currentPatient =
        _activeConsultation ?? (queue.isNotEmpty ? queue.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiveQueueCard(
          waitingCount: waitingCount,
          currentPatient: currentPatient,
          onStartSession: currentPatient != null
              ? () => _handleStartSession(currentPatient)
              : () {},
          onViewProfile: currentPatient != null
              ? () => context.push(
                  RoutePaths.patientDetail.replaceFirst(
                    ':patientId',
                    currentPatient.patientId,
                  ),
                )
              : null,
          onCancel: currentPatient != null
              ? () => _handleCancelAppointment(currentPatient.id)
              : null,
        ),
        const SizedBox(height: 24),
        _buildStatsGrid(stats),
        const SizedBox(height: 24),
        LiveQueueList(
          queue: queue,
          onStartSession: _handleStartSession,
          onCancel: (item) => _handleCancelAppointment(item.id),
          onReorder: _handleReorder,
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(
    DashboardStats stats,
    List<QueueItem> queue,
    List<Appointment> appointments,
  ) {
    final waitingCount = queue.length;
    final currentPatient =
        _activeConsultation ?? (queue.isNotEmpty ? queue.first : null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Active Patient & Live Queue List
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LiveQueueCard(
                waitingCount: waitingCount,
                currentPatient: currentPatient,
                onStartSession: currentPatient != null
                    ? () => _handleStartSession(currentPatient)
                    : () {},
                onViewProfile: currentPatient != null
                    ? () => context.push(
                        RoutePaths.patientDetail.replaceFirst(
                          ':patientId',
                          currentPatient.patientId,
                        ),
                      )
                    : null,
                onCancel: currentPatient != null
                    ? () => _handleCancelAppointment(currentPatient.id)
                    : null,
              ),
              const SizedBox(height: 24),
              LiveQueueList(
                queue: queue,
                onStartSession: _handleStartSession,
                onCancel: (item) => _handleCancelAppointment(item.id),
                onReorder: _handleReorder,
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right Column: Stats
        Expanded(flex: 2, child: _buildStatsGrid(stats)),
      ],
    );
  }

  Widget _buildStatsGrid(DashboardStats stats) {
    String formatTrend(double? trend) {
      if (trend == null || trend.abs() < 0.1) return '0%';
      final prefix = trend > 0 ? '+' : '';
      return '$prefix${trend.toStringAsFixed(1)}%';
    }

    return Builder(
      builder: (context) {
        final width = MediaQuery.of(context).size.width;
        final useVertical = width < 480;
        final isDesktop = width >= 1100;

        if (useVertical || isDesktop) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatCard(
                label: 'Consultations Done',
                value: '${stats.consultationsToday}',
                icon: Icons.check_circle_outline,
                color: Colors.green,
                trend: formatTrend(stats.consultationsTrend),
                isPositiveTrend: (stats.consultationsTrend ?? 0) >= 0,
              ),
              const SizedBox(height: 12),
              StatCard(
                label: 'Total Time',
                value: '${stats.totalConsultationMinutes}m',
                icon: Icons.access_time,
                color: Colors.orange,
                trend: formatTrend(stats.timeTrend),
                isPositiveTrend: (stats.timeTrend ?? 0) >= 0,
              ),
              const SizedBox(height: 12),
              StatCard(
                label: 'Consultation History',
                value: 'View History',
                icon: Icons.history_rounded,
                color: Colors.blue,
                onTap: () => context.go('/home/history'),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Consultations Done',
                value: '${stats.consultationsToday}',
                icon: Icons.check_circle_outline,
                color: Colors.green,
                trend: formatTrend(stats.consultationsTrend),
                isPositiveTrend: (stats.consultationsTrend ?? 0) >= 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Total Time',
                value: '${stats.totalConsultationMinutes}m',
                icon: Icons.access_time,
                color: Colors.orange,
                trend: formatTrend(stats.timeTrend),
                isPositiveTrend: (stats.timeTrend ?? 0) >= 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Consultation History',
                value: 'View History',
                icon: Icons.history_rounded,
                color: Colors.blue,
                onTap: () => context.go('/home/history'),
              ),
            ),
          ],
        );
      },
    );
  }
}
