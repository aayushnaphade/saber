import 'package:flutter/material.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/data/supabase/supabase_dashboard_service.dart';
import 'package:saber/pages/home/dashboard/widgets/ai_insights_card.dart';
import 'package:saber/pages/home/dashboard/widgets/appointment_timeline.dart';
import 'package:saber/pages/home/dashboard/widgets/live_queue_card.dart';
import 'package:saber/pages/home/dashboard/widgets/quick_actions.dart';
import 'package:saber/pages/home/dashboard/widgets/stat_card.dart';
import 'package:saber/pages/home/dashboard/widgets/welcome_header.dart';
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
  DashboardStats _stats = const DashboardStats(
    patientsToday: 0,
    pendingReports: 0,
    completedSessions: 0,
    averageTimePerPatient: 0,
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
          _insights = MockDashboardData.getInsights(); // Keep mock for now
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
          SnackBar(content: Text('Error cancelling appointment: $e')),
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
          SnackBar(content: Text('Error rescheduling appointment: $e')),
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
                WelcomeHeader(doctorName: _doctorName, avatarUrl: _avatarUrl),
                const SizedBox(height: 32),

                // Main Grid Layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      return _buildDesktopLayout(
                        _stats,
                        _queue,
                        _appointments,
                        _insights,
                      );
                    } else {
                      return _buildMobileLayout(
                        _stats,
                        _queue,
                        _appointments,
                        _insights,
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
    List<AIInsight> insights,
  ) {
    final waitingCount = queue.isEmpty ? 0 : queue.length - 1;
    final currentPatient = queue.isNotEmpty ? queue.first : null;

    return Column(
      children: [
        LiveQueueCard(
          waitingCount: waitingCount,
          currentPatient: currentPatient,
          onStartSession: () {},
          onCancel: currentPatient != null
              ? () => _handleCancelAppointment(currentPatient.id)
              : null,
        ),
        const SizedBox(height: 24),
        const QuickActions(),
        const SizedBox(height: 24),
        _buildStatsGrid(stats),
        const SizedBox(height: 24),
        AIInsightsCard(insights: insights),
        const SizedBox(height: 24),
        AppointmentTimeline(
          appointments: appointments,
          onCancel: _handleCancelAppointment,
          onReschedule: _handleRescheduleAppointment,
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(
    DashboardStats stats,
    List<QueueItem> queue,
    List<Appointment> appointments,
    List<AIInsight> insights,
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
                onStartSession: () {},
                onCancel: currentPatient != null
                    ? () => _handleCancelAppointment(currentPatient.id)
                    : null,
              ),
              const SizedBox(height: 24),
              _buildStatsGrid(stats),
              const SizedBox(height: 24),
              AppointmentTimeline(
                appointments: appointments,
                onCancel: _handleCancelAppointment,
                onReschedule: _handleRescheduleAppointment,
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right Column (Quick Actions & Insights)
        Expanded(
          flex: 1,
          child: Column(
            children: [
              const QuickActions(),
              const SizedBox(height: 24),
              AIInsightsCard(insights: insights),
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
            label: 'Avg. Time',
            value: '${stats.averageTimePerPatient}m',
            icon: Icons.timer_outlined,
            color: Colors.orange,
            trend: '-2m',
            isPositiveTrend: true,
          ),
        ),
      ],
    );
  }
}
