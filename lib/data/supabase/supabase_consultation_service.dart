import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/models/previous_session_note.dart';
import 'package:saber/data/services/sync_outbox.dart';
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
    int sessionNumber, {
    String? doctorId,
  }) async {
    try {
      final effectiveDoctorId = doctorId ?? supabase.auth.currentUser?.id;
      if (effectiveDoctorId == null) return null;

      final cloudPrefix = '$effectiveDoctorId/$patientId/session_notes';
      final sessionPath = '$cloudPrefix/session_$sessionNumber';

      final files = await supabase.storage
          .from('medical_notes')
          .list(path: sessionPath);

      if (files.isEmpty) {
        log.warning('No files found in $sessionPath');
        return null;
      }

      // Find the preview file (.sbn2.p or .sbn.p)
      FileObject? fileToUse = files.cast<FileObject?>().firstWhere(
        (f) => f != null && (f.name.endsWith('.p')),
        orElse: () => null,
      );

      // FALLBACK: If no preview, check for raw .sbn2 or .sbn
      if (fileToUse == null) {
        fileToUse = files.cast<FileObject?>().firstWhere(
          (f) =>
              f != null &&
              (f.name.endsWith('.sbn2') || f.name.endsWith('.sbn')),
          orElse: () => null,
        );
        if (fileToUse != null) {
          log.info(
            'Found raw note file (no preview) for session $sessionNumber: ${fileToUse.name}',
          );
        }
      }

      if (fileToUse != null) {
        // Use createSignedUrl instead of getPublicUrl for private buckets
        final signedUrl = await supabase.storage
            .from('medical_notes')
            .createSignedUrl('$sessionPath/${fileToUse.name}', 60 * 60);

        return PreviousSessionNote(
          imageUrl: signedUrl,
          sessionNumber: sessionNumber,
          createdAt: fileToUse.updatedAt != null
              ? DateTime.parse(fileToUse.updatedAt!).toLocal()
              : DateTime.now(),
          fileName: fileToUse.name,
        );
      }

      return null;
    } catch (e) {
      log.severe('Error fetching session note for session $sessionNumber: $e');
      return null;
    }
  }

  /* static Future<Map<String, int>> getPatientProgressStats() async {
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
  } */

  /// Complete a consultation
  static Future<void> completeConsultation(
    String consultationId, {
    String? progressStatus,
  }) async {
    try {
      final updates = {'status': 'completed'};

      await supabase
          .from('consultations')
          .update(updates)
          .eq('id', consultationId);
      log.info('Consultation $consultationId marked as completed');
    } catch (e) {
      log.severe('Error completing consultation: $e');
      if (_isNetworkError(e)) {
        log.info('Queueing consultation completion for offline sync');
        await SyncOutbox.enqueue(
          OutboxEntry(
            operation: 'completeConsultation',
            payload: {'consultationId': consultationId, 'status': 'completed'},
          ),
        );
        return; // Don't rethrow — operation is queued
      }
      rethrow;
    }
  }

  static bool _isNetworkError(Object e) {
    final msg = e.toString();
    return e is SocketException ||
        msg.contains('SocketException') ||
        msg.contains('Connection timed out') ||
        msg.contains('connection abort') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Network is unreachable') ||
        msg.contains('Network error') ||
        msg.contains('TimeoutException') ||
        msg.contains('ClientException') ||
        msg.contains('HandshakeException') ||
        msg.contains('HttpException') ||
        msg.contains('CERTIFICATE_VERIFY_FAILED') ||
        msg.contains('Connection refused') ||
        msg.contains('Connection reset');
  }

  /// Get the page count for a specific session from cloud storage
  /// Get the page count for a specific session from cloud storage
  static Future<int> getSessionPageCount(
    String patientId,
    int sessionNumber, {
    String? doctorId,
  }) async {
    try {
      final effectiveDoctorId = doctorId ?? supabase.auth.currentUser?.id;
      if (effectiveDoctorId == null) return 0;

      final cloudPrefix =
          '$effectiveDoctorId/$patientId/session_notes/session_$sessionNumber';
      final files = await supabase.storage
          .from('medical_notes')
          .list(path: cloudPrefix);

      // 1. Check for .meta file
      final metaFiles = files.where((f) => f.name.endsWith('.meta'));
      if (metaFiles.isNotEmpty) {
        try {
          final metaFile = metaFiles.first;
          final bytes = await supabase.storage
              .from('medical_notes')
              .download('$cloudPrefix/${metaFile.name}');
          final json = jsonDecode(utf8.decode(bytes));
          final count = json['pageCount'];
          if (count is int) return count;
        } catch (e) {
          log.warning('Error reading .meta file: $e');
        }
      }

      // 2. Fallback: Count files that appear to be page assets (session_note.sbn.0, session_note.sbn.1, etc.)
      final pageFiles = files.where((f) {
        final name = f.name;
        // Exclude meta and preview files
        return (name.contains('.sbn') || name.contains('.sbn2')) &&
            !name.endsWith('.p') &&
            !name.endsWith('.meta');
      });

      return pageFiles.length;
    } catch (e) {
      log.severe('Error fetching session page count: $e');
      return 0;
    }
  }

  /// Fetch all session numbers that exist in cloud storage for a patient
  static Future<List<int>> getAllSessionNumbers(
    String patientId, {
    String? doctorId,
  }) async {
    try {
      final effectiveDoctorId = doctorId ?? supabase.auth.currentUser?.id;
      if (effectiveDoctorId == null) return [];

      final cloudPrefix = '$effectiveDoctorId/$patientId/session_notes';
      log.info('Fetching all session numbers from: $cloudPrefix');

      // List all folders in the session_notes directory
      final sessionFolders = await supabase.storage
          .from('medical_notes')
          .list(path: cloudPrefix);

      final sessionNumbers = <int>[];

      for (final folder in sessionFolders) {
        // Folders often have null id, but checking name is safer
        if (folder.name.startsWith('session_')) {
          final sessionNum =
              int.tryParse(folder.name.replaceAll('session_', '')) ?? 0;
          if (sessionNum > 0) {
            sessionNumbers.add(sessionNum);
          }
        }
      }

      sessionNumbers.sort();
      return sessionNumbers;
    } catch (e) {
      log.severe('Error fetching all session numbers: $e');
      return [];
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
