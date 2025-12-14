import 'package:flutter/material.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/pages/home/dashboard/widgets/ai_insights_card.dart';
import 'package:saber/pages/home/dashboard/widgets/appointment_timeline.dart';
import 'package:saber/pages/home/dashboard/widgets/live_queue_card.dart';
import 'package:saber/pages/home/dashboard/widgets/quick_actions.dart';
import 'package:saber/pages/home/dashboard/widgets/stat_card.dart';
import 'package:saber/pages/home/dashboard/widgets/welcome_header.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock Data
    final stats = MockDashboardData.getStats();
    final queue = MockDashboardData.getLiveQueue();
    final appointments = MockDashboardData.getTodayAppointments();
    final insights = MockDashboardData.getInsights();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WelcomeHeader(doctorName: 'Adil Hanney'),
              const SizedBox(height: 32),

              // Main Grid Layout
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 900) {
                    return _buildDesktopLayout(
                      stats,
                      queue,
                      appointments,
                      insights,
                    );
                  } else {
                    return _buildMobileLayout(
                      stats,
                      queue,
                      appointments,
                      insights,
                    );
                  }
                },
              ),
            ],
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
