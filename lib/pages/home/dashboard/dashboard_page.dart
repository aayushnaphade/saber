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

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  var _doctorName = '';
  String? _avatarUrl;

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
    return Column(
      children: [
        LiveQueueCard(
          waitingCount: queue.length - 1,
          currentPatient: queue.isNotEmpty ? queue.first : null,
          onStartSession: () {},
        ),
        const SizedBox(height: 24),
        const QuickActions(),
        const SizedBox(height: 24),
        _buildStatsGrid(stats),
        const SizedBox(height: 24),
        AIInsightsCard(insights: insights),
        const SizedBox(height: 24),
        AppointmentTimeline(appointments: appointments),
      ],
    );
  }

  Widget _buildDesktopLayout(
    DashboardStats stats,
    List<QueueItem> queue,
    List<Appointment> appointments,
    List<AIInsight> insights,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Main Actions & Queue)
        Expanded(
          flex: 2,
          child: Column(
            children: [
              LiveQueueCard(
                waitingCount: queue.length - 1,
                currentPatient: queue.isNotEmpty ? queue.first : null,
                onStartSession: () {},
              ),
              const SizedBox(height: 24),
              _buildStatsGrid(stats),
              const SizedBox(height: 24),
              AppointmentTimeline(appointments: appointments),
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
