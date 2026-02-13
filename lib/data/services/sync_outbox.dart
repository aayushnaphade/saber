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

  /// Returns all pending (non-completed) entries, oldest first.
  static Future<List<OutboxEntry>> getPending() async {
    final entries = await _readAll();
    return entries
        .map(OutboxEntry.fromJson)
        .where((e) => e.status != OutboxStatus.completed)
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

  /// Marks an entry as failed with an error message.
  static Future<void> markFailed(String id, String error) async {
    final entries = await _readAll();
    for (final entry in entries) {
      if (entry['id'] == id) {
        entry['status'] = 'failed';
        entry['lastError'] = error;
        entry['retryCount'] = (entry['retryCount'] as int? ?? 0) + 1;
      }
    }
    await _writeAll(entries);
    _log.warning('Outbox entry $id marked as failed: $error');
  }

  /// Returns the count of pending operations.
  static Future<int> pendingCount() async {
    final entries = await _readAll();
    return entries.where((e) => e['status'] != 'completed').length;
  }

  /// Returns consultation IDs that have been locally completed
  /// (queued for sync) but not yet pushed to the server.
  /// This is used by the dashboard to filter out stale active consultations.
  static Future<Set<String>> getLocallyCompletedConsultationIds() async {
    final entries = await getPending();
    final ids = <String>{};
    for (final entry in entries) {
      if (entry.operation == 'completeConsultation' ||
          entry.operation == 'complete_consultation') {
        final id =
            entry.payload['consultationId'] as String? ??
            entry.payload['consultation_id'] as String?;
        if (id != null) ids.add(id);
      }
    }
    return ids;
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
