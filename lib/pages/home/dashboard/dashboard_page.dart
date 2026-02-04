import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/session_manager.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/data/supabase/supabase_dashboard_service.dart';
import 'package:saber/components/theming/premium_confirmation_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupRealtimeSubscription();
    stows.isOnline.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (stows.isOnline.value && mounted) {
      debugPrint('Dashboard: Internet restored, refreshing data...');
      _loadDashboardData();
      _setupRealtimeSubscription();
    }
  }

  @override
  void dispose() {
    stows.isOnline.removeListener(_onConnectivityChanged);
    if (_consultationsSubscription != null) {
      supabase.removeChannel(_consultationsSubscription!);
    }
    super.dispose();
  }

  void _setupRealtimeSubscription() {
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
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) _setupRealtimeSubscription();
            });
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
    debugPrint('Dashboard: Fetching data from Supabase...');
    try {
      // Clean up past pending sessions first
      await SupabaseDashboardService.cancelPastPendingSessions();

      final results = await Future.wait([
        SupabaseDashboardService.getStats(),
        SupabaseDashboardService.getLiveQueue(),
        SupabaseDashboardService.getTodayAppointments(),
        SupabaseDashboardService.getActiveConsultation(),
      ]);

      if (!mounted) return;

      setState(() {
        _stats = results[0] as DashboardStats;
        _queue = results[1] as List<QueueItem>;
        _appointments = results[2] as List<Appointment>;
        _activeConsultation = results[3] as QueueItem?;
      });

      debugPrint(
        'Dashboard: UI Update triggered with ${_queue.length} queue items',
      );
    } catch (e, stack) {
      debugPrint('Dashboard: Error in _fetchDashboardData: $e\n$stack');
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
        context.push(route);
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
      await SupabaseDashboardService.cancelAppointment(consultationId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Appointment cancelled')));
        // Realtime subscription should handle the update, but we can force fetch too
        _fetchDashboardData();
      }
    } catch (e) {
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: SafeArea(child: DashboardSkeleton()));
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WelcomeHeader(doctorName: _doctorName, avatarUrl: _avatarUrl),
                const SizedBox(height: 32),

                // Main Grid Layout
                Builder(
                  builder: (context) {
                    final width = MediaQuery.of(context).size.width;
                    if (width >= 1100) {
                      return _buildDesktopLayout(_stats, _queue, _appointments);
                    } else {
                      return _buildMobileLayout(_stats, _queue, _appointments);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // If each card would be less than 160px wide, wrap them
        final useVertical = constraints.maxWidth < 480;

        if (useVertical) {
          return Column(
            children: [
              StatCard(
                label: 'Consultations Done',
                value: stats.consultationsToday.toString(),
                icon: Icons.check_circle_outline,
                trend: formatTrend(stats.consultationsTrend),
                isPositiveTrend: (stats.consultationsTrend ?? 0) >= 0,
              ),
              const SizedBox(height: 12),
              StatCard(
                label: 'Total Time',
                value: '${stats.totalConsultationMinutes}m',
                icon: Icons.timer_outlined,
                color: Colors.orange,
                trend: formatTrend(stats.timeTrend),
                isPositiveTrend: (stats.timeTrend ?? 0) >= 0,
              ),
              const SizedBox(height: 12),
              StatCard(
                label: 'History',
                value: 'View All',
                icon: Icons.history,
                color: Colors.purple,
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
                value: stats.consultationsToday.toString(),
                icon: Icons.check_circle_outline,
                trend: formatTrend(stats.consultationsTrend),
                isPositiveTrend: (stats.consultationsTrend ?? 0) >= 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Total Time',
                value: '${stats.totalConsultationMinutes}m',
                icon: Icons.timer_outlined,
                color: Colors.orange,
                trend: formatTrend(stats.timeTrend),
                isPositiveTrend: (stats.timeTrend ?? 0) >= 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'History',
                value: 'View All',
                icon: Icons.history,
                color: Colors.purple,
                onTap: () => context.go('/home/history'),
              ),
            ),
          ],
        );
      },
    );
  }
}
