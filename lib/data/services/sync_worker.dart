import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/services/offline_report_queue.dart';
import 'package:saber/data/services/offline_report_worker.dart';
import 'package:saber/data/services/sync_outbox.dart';
import 'package:saber/data/supabase/supabase_client.dart';

/// Background processor that drains the [SyncOutbox] when connectivity
/// is restored. Listens to [stows.isOnline] and processes entries FIFO
/// with exponential backoff.
class SyncWorker {
  static final _log = Logger('SyncWorker');
  static Timer? _drainTimer;
  static bool _isProcessing = false;

  /// Initialize the worker and start listening for connectivity changes.
  static Future<void> initialize() async {
    _log.info('SyncWorker initialized');
    stows.isOnline.addListener(_onConnectivityChanged);

    // Give failed items another chance on app startup
    await SyncOutbox.retryAllFailed();
    await OfflineReportQueue.retryAllFailed();

    // Also resume any pending offline reports
    await OfflineReportWorker.processQueue();

    // Trigger initial check if online
    if (stows.isOnline.value) {
      processOutbox();
    }
  }

  static void _onConnectivityChanged() {
    if (stows.isOnline.value) {
      _log.info('Connectivity restored, scheduling outbox drain');
      _scheduleDrain();
      // Also process any pending offline reports
      OfflineReportWorker.processQueue();
    } else {
      _drainTimer?.cancel();
      _drainTimer = null;
    }
  }

  static void _scheduleDrain() {
    _drainTimer?.cancel();
    _drainTimer = Timer(const Duration(seconds: 2), processOutbox);
  }

  /// Process all pending entries in the outbox, with retry logic.
  static Future<void> processOutbox() async {
    if (_isProcessing) return;
    _isProcessing = true;

    _log.info('Starting outbox drain...');

    try {
      final entries = await SyncOutbox.getPending();
      if (entries.isEmpty) {
        _log.info('Outbox is empty');
        return;
      }

      _log.info('Processing ${entries.length} outbox entries');

      for (final entry in entries) {
        if (!stows.isOnline.value) {
          _log.info('Lost connectivity mid-drain, stopping');
          break;
        }

        try {
          await _processEntry(entry);
          await SyncOutbox.markCompleted(entry.id);
          _log.info('Successfully processed: ${entry.operation} (${entry.id})');
        } catch (e) {
          if (_isNetworkError(e)) {
            // For network errors, we stop processing but don't increment retry count
            // (infinite retries until connected). We just update the logs.
            _log.warning('Network error detected. Pausing sync.');
            await SyncOutbox.markTransientFailure(entry.id, e.toString());
            break; // Stop processing to avoid rapid retry loop
          } else {
            _log.severe(
              'Permanent failure for entry ${entry.id}. Marking as failed.',
            );
            await SyncOutbox.markPermanentFailure(entry.id, e.toString());
            // Continue to next item
          }
        }
      }
    } catch (e, stack) {
      _log.severe('Unexpected error in processOutbox: $e', e, stack);
    } finally {
      _isProcessing = false;
    }
  }

  static Future<void> _processEntry(OutboxEntry entry) async {
    _log.info('Dispatching operation: ${entry.operation}');
    if (entry.operation == 'complete_consultation') {
      final payload = entry.payload;
      _log.info('Payload: $payload');

      final consultationId =
          (payload['consultation_id'] ?? payload['consultationId']) as String;

      // Update the consultation status in Supabase
      await supabase
          .from('consultations')
          .update({
            'status': 'completed',
            'session_end_time': payload['session_end_time'],
            'duration_seconds': payload['duration_seconds'],
          })
          .eq('id', consultationId);
    } else if (entry.operation == 'create_report') {
      final payload = entry.payload;
      _log.info(
        'Payload keys: ${payload.keys.toList()}',
      ); // Avoid logging massive markdown

      await supabase.from('clinical_reports').insert(payload);
    } else {
      _log.warning('Unknown operation: ${entry.operation}');
      throw Exception('Unknown operation: ${entry.operation}');
    }
  }

  static bool _isNetworkError(Object e) {
    final msg = e.toString();
    // Log the error message for debugging
    _log.info('Checking if network error: "$msg"');

    return e is SocketException ||
        msg.contains('SocketException') ||
        msg.contains('Connection timed out') ||
        msg.contains('connection abort') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Network is unreachable') ||
        msg.contains('Network error') ||
        msg.contains('TimeoutException') ||
        // ClientException/HttpException often imply 4xx/5xx responses or protocol errors
        // which should NOT be retried infinitely. We treat them as transient errors
        // that will eventually fail permanently if unresolved.
        msg.contains('HandshakeException') ||
        msg.contains('CERTIFICATE_VERIFY_FAILED') ||
        msg.contains('Connection refused') ||
        msg.contains('Connection closed') ||
        msg.contains('Connection reset');
  }

  /// Clean up resources.
  static void dispose() {
    stows.isOnline.removeListener(_onConnectivityChanged);
    _drainTimer?.cancel();
    _drainTimer = null;
    _log.info('SyncWorker disposed');
  }
}
