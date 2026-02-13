import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:saber/data/prefs.dart';
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
  static void initialize() {
    stows.isOnline.addListener(_onConnectivityChanged);
    // Process any entries that might have been queued while the app was closed
    Future.delayed(const Duration(seconds: 3), () {
      if (stows.isOnline.value) {
        processOutbox();
        OfflineReportWorker.processQueue();
      }
    });
    _log.info('SyncWorker initialized');
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
            _log.warning('Network error processing ${entry.id}, will retry');
            await SyncOutbox.markFailed(entry.id, e.toString());
            break; // Stop processing, will retry when online again
          } else if (entry.retryCount >= 3) {
            _log.severe(
              'Permanent failure for ${entry.id} after ${entry.retryCount} retries: $e',
            );
            await SyncOutbox.markFailed(entry.id, 'PERMANENT: $e');
          } else {
            _log.warning('Transient error for ${entry.id}: $e');
            await SyncOutbox.markFailed(entry.id, e.toString());
          }
        }

        // Small delay between operations to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      _isProcessing = false;
      _log.info('Outbox drain complete');
    }
  }

  /// Dispatches an outbox entry to the appropriate Supabase operation.
  static Future<void> _processEntry(OutboxEntry entry) async {
    switch (entry.operation) {
      case 'complete_consultation':
      case 'completeConsultation':
        final consultationId =
            (entry.payload['consultation_id'] ??
                    entry.payload['consultationId'])
                as String;
        final endTime = entry.payload['session_end_time'] as String?;
        await supabase
            .from('consultations')
            .update({
              'status': 'completed',
              if (endTime != null) 'session_end_time': endTime,
            })
            .eq('id', consultationId);

      case 'create_report':
        await supabase.from('clinical_reports').insert(entry.payload);

      case 'update_consultation':
        final consultationId = entry.payload['consultation_id'] as String;
        final updates = Map<String, dynamic>.from(entry.payload)
          ..remove('consultation_id');
        await supabase
            .from('consultations')
            .update(updates)
            .eq('id', consultationId);

      default:
        _log.warning('Unknown operation: ${entry.operation}');
        throw StateError('Unknown outbox operation: ${entry.operation}');
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

  /// Clean up resources.
  static void dispose() {
    stows.isOnline.removeListener(_onConnectivityChanged);
    _drainTimer?.cancel();
    _drainTimer = null;
    _log.info('SyncWorker disposed');
  }
}
