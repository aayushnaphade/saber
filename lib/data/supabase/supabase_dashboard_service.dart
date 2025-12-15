import 'package:logging/logging.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDashboardService {
  static final log = Logger('SupabaseDashboardService');

  /// Fetches the current live queue (waiting and in-progress consultations)
  static Future<List<QueueItem>> getLiveQueue() async {
    try {
      final response = await supabase
          .from('consultations')
          .select('*, patients(full_name)')
          .or('status.eq.waiting,status.eq.in_progress')
          .order('created_at', ascending: true);

      final List<QueueItem> queue = [];
      int position = 1;

      for (final item in response as List) {
        final patient = item['patients'];
        final patientName = patient != null ? patient['full_name'] : 'Unknown';
        final status = item['status'] as String;

        // Calculate estimated wait time (mock logic for now: 15 mins per person ahead)
        final waitTime = Duration(minutes: (position - 1) * 15);

        queue.add(
          QueueItem(
            id: item['id'],
            patientName: patientName,
            patientId: item['patient_id'],
            position: position++,
            estimatedWaitTime: waitTime,
            status: status == 'in_progress' ? 'In Consultation' : 'Waiting',
          ),
        );
      }

      return queue;
    } catch (e) {
      log.severe('Error fetching live queue: $e');
      return [];
    }
  }

  /// Fetches today's appointments (all consultations created today)
  static Future<List<Appointment>> getTodayAppointments() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String();
      final endOfDay = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ).toIso8601String();

      final response = await supabase
          .from('consultations')
          .select('*, patients(full_name)')
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay)
          .order('created_at', ascending: true);

      return (response as List).map((item) {
        final patient = item['patients'];
        final patientName = patient != null ? patient['full_name'] : 'Unknown';
        final statusStr = item['status'] as String;

        AppointmentStatus status;
        switch (statusStr) {
          case 'completed':
            status = AppointmentStatus.completed;
            break;
          case 'cancelled':
            status = AppointmentStatus.cancelled;
            break;
          case 'in_progress':
            status = AppointmentStatus.inProgress;
            break;
          default:
            status = AppointmentStatus.upcoming;
        }

        return Appointment(
          id: item['id'],
          patientName: patientName,
          patientId: item['patient_id'],
          time: DateTime.parse(item['created_at']),
          reason:
              'General Consultation', // Placeholder as reason isn't in schema yet
          status: status,
        );
      }).toList();
    } catch (e) {
      log.severe('Error fetching appointments: $e');
      return [];
    }
  }

  /// Fetches dashboard statistics
  static Future<DashboardStats> getStats() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String();

      // Count patients today
      final patientsToday = await supabase
          .from('consultations')
          .count(CountOption.exact)
          .gte('created_at', startOfDay);

      // Count completed sessions
      final completedSessions = await supabase
          .from('consultations')
          .count(CountOption.exact)
          .gte('created_at', startOfDay)
          .eq('status', 'completed');

      // Count pending (waiting)
      final pending = await supabase
          .from('consultations')
          .count(CountOption.exact)
          .gte('created_at', startOfDay)
          .eq('status', 'waiting');

      return DashboardStats(
        patientsToday: patientsToday,
        pendingReports: pending, // Using pending consultations as proxy
        completedSessions: completedSessions,
        averageTimePerPatient: 15.0, // Mock value
      );
    } catch (e) {
      log.severe('Error fetching stats: $e');
      return const DashboardStats(
        patientsToday: 0,
        pendingReports: 0,
        completedSessions: 0,
        averageTimePerPatient: 0,
      );
    }
  }
}
