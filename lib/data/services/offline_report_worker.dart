import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/api/report_generator.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/services/offline_report_queue.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:saber/data/supabase/supabase_consultation_service.dart';
import 'package:saber/data/supabase/supabase_prescription_service.dart';
import 'package:saber/data/supabase/supabase_report_service.dart';
import 'package:saber/data/utils/report_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Worker processed by SyncWorker to generate and upload pending reports
class OfflineReportWorker {
  static final _log = Logger('OfflineReportWorker');
  static var _isProcessing = false;
  static final List<VoidCallback> _completionListeners = [];

  /// Add a listener to be called when report processing completes
  static void addCompletionListener(VoidCallback listener) {
    _completionListeners.add(listener);
  }

  /// Remove a completion listener
  static void removeCompletionListener(VoidCallback listener) {
    _completionListeners.remove(listener);
  }

  static void _notifyCompletion() {
    for (final listener in _completionListeners) {
      try {
        listener();
      } catch (e) {
        _log.warning('Error in completion listener: $e');
      }
    }
  }

  /// Process all pending reports in the offline queue.
  /// Calls the Gemini API, generates the report, saves it to Supabase,
  /// and creates prescriptions.
  static Future<void> processQueue({bool force = false}) async {
    if (force) {
      _log.info('Forcing worker processing (resetting flag)');
      _isProcessing = false;
    }

    if (_isProcessing) {
      _log.info('Worker is already processing, skipping trigger');
      return;
    }
    _isProcessing = true;

    try {
      final pendingList = await OfflineReportQueue.getPending();
      if (pendingList.isEmpty) {
        _log.info('[TIMING] No pending reports in queue');
        return;
      }

      _log.info('[TIMING] Online: ${stows.isOnline.value}');
      _log.info(
        '[TIMING] Processing ${pendingList.length} pending offline reports...',
      );

      for (final reportEntry in pendingList) {
        _log.info(
          '[TIMING] Entry ${reportEntry.id}: status=${reportEntry.status}, retryCount=${reportEntry.retryCount}, patient=${reportEntry.patientName}',
        );

        // Skip if max retries reached or marked as permanent failure
        if (reportEntry.retryCount >= 3 || reportEntry.status == 'failed') {
          _log.info(
            '[TIMING] Skipping ${reportEntry.id}: retryCount=${reportEntry.retryCount}, status=${reportEntry.status}',
          );
          // If retryCount >= 3 but status isn't 'failed', mark it as failed
          if (reportEntry.status != 'failed' && reportEntry.retryCount >= 3) {
            await OfflineReportQueue.updateStatus(
              reportEntry.id,
              'failed',
              error: 'Max retries (${reportEntry.retryCount}) exceeded',
            );
          }
          continue;
        }

        // Stop if we lose connection
        if (!stows.isOnline.value) {
          _log.info('[TIMING] Lost connectivity, pausing report worker');
          break;
        }

        try {
          final overallStart = DateTime.now();
          _log.info(
            '[TIMING] >>> Starting processing for report ${reportEntry.id} at $overallStart',
          );
          await _processSingleReport(reportEntry).timeout(
            const Duration(minutes: 3),
            onTimeout: () {
              throw TimeoutException('Report generation timed out after 3 min');
            },
          );
          final overallDuration = DateTime.now().difference(overallStart);
          _log.info(
            '[TIMING] <<< Finished report ${reportEntry.id} in ${overallDuration.inSeconds}s',
          );
        } catch (e) {
          _log.severe('[TIMING] Error processing report ${reportEntry.id}: $e');
          final newRetryCount = reportEntry.retryCount + 1;
          final newStatus = newRetryCount >= 3 ? 'failed' : 'retrying';
          await OfflineReportQueue.updateStatus(
            reportEntry.id,
            newStatus,
            error: e.toString(),
          );
          _log.info(
            '[TIMING] Updated ${reportEntry.id} to status=$newStatus, retryCount will be $newRetryCount',
          );
        }
      }
    } finally {
      _isProcessing = false;
      _notifyCompletion();
    }
  }

  static Future<void> _processSingleReport(PendingReport entry) async {
    _log.info('Generating report for ${entry.patientName} (${entry.id})');

    // 0. Validate or Recover required fields
    String processedPatientId = entry.patientId;
    String? processedPatientName = entry.patientName;

    if (processedPatientId.isEmpty) {
      if (entry.consultationId.isNotEmpty) {
        _log.info(
          'Attempting to recover missing patientId from consultation ${entry.consultationId}',
        );
        try {
          // Attempt to fetch patient_id and patient_name from consultation
          final consultation = await supabase
              .from('clinical_consultations')
              .select('patient_id, patient_name, patients(full_name)')
              .eq('id', entry.consultationId)
              .maybeSingle();

          if (consultation != null && consultation['patient_id'] != null) {
            processedPatientId = consultation['patient_id'] as String;
            // Try to get name from join or fallback
            if (consultation['patients'] != null) {
              processedPatientName = consultation['patients']['full_name'];
            } else {
              processedPatientName = consultation['patient_name'];
            }

            _log.info(
              'Recovered patientId: $processedPatientId. Updating manifest.',
            );
            await OfflineReportQueue.recoverPatient(
              entry.id,
              patientId: processedPatientId,
              patientName: processedPatientName,
            );
          }
        } catch (e) {
          _log.warning('Failed to recover patientId: $e');
        }
      }

      // If still empty after recovery attempt, fail.
      if (processedPatientId.isEmpty) {
        _log.severe(
          'Report ${entry.id} has empty patientId and recovery failed. Marking as permanently failed.',
        );
        await OfflineReportQueue.updateStatus(
          entry.id,
          'failed',
          error: 'Missing patientId — recovery failed',
        );
        return;
      }
    }

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
    final startTime = DateTime.now();
    _log.info('Calling ReportGenerator at $startTime');

    final reportData = await ReportGenerator.generateReport(
      images,
      registrationNumber: entry.registrationNumber,
    );

    final duration = DateTime.now().difference(startTime);
    _log.info(
      'Report generated successfully in ${duration.inSeconds}s for ${entry.id}',
    );

    // 4. Format Markdown
    final markdown = ReportFormatter.formatToMarkdown(
      reportData: reportData,
      patientId: processedPatientId,
      patientName: processedPatientName,
      registrationNumber: entry.registrationNumber,
    );

    // 5. Save Report to Supabase
    // We use the sourceFilePath stored in the queue so that session linking works.
    // If it's null (legacy item), we try to infer it from consultation history.
    String? finalSourcePath = entry.sourceFilePath;
    if (finalSourcePath == null && entry.consultationId.isNotEmpty) {
      try {
        finalSourcePath = await _inferSessionPath(
          processedPatientId,
          entry.consultationId,
        );
        if (finalSourcePath != null) {
          _log.info('Inferred session path for legacy item: $finalSourcePath');
        } else {
          _log.warning('Could not infer session path for ${entry.id}');
        }
      } catch (e) {
        _log.warning('Error inferring session path: $e');
      }
    }

    await SupabaseReportService.createReport(
      patientId: processedPatientId,
      structuredData: reportData,
      markdownContent: markdown,
      sourceDocumentPath: finalSourcePath,
      status: 'draft',
    );
    _log.info('Report saved to Supabase for ${entry.id}');

    // 6. Create Prescriptions (if any)
    try {
      final medications = reportData['medications'];
      if (medications is List && medications.isNotEmpty) {
        final rxStart = DateTime.now();
        _log.info('[TIMING] Step 6: Creating prescriptions...');
        final medsList = medications.whereType<Map<String, dynamic>>().map((m) {
          // ... existing logic ...
          final newMap = Map<String, dynamic>.from(m);
          if (newMap.containsKey('remarks')) {
            newMap['instructions'] = newMap['remarks'];
          }
          return newMap;
        }).toList();

        if (medsList.isNotEmpty) {
          await SupabasePrescriptionService.createPrescription(
            patientId: processedPatientId,
            consultationId: entry.consultationId,
            medications: medsList,
            patientName: processedPatientName,
          );
          final rxDuration = DateTime.now().difference(rxStart);
          _log.info(
            '[TIMING] Step 6: Prescriptions created in ${rxDuration.inMilliseconds}ms',
          );
        }
      } else {
        _log.info('[TIMING] Step 6: No medications to prescribe, skipping');
      }
    } catch (e) {
      _log.warning('Failed to create prescriptions for ${entry.id}: $e');
      // Non-critical, continue to cleanup
    }

    // 7. Ensure Consultation is Completed (Safety net)
    try {
      if (entry.consultationId.isNotEmpty) {
        final step7Start = DateTime.now();
        _log.info(
          '[TIMING] Step 7: Completing consultation ${entry.consultationId}...',
        );
        await SupabaseConsultationService.completeConsultation(
          entry.consultationId,
        );
        final step7Duration = DateTime.now().difference(step7Start);
        _log.info(
          '[TIMING] Step 7: Consultation completed in ${step7Duration.inMilliseconds}ms',
        );
      } else {
        _log.info('[TIMING] Step 7: No consultationId, skipping');
      }
    } catch (e) {
      _log.warning('Consultation completion check failed: $e');
    }

    // 8. Remove from Queue
    final step8Start = DateTime.now();
    _log.info('[TIMING] Step 8: Removing report ${entry.id} from queue...');
    await OfflineReportQueue.remove(entry.id);
    final step8Duration = DateTime.now().difference(step8Start);
    _log.info('[TIMING] Step 8: Removed in ${step8Duration.inMilliseconds}ms');
    _log.info('Report ${entry.id} processing FULLY complete');
  }

  /// Infers the session path (e.g. session_5/session_5_notes.saber)
  /// by looking up the consultation history.
  static Future<String?> _inferSessionPath(
    String patientId,
    String consultationId,
  ) async {
    // Get all consultations for patient, ordered by date (newest first usually)
    final consultations =
        await SupabaseConsultationService.getPatientConsultations(patientId);

    // Sort oldest first to determine index (1-based session number)
    consultations.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final index = consultations.indexWhere((c) => c.id == consultationId);
    if (index != -1) {
      final sessionNum = index + 1;
      return 'session_$sessionNum/session_${sessionNum}_notes.saber';
    }
    return null;
  }
}
