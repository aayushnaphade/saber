import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// A persistent write-ahead log for Supabase write operations that failed
/// due to network issues. Entries are stored as JSON on disk and replayed
/// when connectivity is restored.
class SyncOutbox {
  static final _log = Logger('SyncOutbox');

  static Future<File> _outboxFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/cache');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    return File('${cacheDir.path}/sync_outbox.json');
  }

  static Future<List<Map<String, dynamic>>> _readAll() async {
    try {
      final file = await _outboxFile();
      if (!file.existsSync()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final list = jsonDecode(content) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      _log.warning('Error reading outbox: $e');
      return [];
    }
  }

  static Future<void> _writeAll(List<Map<String, dynamic>> entries) async {
    try {
      final file = await _outboxFile();
      await file.writeAsString(jsonEncode(entries));
    } catch (e) {
      _log.warning('Error writing outbox: $e');
    }
  }

  /// Enqueues a failed operation for later replay.
  static Future<String> enqueue(OutboxEntry entry) async {
    final entries = await _readAll();
    entries.add(entry.toJson());
    await _writeAll(entries);
    _log.info(
      'Enqueued operation: ${entry.operation} (${entry.id}). '
      'Total pending: ${entries.length}',
    );
    return entry.id;
  }

  /// Returns all pending (non-completed and non-failed) entries, oldest first.
  static Future<List<OutboxEntry>> getPending() async {
    final entries = await _readAll();
    return entries
        .map(OutboxEntry.fromJson)
        .where(
          (e) =>
              e.status != OutboxStatus.completed &&
              e.status != OutboxStatus.failed,
        )
        .toList();
  }

  /// Marks an entry as completed and removes it from the outbox.
  static Future<void> markCompleted(String id) async {
    final entries = await _readAll();
    entries.removeWhere((e) => e['id'] == id);
    await _writeAll(entries);
    _log.info(
      'Outbox entry $id marked as completed. Remaining: ${entries.length}',
    );
  }

  /// Reset all 'failed' entries to 'pending' so they are retried.
  /// Used on app startup to give failed items another chance.
  static Future<void> retryAllFailed() async {
    final entries = await _readAll();
    var changed = false;
    for (final entry in entries) {
      if (entry['status'] == 'failed') {
        entry['status'] = 'pending';
        entry['retryCount'] = 0; // Reset retries
        entry['lastError'] = null;
        changed = true;
      }
    }
    if (changed) {
      await _writeAll(entries);
      _log.info('Reset failed outbox entries to pending for retry');
    }
  }

  /// Marks an entry as permanently failed. It will not be retried.
  static Future<void> markPermanentFailure(String id, String error) async {
    final entries = await _readAll();
    final index = entries.indexWhere((e) => e['id'] == id);
    if (index != -1) {
      entries[index]['status'] = 'failed';
      entries[index]['lastError'] = error;
      await _writeAll(entries);
      _log.severe('Marked entry $id as permanently failed: $error');
    } else {
      _log.warning('Could not find entry $id to mark as failed');
    }
  }

  /// Marks an entry as transiently failed (retry later).
  /// Increments retry count.
  static Future<void> markTransientFailure(String id, String error) async {
    final entries = await _readAll();
    final index = entries.indexWhere((e) => e['id'] == id);
    if (index != -1) {
      // Don't change status to 'failed', just keep it pending (or 'processing' implicitly)
      // but update metadata
      final currentRetries = (entries[index]['retryCount'] as int?) ?? 0;
      entries[index]['retryCount'] = currentRetries + 1;
      entries[index]['lastError'] = error;

      await _writeAll(entries);
      _log.info(
        'Marked entry $id as transient failure (Retry ${currentRetries + 1}): $error',
      );
    } else {
      _log.warning('Could not find entry $id to mark as transient failure');
    }
  }

  /// Returns the count of pending operations (excluding failed ones).
  static Future<int> pendingCount() async {
    final entries = await _readAll();
    final count = entries
        .where((e) => e['status'] != 'completed' && e['status'] != 'failed')
        .length;
    _log.info('Pending sync count: $count');
    return count;
  }

  /// Returns IDs of consultations that are locally completed but not yet synced.
  /// Used by Dashboard to filter out "active" sessions that are actually done.
  static Future<Set<String>> getLocallyCompletedConsultationIds() async {
    final pending = await getPending();
    return pending
        .where(
          (e) =>
              e.operation == 'completeConsultation' ||
              e.operation == 'complete_consultation',
        )
        .map((e) {
          final cid =
              e.payload['consultationId'] ?? e.payload['consultation_id'];
          return cid?.toString();
        })
        .whereType<String>()
        .toSet();
  }

  /// Returns IDs of consultations that were started offline but not yet synced.
  /// Used by Dashboard to filter out queue items that are actually in-progress.
  static Future<Set<String>> getLocallyStartedConsultationIds() async {
    final pending = await getPending();
    return pending
        .where((e) => e.operation == 'start_consultation')
        .map((e) {
          final cid =
              e.payload['consultationId'] ?? e.payload['consultation_id'];
          return cid?.toString();
        })
        .whereType<String>()
        .toSet();
  }

  /// Clears all entries from the outbox.
  static Future<void> clear() async {
    try {
      final file = await _outboxFile();
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      _log.warning('Error clearing outbox: $e');
    }
  }
}

enum OutboxStatus { pending, processing, completed, failed }

/// Represents a single queued write operation.
class OutboxEntry {
  final String id;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;
  final OutboxStatus status;

  OutboxEntry({
    String? id,
    required this.operation,
    required this.payload,
    DateTime? createdAt,
    this.retryCount = 0,
    this.lastError,
    this.status = OutboxStatus.pending,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'operation': operation,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'lastError': lastError,
    'status': status.name,
  };

  factory OutboxEntry.fromJson(Map<String, dynamic> json) {
    return OutboxEntry(
      id: json['id'] as String,
      operation: json['operation'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      status: OutboxStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OutboxStatus.pending,
      ),
    );
  }

  @override
  String toString() => 'OutboxEntry($operation, id=$id, status=$status)';
}
