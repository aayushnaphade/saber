import 'dart:io';

import 'package:logging/logging.dart';

import 'package:saber/data/services/offline_dashboard_cache.dart';
import 'package:saber/data/services/sync_outbox.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:uuid/uuid.dart';

import 'package:saber/data/models/dashboard_models.dart';

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
      final startTime = DateTime.now();
      _log.info(
        'SupabaseReportService: Start saving report for $patientId at $startTime',
      );

      final response = await supabase
          .from('clinical_reports')
          .insert(insertPayload)
          .select()
          .single();

      final duration = DateTime.now().difference(startTime);
      _log.info(
        'SupabaseReportService: Saved report in ${duration.inMilliseconds}ms',
      );

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
        msg.contains('No address associated with hostname') ||
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

  /// Fetches reports that require doctor review (status = 'draft')
  /// Joins with patients table to get patient name for display
  /// Fetches reports that require doctor review (status = 'draft')
  /// Joins with patients table to get patient name for display
  static Future<({List<ClinicalReport> items, bool isStale})>
  getPendingReviewReports() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _log.warning(
        'SupabaseReportService: User is null. Attempting to load from cache.',
      );
      final cached = await OfflineDashboardCache.loadPendingReviews();
      if (cached != null) {
        _log.info(
          'SupabaseReportService: Returning ${cached.length} cached pending reviews (User null)',
        );
        return (items: cached, isStale: true);
      }
      return (items: <ClinicalReport>[], isStale: false);
    }

    try {
      final response = await supabase
          .from('clinical_reports')
          .select(
            'id, patient_id, doctor_id, created_at, session_date, source_document_path, structured_data, markdown_content, status, patients(full_name)',
          )
          .eq('doctor_id', user.id)
          .eq('status', 'draft')
          .order('created_at', ascending: false);

      final items = (response as List)
          .map((e) => ClinicalReport.fromJson(e))
          .toList();

      // Cache on success
      await OfflineDashboardCache.savePendingReviews(items);
      _log.info(
        'SupabaseReportService: Fetched ${items.length} pending reviews from Supabase',
      );

      return (items: items, isStale: false);
    } catch (e) {
      _log.warning(
        'SupabaseReportService: Error fetching pending review reports: $e',
      );

      // On network error, try cached data
      if (_isNetworkError(e)) {
        _log.info(
          'SupabaseReportService: Network error detected. Attempting cache load.',
        );
        final cached = await OfflineDashboardCache.loadPendingReviews();
        if (cached != null) {
          _log.info(
            'SupabaseReportService: Returning ${cached.length} cached pending reviews',
          );
          return (items: cached, isStale: true);
        } else {
          _log.warning('SupabaseReportService: Cache was null/empty.');
        }
      } else {
        _log.warning(
          'SupabaseReportService: Error was NOT classified as network error.',
        );
      }

      return (items: <ClinicalReport>[], isStale: false);
    }
  }

  /// Updates the status of a report (e.g. 'draft' -> 'verified')
  static Future<void> updateReportStatus(String reportId, String status) async {
    await supabase
        .from('clinical_reports')
        .update({'status': status})
        .eq('id', reportId);
  }

  /// Updates a report's content and status.
  static Future<void> updateReport({
    required String reportId,
    required Map<String, dynamic> structuredData,
    required String markdownContent,
    String? status,
  }) async {
    final updatePayload = {
      'structured_data': structuredData,
      'markdown_content': markdownContent,
      if (status != null) 'status': status,
    };

    await supabase
        .from('clinical_reports')
        .update(updatePayload)
        .eq('id', reportId);
  }
}
