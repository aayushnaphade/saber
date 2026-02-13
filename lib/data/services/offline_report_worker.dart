import 'dart:async';

import 'package:logging/logging.dart';
import 'package:saber/data/api/report_generator.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/services/offline_report_queue.dart';
import 'package:saber/data/supabase/supabase_consultation_service.dart';
import 'package:saber/data/supabase/supabase_prescription_service.dart';
import 'package:saber/data/supabase/supabase_report_service.dart';
import 'package:saber/data/utils/report_formatter.dart';

/// Worker processed by SyncWorker to generate and upload pending reports
class OfflineReportWorker {
  static final _log = Logger('OfflineReportWorker');
  static bool _isProcessing = false;

  /// Process all pending reports in the offline queue.
  /// Calls the Gemini API, generates the report, saves it to Supabase,
  /// and creates prescriptions.
  static Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final pendingList = await OfflineReportQueue.getPending();
      if (pendingList.isEmpty) return;

      _log.info('Processing ${pendingList.length} pending offline reports...');

      for (final reportEntry in pendingList) {
        // Skip if max retries reached or marked as permanent failure
        if (reportEntry.retryCount >= 3 || reportEntry.status == 'failed') {
          continue;
        }

        // Stop if we lose connection
        if (!stows.isOnline.value) {
          _log.info('Lost connectivity, pausing report worker');
          break;
        }

        try {
          await _processSingleReport(reportEntry);
        } catch (e) {
          _log.severe('Error processing report ${reportEntry.id}', e);
          await OfflineReportQueue.updateStatus(
            reportEntry.id,
            'retrying', // Or 'failed' depending on error
            error: e.toString(),
          );
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  static Future<void> _processSingleReport(PendingReport entry) async {
    _log.info('Generating report for ${entry.patientName} (${entry.id})');

    // 1. Load Images
    final images = await OfflineReportQueue.loadImages(entry.id);
    if (images.isEmpty) {
      _log.severe('No images found for report ${entry.id}, marking failed');
      await OfflineReportQueue.updateStatus(
        entry.id,
        'failed',
        error: 'No images found',
      );
      return;
    }

    // 2. Determine Model (use current specific preference or default)
    // We use the default logic from ReportGenerator internally.

    // 3. Generate Report via Gemini
    final reportData = await ReportGenerator.generateReport(
      images,
      registrationNumber: entry.registrationNumber,
    );

    _log.info('Report generated successfully for ${entry.id}');

    // 4. Format Markdown
    final markdown = ReportFormatter.formatToMarkdown(
      reportData: reportData,
      patientId: entry.patientId,
      patientName: entry.patientName,
      registrationNumber: entry.registrationNumber,
    );

    // 5. Save Report to Supabase
    // We use the sourceFilePath stored in the queue so that session linking works
    await SupabaseReportService.createReport(
      patientId: entry.patientId,
      structuredData: reportData,
      markdownContent: markdown,
      sourceDocumentPath: entry.sourceFilePath,
    );
    _log.info('Report saved to Supabase for ${entry.id}');

    // 6. Create Prescriptions (if any)
    try {
      final medications = reportData['medications'];
      if (medications is List && medications.isNotEmpty) {
        final medsList = medications.whereType<Map<String, dynamic>>().map((m) {
          final newMap = Map<String, dynamic>.from(m);
          if (newMap.containsKey('remarks')) {
            newMap['instructions'] = newMap['remarks'];
          }
          return newMap;
        }).toList();

        if (medsList.isNotEmpty) {
          await SupabasePrescriptionService.createPrescription(
            patientId: entry.patientId,
            consultationId: entry.consultationId,
            medications: medsList,
            patientName: entry.patientName,
          );
          _log.info('Prescriptions created for ${entry.id}');
        }
      }
    } catch (e) {
      _log.warning('Failed to create prescriptions for ${entry.id}: $e');
      // Non-critical, continue to cleanup
    }

    // 7. Ensure Consultation is Completed (Safety net)
    try {
      // Only if ID is valid
      if (entry.consultationId.isNotEmpty) {
        // We don't want to override existing completion data if SyncOutbox handled it,
        // but providing a status update is idempotent usually.
        await SupabaseConsultationService.completeConsultation(
          entry.consultationId,
        );
      }
    } catch (e) {
      _log.warning('Consultation completion check failed: $e');
    }

    // 8. Remove from Queue
    await OfflineReportQueue.remove(entry.id);
    _log.info('Report ${entry.id} processing complete and removed from queue');
  }
}
