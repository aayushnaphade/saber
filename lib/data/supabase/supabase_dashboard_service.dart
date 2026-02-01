import 'package:logging/logging.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDashboardService {
  static final log = Logger('SupabaseDashboardService');

  /// Fetches the current live queue (waiting and in-progress consultations)
  static Future<List<QueueItem>> getLiveQueue() async {
    try {
      // Auto-cleanup past pending sessions
      await cancelPastPendingSessions();

      final response = await supabase
          .from('consultations')
          .select('*, patients(full_name, gender, age, visit_type)')
          .or('status.eq.waiting,status.eq.in_progress')
          .order('queue_order', ascending: true)
          .order('scheduled_time', ascending: true);

      final List<QueueItem> queue = [];
      int position = 1;

      for (final item in response as List) {
        final patient = item['patients'];
        final patientName = patient != null ? patient['full_name'] : 'Unknown';
        final status = item['status'] as String;
        
        final age = patient?['age'] as int? ?? 0;
        
        final gender = patient?['gender'] as String? ?? 'Unknown';
        // Use visit_type from patient or default to 'New Patient'
        final visitType = patient?['visit_type'] as String? ?? 'New Patient';
        final registeredTime = DateTime.parse(item['created_at']);

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
            age: age,
            gender: gender,
            registeredTime: registeredTime,
            patientType: visitType,
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
      // Auto-cleanup past pending sessions
      await cancelPastPendingSessions();

      final now = DateTime.now();
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toUtc().toIso8601String();
      final endOfDay = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();

      final response = await supabase
          .from('consultations')
          .select('*, patients(full_name, visit_type, gender, age)')
          .gte('scheduled_time', startOfDay)
          .lte('scheduled_time', endOfDay)
          .order('scheduled_time', ascending: true);

      return (response as List).map((item) {
        final patient = item['patients'];
        final patientName = patient != null ? patient['full_name'] : 'Unknown';
        final visitType = patient != null ? patient['visit_type'] : null;
        final statusStr = item['status'] as String;
        final appointmentTypeStr = item['appointment_type'] as String?;

        AppointmentStatus status;
        switch (statusStr) {
          case 'completed':
            status = AppointmentStatus.completed;
          case 'cancelled':
            status = AppointmentStatus.cancelled;
          case 'in_progress':
            status = AppointmentStatus.inProgress;
          default:
            status = AppointmentStatus.upcoming;
        }

        final age = patient?['age'] as int?;
        final gender = patient?['gender'] as String?;

        return Appointment(
          id: item['id'],
          patientName: patientName,
          patientId: item['patient_id'],
          time: DateTime.parse(item['scheduled_time'] ?? item['created_at']),
          reason: visitType ?? 'General Consultation',
          status: status,
          appointmentType: appointmentTypeStr ?? 'walk-in',
          age: age,
          gender: gender,
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
      ).toUtc().toIso8601String();

      // Count patients today
      final patientsToday = await supabase
          .from('consultations')
          .count(CountOption.exact)
          .gte('created_at', startOfDay);

      final completedSessionsData = await supabase
          .from('consultations')
          .select('session_start_time, session_end_time')
          .gte('created_at', startOfDay)
          .eq('status', 'completed');

      final completedSessions = (completedSessionsData as List).length;

      int totalMinutes = 0;
      for (final session in completedSessionsData as List) {
        final startStr = session['session_start_time'] as String?;
        final endStr = session['session_end_time'] as String?;
        if (startStr != null && endStr != null) {
          final start = DateTime.parse(startStr);
          final end = DateTime.parse(endStr);
          totalMinutes += end.difference(start).inMinutes;
        }
      }

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
        totalConsultationMinutes: totalMinutes,
      );
    } catch (e) {
      log.severe('Error fetching stats: $e');
      return const DashboardStats(
        patientsToday: 0,
        pendingReports: 0,
        completedSessions: 0,
        totalConsultationMinutes: 0,
      );
    }
  }

  /// Cancels an appointment
  static Future<void> cancelAppointment(String consultationId) async {
    try {
      await supabase
          .from('consultations')
          .update({'status': 'cancelled'})
          .eq('id', consultationId);
    } catch (e) {
      log.severe('Error cancelling appointment: $e');
      rethrow;
    }
  }

  /// Reschedules an appointment
  static Future<void> rescheduleAppointment(
      String consultationId, DateTime newTime) async {
    try {
      await supabase
          .from('consultations')
          .update({'created_at': newTime.toIso8601String()})
          .eq('id', consultationId);
    } catch (e) {
      log.severe('Error rescheduling appointment: $e');
      rethrow;
    }
  }

  /// Completes a consultation session
  static Future<void> completeConsultation(String consultationId) async {
    try {
      await supabase
          .from('consultations')
          .update({
            'status': 'completed',
            'session_end_time': DateTime.now().toIso8601String(),
          })
          .eq('id', consultationId);
      log.info('Consultation $consultationId marked as completed');
    } catch (e) {
      log.severe('Error completing consultation: $e');
      rethrow;
    }
  }

  /// Cancel past pending sessions (auto-cleanup for no-shows)
  /// Marks all waiting/in_progress consultations from previous days as cancelled
  static Future<int> cancelPastPendingSessions() async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

      final response = await supabase
          .from('consultations')
          .update({'status': 'cancelled'})
          .lt('scheduled_time', startOfToday)
          .inFilter('status', ['waiting', 'in_progress'])
          .select();

      final count = (response as List).length;
      if (count > 0) {
        log.info('Auto-cancelled $count past pending sessions');
      }
      return count;
    } catch (e) {
      log.severe('Error cancelling past pending sessions: $e');
      return 0;
    }
  }

  /// Check for scheduling conflicts
  /// Returns list of conflicting appointments for the given time slot
  static Future<List<Appointment>> checkTimeSlotConflicts(
      DateTime scheduledTime,
      {String? excludeConsultationId}) async {
    try {
      // Check within a 30-minute window
      final start = scheduledTime.subtract(const Duration(minutes: 15));
      final end = scheduledTime.add(const Duration(minutes: 15));

      var query = supabase
          .from('consultations')
          .select('*, patients(full_name, visit_type, gender, age)')
          .gte('scheduled_time', start.toIso8601String())
          .lte('scheduled_time', end.toIso8601String())
          .neq('status', 'cancelled')
          .neq('status', 'completed');

      if (excludeConsultationId != null) {
        query = query.neq('id', excludeConsultationId);
      }

      final response = await query;

      return (response as List).map((item) {
        final patient = item['patients'];
        final patientName = patient != null ? patient['full_name'] : 'Unknown';
        final visitType = patient != null ? patient['visit_type'] : null;
        final statusStr = item['status'] as String;
        final appointmentTypeStr = item['appointment_type'] as String?;

        AppointmentStatus status;
        switch (statusStr) {
          case 'completed':
            status = AppointmentStatus.completed;
          case 'cancelled':
            status = AppointmentStatus.cancelled;
          case 'in_progress':
            status = AppointmentStatus.inProgress;
          default:
            status = AppointmentStatus.upcoming;
        }

        final age = patient?['age'] as int?;
        final gender = patient?['gender'] as String?;

        return Appointment(
          id: item['id'],
          patientName: patientName,
          patientId: item['patient_id'],
          time: DateTime.parse(item['scheduled_time'] ?? item['created_at']),
          reason: visitType ?? 'General Consultation',
          status: status,
          appointmentType: appointmentTypeStr ?? 'walk-in',
          age: age,
          gender: gender,
        );
      }).toList();
    } catch (e) {
      log.severe('Error checking time slot conflicts: $e');
      return [];
    }
  }

  /// Fetches consultation history for a given date range
  static Future<List<Appointment>> getConsultationHistory(
      DateTime start, DateTime end) async {
    try {
      final response = await supabase
          .from('consultations')
          .select('*, patients(full_name, visit_type, gender, age)')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        final patient = item['patients'];
        final patientName = patient != null ? patient['full_name'] : 'Unknown';
        final visitType = patient != null ? patient['visit_type'] : null;
        final statusStr = item['status'] as String;
        final appointmentTypeStr = item['appointment_type'] as String?;

        AppointmentStatus status;
        switch (statusStr) {
          case 'completed':
            status = AppointmentStatus.completed;
          case 'cancelled':
            status = AppointmentStatus.cancelled;
          case 'in_progress':
            status = AppointmentStatus.inProgress;
          default:
            status = AppointmentStatus.upcoming;
        }

        final age = patient?['age'] as int?;
        final gender = patient?['gender'] as String?;

        return Appointment(
          id: item['id'],
          patientName: patientName,
          patientId: item['patient_id'],
          time: DateTime.parse(item['created_at']),
          reason: visitType ?? 'General Consultation',
          status: status,
          appointmentType: appointmentTypeStr ?? 'walk-in',
          age: age,
          gender: gender,
        );
      }).toList();
    } catch (e) {
      log.severe('Error fetching consultation history: $e');
      return [];
    }
  }

  /// Generate mock AI insights (until we have real analysis backend)
  static Future<List<AIInsight>> getInsights() async {
    // In a real app, this would fetch from an 'insights' table or an Edge Function
    // that analyzes patient data.
    return [
      AIInsight(
        id: '1',
        title: 'High Volume Expected',
        description: 'Based on historical data, Monday mornings have 20% more walk-ins.',
        type: InsightType.trend,
        timestamp: DateTime.now(),
      ),
      AIInsight(
        id: '2',
        title: 'Pending Lab Reports',
        description: '3 patients from yesterday are waiting for blood test results.',
        type: InsightType.action,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }
}

