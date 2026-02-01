import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/data/supabase/supabase_dashboard_service.dart';
import 'package:saber/pages/home/dashboard/widgets/ai_insights_card.dart';
import 'package:saber/pages/home/dashboard/widgets/live_queue_card.dart';
import 'package:saber/pages/home/dashboard/widgets/live_queue_list.dart';
import 'package:saber/pages/home/dashboard/widgets/quick_actions.dart';
import 'package:saber/pages/home/dashboard/widgets/stat_card.dart';
import 'package:saber/pages/home/dashboard/widgets/welcome_header.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  var _doctorName = '';
  String? _avatarUrl;
  RealtimeChannel? _consultationsSubscription;

  // Dashboard Data
  var _isLoading = true;
  var _stats = const DashboardStats(
    patientsToday: 0,
    pendingReports: 0,
    completedSessions: 0,
    totalConsultationMinutes: 0,
  );
  List<QueueItem> _queue = [];
  List<Appointment> _appointments = [];
  List<AIInsight> _insights = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
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
        .subscribe();
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
    debugPrint('Dashboard: Fetching dashboard stats/queue/appointments...');
    try {
      // Clean up past pending sessions first
      await SupabaseDashboardService.cancelPastPendingSessions();

      final results = await Future.wait([
        SupabaseDashboardService.getStats(),
        SupabaseDashboardService.getLiveQueue(),
        SupabaseDashboardService.getTodayAppointments(),
      ]);

      debugPrint(
        'Dashboard: Fetch complete. Stats: ${results[0]}, Queue: ${(results[1] as List).length}, Appts: ${(results[2] as List).length}',
      );

      if (mounted) {
        setState(() {
          _stats = results[0] as DashboardStats;
          _queue = results[1] as List<QueueItem>;
          _appointments = results[2] as List<Appointment>;
          // Fetch insights from service (currently mocked inside service)
          SupabaseDashboardService.getInsights().then((value) {
            if (mounted) setState(() => _insights = value);
          });
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _doctorName = data['full_name'] as String? ?? '';
          _avatarUrl = data['avatar_url'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile for dashboard: $e');
    }
  }

  Future<void> _handleStartSession(QueueItem item) async {
    try {
      // 1. Update status to in_progress
      await supabase
          .from('consultations')
          .update({
            'status': 'in_progress',
            'session_start_time': DateTime.now().toIso8601String(),
          })
          .eq('id', item.id);

      // 2. Create Session Files
      final patientId = item.patientId;
      
      final patientsDir = Directory(p.join(FileManager.documentsDirectory, 'patients', patientId));
      if (!patientsDir.existsSync()) {
        await patientsDir.create(recursive: true);
      }
      
      final sessionNotesDir = Directory(p.join(patientsDir.path, 'session_notes'));
      if (!sessionNotesDir.existsSync()) {
        await sessionNotesDir.create(recursive: true);
      }
      
      int nextSessionNumber = 1;
      try {
        final existing = sessionNotesDir.listSync();
        var maxNum = 0;
        for (var entity in existing) {
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
      final sessionDir = Directory(p.join(sessionNotesDir.path, sessionFolderName));
      await sessionDir.create();
      
      final documentName = 'session_${nextSessionNumber}_notes';
      final fullPath = p.join(sessionDir.path, '$documentName.sbn');
      
      // Navigate to editor
      // RoutePaths.editFilePath expects path relative to app's data logic if it's based on it,
      // but usually Editor accepts aboslute paths too?
      // Looking at RoutePaths.editFilePath implementation:
      // return '$edit?path=${Uri.encodeQueryComponent(filePath)}';
      // The Editor logic usually handles loading.
      // Based on patient_profile.dart, it passes:
      // '${patient!.documentFolderPath(DocumentType.sessionNote)}/$sessionFolderName/$documentName.sbn';
      // which is relative to documentsDirectory if patient.localFolderPath is relative.
      // patient.localFolderPath => '/patients/$id'
      // So passed path starts with /patients/...
      // Relative path calculation:
      
      final relativePath = p.relative(fullPath, from: FileManager.documentsDirectory);
      // Ensure it starts with / if needed, or if Editor handles relative paths correctly.
      // PatientProfile uses path starting with /patients/...
      // p.relative might return 'patients/...' (without leading /).
      
      final pathForRoute = relativePath.startsWith('/') ? relativePath : '/$relativePath';

      if (mounted) {
        // Pass consultation ID as a query parameter
        final route = RoutePaths.editFilePath(pathForRoute);
        final routeWithConsultation = '$route${route.contains('?') ? '&' : '?'}consultation_id=${item.id}';
        context.go(routeWithConsultation);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment cancelled')),
        );
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

  Future<void> _handleRescheduleAppointment(
      String consultationId, DateTime newTime) async {
    try {
      await SupabaseDashboardService.rescheduleAppointment(
          consultationId, newTime);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment rescheduled')),
        );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WelcomeHeader(
                    doctorName: _doctorName, avatarUrl: _avatarUrl),
                const SizedBox(height: 32),

                // Main Grid Layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
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
    );
  }

  Widget _buildMobileLayout(
    DashboardStats stats,
    List<QueueItem> queue,
    List<Appointment> appointments,
  ) {
    final waitingCount = queue.isEmpty ? 0 : queue.length - 1;
    final currentPatient = queue.isNotEmpty ? queue.first : null;

    return Column(
      children: [
        LiveQueueCard(
          waitingCount: waitingCount,
          currentPatient: currentPatient,
          onStartSession: currentPatient != null
              ? () => _handleStartSession(currentPatient)
              : () {},
          onViewProfile: currentPatient != null
              ? () => context.go(
                    RoutePaths.patientDetail
                        .replaceFirst(':patientId', currentPatient.patientId),
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
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(
    DashboardStats stats,
    List<QueueItem> queue,
    List<Appointment> appointments,
  ) {
    final waitingCount = queue.isEmpty ? 0 : queue.length - 1;
    final currentPatient = queue.isNotEmpty ? queue.first : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Main Actions & Queue)
        Expanded(
          flex: 2,
          child: Column(
            children: [
              LiveQueueCard(
                waitingCount: waitingCount,
                currentPatient: currentPatient,
                onStartSession: currentPatient != null
                    ? () => _handleStartSession(currentPatient)
                    : () {},
                onViewProfile: currentPatient != null
                    ? () => context.go(
                          RoutePaths.patientDetail
                              .replaceFirst(':patientId', currentPatient.patientId),
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(DashboardStats stats) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Patients Today',
            value: stats.patientsToday.toString(),
            icon: Icons.people_outline,
            trend: '+12%',
            isPositiveTrend: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            label: 'Total Time',
            value: '${stats.totalConsultationMinutes}m',
            icon: Icons.timer_outlined,
            color: Colors.orange,
            // trend: '-2m', // Trend logic removed for now
            isPositiveTrend: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildHistoryButton(context),
        ),
      ],
    );
  }

  Widget _buildHistoryButton(BuildContext context) {
    return Material(
      color: Colors.purple.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.go('/home/history'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          height: 100, // Approximate height to match StatCard
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history, color: Colors.purple),
              ),
              const SizedBox(height: 8),
              const Text(
                'History',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
