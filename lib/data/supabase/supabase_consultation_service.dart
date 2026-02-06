import 'package:logging/logging.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/models/previous_session_note.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing consultations and patient sessions
class SupabaseConsultationService {
  static final log = Logger('SupabaseConsultationService');

  /// Fetch all consultations for a specific patient
  static Future<List<PatientConsultation>> getPatientConsultations(
    String patientId,
  ) async {
    try {
      final response = await supabase
          .from('consultations')
          .select('''
            id,
            patient_id,
            doctor_id,
            status,
            created_at,
            patients!inner(full_name),
            profiles!inner(full_name)
          ''')
          .eq('patient_id', patientId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PatientConsultation.fromJson(json))
          .toList();
    } catch (e) {
      log.severe('Error fetching patient consultations: $e');
      return [];
    }
  }

  /// Fetch all consultations for today for the current doctor
  static Future<List<PatientConsultation>> getTodayConsultations(
    String doctorId,
  ) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await supabase
          .from('consultations')
          .select('''
            id,
            patient_id,
            doctor_id,
            status,
            created_at,
            scheduled_time,
            appointment_type,
            patients!inner(full_name, age, contact_number),
            profiles!inner(full_name)
          ''')
          .eq('doctor_id', doctorId)
          .gte('scheduled_time', startOfDay.toUtc().toIso8601String())
          .lt('scheduled_time', endOfDay.toUtc().toIso8601String())
          .order('scheduled_time', ascending: true);

      return (response as List)
          .map((json) => PatientConsultation.fromJson(json))
          .toList();
    } catch (e) {
      log.severe('Error fetching today consultations: $e');
      return [];
    }
  }

  /// Fetch upcoming consultations for the current doctor
  static Future<List<PatientConsultation>> getUpcomingConsultations(
    String doctorId,
  ) async {
    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final startOfTomorrow = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
      );

      final response = await supabase
          .from('consultations')
          .select('''
            id,
            patient_id,
            doctor_id,
            status,
            created_at,
            scheduled_time,
            appointment_type,
            patients!inner(full_name, age, contact_number),
            profiles!inner(full_name)
          ''')
          .eq('doctor_id', doctorId)
          .gte('scheduled_time', startOfTomorrow.toUtc().toIso8601String())
          .inFilter('status', ['waiting', 'in_progress'])
          .order('scheduled_time', ascending: true)
          .limit(20);

      return (response as List)
          .map((json) => PatientConsultation.fromJson(json))
          .toList();
    } catch (e) {
      log.severe('Error fetching upcoming consultations: $e');
      return [];
    }
  }

  /// Fetch completed consultations for the current doctor
  static Future<List<PatientConsultation>> getCompletedConsultations(
    String doctorId, {
    int limit = 50,
  }) async {
    try {
      final response = await supabase
          .from('consultations')
          .select('''
            id,
            patient_id,
            doctor_id,
            status,
            created_at,
            patients!inner(full_name, age, contact_number),
            profiles!inner(full_name)
          ''')
          .eq('doctor_id', doctorId)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => PatientConsultation.fromJson(json))
          .toList();
    } catch (e) {
      log.severe('Error fetching completed consultations: $e');
      return [];
    }
  }

  /// Fetch consultations for a specific date range
  static Future<List<PatientConsultation>> getConsultationsByDateRange(
    String doctorId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await supabase
          .from('consultations')
          .select('''
            id,
            patient_id,
            doctor_id,
            status,
            created_at,
            scheduled_time,
            appointment_type,
            patients!inner(full_name, age, contact_number),
            profiles!inner(full_name)
          ''')
          .eq('doctor_id', doctorId)
          .gte('scheduled_time', startDate.toUtc().toIso8601String())
          .lt('scheduled_time', endDate.toUtc().toIso8601String())
          .order('scheduled_time', ascending: false);

      return (response as List)
          .map((json) => PatientConsultation.fromJson(json))
          .toList();
    } catch (e) {
      log.severe('Error fetching consultations by date range: $e');
      return [];
    }
  }

  /// Get consultations grouped by date for calendar view
  static Future<Map<DateTime, List<PatientConsultation>>>
  getConsultationsGroupedByDate(
    String doctorId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final consultations = await getConsultationsByDateRange(
        doctorId,
        startDate,
        endDate,
      );

      final grouped = <DateTime, List<PatientConsultation>>{};

      for (final consultation in consultations) {
        final date = consultation.scheduledTime;
        final dateKey = DateTime(date.year, date.month, date.day);

        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(consultation);
      }

      return grouped;
    } catch (e) {
      log.severe('Error grouping consultations by date: $e');
      return {};
    }
  }

  /// Fetch all previous session notes screenshots for a patient
  static Future<List<PreviousSessionNote>> getPreviousSessionNotes(
    String patientId, {
    int? excludeSessionNumber,
  }) async {
    try {
      final doctorId = supabase.auth.currentUser?.id;
      if (doctorId == null) return [];

      final cloudPrefix = '$doctorId/$patientId/session_notes';
      log.info('Fetching notes from: $cloudPrefix');

      // List all folders in the session_notes directory
      final sessionFolders = await supabase.storage
          .from('medical_notes')
          .list(path: cloudPrefix);

      log.info('Found ${sessionFolders.length} items in session_notes');

      final List<PreviousSessionNote> notes = [];

      for (final folder in sessionFolders) {
        // Folders often have null id, but checking name is safer
        if (folder.name.startsWith('session_')) {
          final folderName = folder.name;

          // Extract session number from folder name "session_X"
          final sessionNum =
              int.tryParse(folderName.replaceAll('session_', '')) ?? 0;

          if (excludeSessionNumber != null &&
              sessionNum == excludeSessionNumber) {
            log.info('Skipping current session: $sessionNum');
            continue;
          }

          final sessionPath = '$cloudPrefix/$folderName';

          final files = await supabase.storage
              .from('medical_notes')
              .list(path: sessionPath);

          log.info('Found ${files.length} files in $sessionPath');

          // Find the preview file (.sbn2.p or .sbn.p)
          final previewFile = files.cast<FileObject?>().firstWhere(
            (f) => f != null && (f.name.endsWith('.p')),
            orElse: () => null,
          );

          if (previewFile != null) {
            try {
              // Use createSignedUrl instead of getPublicUrl for private buckets
              final signedUrl = await supabase.storage
                  .from('medical_notes')
                  .createSignedUrl('$sessionPath/${previewFile.name}', 60 * 60);

              notes.add(
                PreviousSessionNote(
                  imageUrl: signedUrl,
                  sessionNumber: sessionNum,
                  createdAt: previewFile.updatedAt != null
                      ? DateTime.parse(previewFile.updatedAt!).toLocal()
                      : DateTime.now(),
                  fileName: previewFile.name,
                ),
              );
              log.info('Added note for session $sessionNum');
            } catch (e) {
              log.severe('Error parsing note for $folderName: $e');
            }
          }
        }
      }

      notes.sort((a, b) => b.sessionNumber.compareTo(a.sessionNumber));
      return notes;
    } catch (e) {
      log.severe('Error fetching previous session notes: $e');
      return [];
    }
  }

  /// Fetch a single session note for a specific patient and session number
  static Future<PreviousSessionNote?> getSessionNote(
    String patientId,
    int sessionNumber,
  ) async {
    try {
      final doctorId = supabase.auth.currentUser?.id;
      if (doctorId == null) return null;

      final cloudPrefix = '$doctorId/$patientId/session_notes';
      final sessionPath = '$cloudPrefix/session_$sessionNumber';

      log.info('Fetching specific note from: $sessionPath');

      final files = await supabase.storage
          .from('medical_notes')
          .list(path: sessionPath);

      if (files.isEmpty) {
        log.info('No files found in $sessionPath');
        return null;
      }

      // Find the preview file (.sbn2.p or .sbn.p)
      final previewFile = files.cast<FileObject?>().firstWhere(
        (f) => f != null && (f.name.endsWith('.p')),
        orElse: () => null,
      );

      if (previewFile != null) {
        // Use createSignedUrl instead of getPublicUrl for private buckets
        final signedUrl = await supabase.storage
            .from('medical_notes')
            .createSignedUrl('$sessionPath/${previewFile.name}', 60 * 60);

        return PreviousSessionNote(
          imageUrl: signedUrl,
          sessionNumber: sessionNumber,
          createdAt: previewFile.updatedAt != null
              ? DateTime.parse(previewFile.updatedAt!).toLocal()
              : DateTime.now(),
          fileName: previewFile.name,
        );
      }

      return null;
    } catch (e) {
      log.severe('Error fetching session note for session $sessionNumber: $e');
      return null;
    }
  }

  /// Get patient progress statistics
  static Future<Map<String, int>> getPatientProgressStats() async {
    try {
      final doctorId = supabase.auth.currentUser?.id;
      if (doctorId == null) return {};

      // Get all completed consultations with a progress status
      final response = await supabase
          .from('consultations')
          .select('progress_status')
          .eq('doctor_id', doctorId)
          .eq('status', 'completed')
          .not('progress_status', 'is', null);

      int improving = 0;
      int stable = 0;
      int deteriorating = 0;

      for (final item in response as List) {
        final status = item['progress_status'] as String?;
        if (status == 'improving')
          improving++;
        else if (status == 'stable')
          stable++;
        else if (status == 'deteriorating')
          deteriorating++;
      }

      return {
        'improving': improving,
        'stable': stable,
        'deteriorating': deteriorating,
      };
    } catch (e) {
      log.severe('Error fetching patient progress stats: $e');
      return {'improving': 0, 'stable': 0, 'deteriorating': 0};
    }
  }

  /// Complete a consultation
  static Future<void> completeConsultation(
    String consultationId, {
    String? progressStatus,
  }) async {
    try {
      final updates = {'status': 'completed'};
      if (progressStatus != null) {
        updates['progress_status'] = progressStatus;
      }

      await supabase
          .from('consultations')
          .update(updates)
          .eq('id', consultationId);
      log.info(
        'Consultation $consultationId marked as completed with status: $progressStatus',
      );
    } catch (e) {
      log.severe('Error completing consultation: $e');
      rethrow; // Vital: let the caller handle/log this visibility
    }
  }
}

/// Model for patient consultation data
class PatientConsultation {
  final String id;
  final String patientId;
  final String? doctorId;
  final String status;
  final DateTime createdAt;
  final DateTime scheduledTime;
  final String appointmentType;
  final String patientName;
  final String? doctorName;
  final int? patientAge;
  final String? patientContact;
  final String? progressStatus;

  PatientConsultation({
    required this.id,
    required this.patientId,
    this.doctorId,
    required this.status,
    required this.createdAt,
    required this.scheduledTime,
    required this.appointmentType,
    required this.patientName,
    this.doctorName,
    this.patientAge,
    this.patientContact,
    this.progressStatus,
  });

  factory PatientConsultation.fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['created_at'] as String;
    final scheduledTimeStr = json['scheduled_time'] as String?;

    return PatientConsultation(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      doctorId: json['doctor_id'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(createdAtStr).toLocal(),
      scheduledTime: scheduledTimeStr != null
          ? DateTime.parse(scheduledTimeStr).toLocal()
          : DateTime.parse(createdAtStr).toLocal(),
      appointmentType: json['appointment_type'] as String? ?? 'walk-in',
      patientName: json['patients']['full_name'] as String,
      doctorName: json['profiles']?['full_name'] as String?,
      patientAge: json['patients']?['age'] as int?,
      patientContact: json['patients']?['contact_number'] as String?,
      progressStatus: json['progress_status'] as String?,
    );
  }

  bool get isScheduled => appointmentType == 'scheduled';

  AppointmentStatus get appointmentStatus {
    switch (status) {
      case 'waiting':
        return AppointmentStatus.upcoming;
      case 'in_progress':
        return AppointmentStatus.inProgress;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      default:
        return AppointmentStatus.upcoming;
    }
  }
}
