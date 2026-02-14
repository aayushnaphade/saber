import 'dart:io';

import 'package:logging/logging.dart';
import 'package:saber/data/services/sync_outbox.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:uuid/uuid.dart';

class ClinicalReport {
  final String id;
  final String patientId;
  final String doctorId;
  final DateTime createdAt;
  final DateTime sessionDate;
  final String? sourceDocumentPath;
  final Map<String, dynamic> structuredData;
  final String? markdownContent;
  final String status;

  ClinicalReport({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.createdAt,
    required this.sessionDate,
    this.sourceDocumentPath,
    required this.structuredData,
    this.markdownContent,
    this.status = 'verified',
  });

  factory ClinicalReport.fromJson(Map<String, dynamic> json) {
    return ClinicalReport(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      doctorId: json['doctor_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      sessionDate: DateTime.parse(json['session_date'] as String).toLocal(),
      sourceDocumentPath: json['source_document_path'] as String?,
      structuredData: json['structured_data'] as Map<String, dynamic>,
      markdownContent: json['markdown_content'] as String?,
      status: json['status'] as String? ?? 'verified',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'session_date': sessionDate.toIso8601String().split('T')[0],
      'source_document_path': sourceDocumentPath,
      'structured_data': structuredData,
      'markdown_content': markdownContent,
      'status': status,
    };
  }
}

class SupabaseReportService {
  static final _log = Logger('SupabaseReportService');

  /// Creates a clinical report.
  /// If offline, queues the insert for later sync and returns a local placeholder.
  static Future<ClinicalReport> createReport({
    required String patientId,
    required Map<String, dynamic> structuredData,
    required String markdownContent,
    String? sourceDocumentPath,
    String status = 'verified',
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final insertPayload = {
      'patient_id': patientId,
      'doctor_id': user.id,
      'session_date': DateTime.now().toIso8601String().split('T')[0],
      'source_document_path': sourceDocumentPath,
      'structured_data': structuredData,
      'markdown_content': markdownContent,
      'status': status,
    };

    try {
      final response = await supabase
          .from('clinical_reports')
          .insert(insertPayload)
          .select()
          .single();

      return ClinicalReport.fromJson(response);
    } catch (e) {
      if (_isNetworkError(e)) {
        _log.warning(
          'Network error creating report for patient $patientId, '
          'queuing for later sync',
        );
        await SyncOutbox.enqueue(
          OutboxEntry(operation: 'create_report', payload: insertPayload),
        );
        // Return a local placeholder so the UI flow is unblocked
        return ClinicalReport(
          id: const Uuid().v4(),
          patientId: patientId,
          doctorId: user.id,
          createdAt: DateTime.now(),
          sessionDate: DateTime.now(),
          sourceDocumentPath: sourceDocumentPath,
          structuredData: structuredData,
          markdownContent: markdownContent,
          status: status,
        );
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
        msg.contains('TimeoutException') ||
        msg.contains('ClientException');
  }

  static Future<List<ClinicalReport>> getReportsForPatient(
    String patientId,
  ) async {
    final response = await supabase
        .from('clinical_reports')
        .select()
        .eq('patient_id', patientId)
        .order('session_date', ascending: false);

    return (response as List).map((e) => ClinicalReport.fromJson(e)).toList();
  }

  static Future<ClinicalReport?> getReportBySourcePath(
    String sourcePath,
  ) async {
    final response = await supabase
        .from('clinical_reports')
        .select()
        .eq('source_document_path', sourcePath)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return ClinicalReport.fromJson(response);
  }

  /// Deletes a clinical report by ID
  static Future<void> deleteReport(String reportId) async {
    await supabase.from('clinical_reports').delete().eq('id', reportId);
  }
}
