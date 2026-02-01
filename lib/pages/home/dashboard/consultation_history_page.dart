import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/api/error_handler.dart';
import 'package:saber/data/supabase/supabase_dashboard_service.dart';
import 'package:saber/design_system/spacing.dart';

class ConsultationHistoryPage extends StatefulWidget {
  const ConsultationHistoryPage({super.key});

  @override
  State<ConsultationHistoryPage> createState() => _ConsultationHistoryPageState();
}

class _ConsultationHistoryPageState extends State<ConsultationHistoryPage> {
  var _isLoading = true;
  var _filter = _HistoryFilter.today;
  List<Appointment> _consultations = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      DateTime start;
      final end = now;

      switch (_filter) {
        case _HistoryFilter.today:
          start = DateTime(now.year, now.month, now.day);
          break;
        case _HistoryFilter.lastWeek:
          start = now.subtract(const Duration(days: 7));
          break;
        case _HistoryFilter.lastMonth:
          start = now.subtract(const Duration(days: 30));
          break;
      }

      final results =
          await SupabaseDashboardService.getConsultationHistory(start, end);
      if (mounted) {
        setState(() {
          _consultations = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getFriendlyErrorMessage(e))),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(HomeRoutes.getRoute(0)),
        ),
        title: const Text('Consultation History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                _buildFilterChip('Today', _HistoryFilter.today),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip('Last Week', _HistoryFilter.lastWeek),
                const SizedBox(width: AppSpacing.sm),
                _buildFilterChip('Last Month', _HistoryFilter.lastMonth),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _consultations.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _consultations.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final consultation = _consultations[index];
                    return _buildConsultationCard(consultation);
                  },
                ),
    );
  }

  Widget _buildFilterChip(String label, _HistoryFilter filter) {
    return FilterChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filter = filter);
          _loadHistory();
        }
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No consultations found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Try changing the filter period',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationCard(Appointment consultation) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            consultation.patientName.isNotEmpty
                ? consultation.patientName[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(consultation.patientName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('MMM d, h:mm a').format(consultation.time)} • ${consultation.reason}',
            ),
            if (consultation.status == AppointmentStatus.cancelled)
                Text(
                  'Cancelled',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
             if (consultation.status == AppointmentStatus.completed)
                Text(
                  'Completed',
                  style: TextStyle(color: Colors.green),
                ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
            // Navigate to patient details with return path to history
             context.go(
                '${RoutePaths.patientDetail.replaceFirst(':patientId', consultation.patientId)}?returnPath=${Uri.encodeComponent('/home/history')}',
             );
        },
      ),
    );
  }
}

enum _HistoryFilter {
  today,
  lastWeek,
  lastMonth,
}
