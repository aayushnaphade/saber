import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Persists captured note images and metadata for reports that failed
/// to generate due to network issues. Images are saved as files and a
/// manifest tracks pending reports.
class OfflineReportQueue {
  static final _log = Logger('OfflineReportQueue');

  static Future<Directory> _queueDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final queueDir = Directory('${dir.path}/pending_reports');
    if (!queueDir.existsSync()) {
      queueDir.createSync(recursive: true);
    }
    return queueDir;
  }

  static Future<File> _manifestFile() async {
    final dir = await _queueDir();
    return File('${dir.path}/manifest.json');
  }

  static Future<List<Map<String, dynamic>>> _readManifest() async {
    try {
      final file = await _manifestFile();
      if (!file.existsSync()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final list = jsonDecode(content) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      _log.warning('Error reading report manifest: $e');
      return [];
    }
  }

  static Future<void> _writeManifest(List<Map<String, dynamic>> entries) async {
    try {
      final file = await _manifestFile();
      await file.writeAsString(jsonEncode(entries));
    } catch (e) {
      _log.warning('Error writing report manifest: $e');
    }
  }

  /// Saves note images and metadata for later report generation.
  /// Returns the ID of the queued report.
  static Future<String> saveForLater({
    required List<Uint8List> imageBytesList,
    required String patientId,
    required String consultationId,
    required String? sourceFilePath,
    String? registrationNumber,
    String? patientName,
  }) async {
    // Guard: never queue a report without a valid patientId
    if (patientId.isEmpty) {
      throw ArgumentError('Cannot queue report: patientId is empty');
    }

    final id = const Uuid().v4();
    final dir = await _queueDir();
    final reportDir = Directory('${dir.path}/$id');
    reportDir.createSync(recursive: true);

    // Save images
    for (var i = 0; i < imageBytesList.length; i++) {
      final imgFile = File('${reportDir.path}/page_$i.png');
      await imgFile.writeAsBytes(imageBytesList[i]);
    }

    // Save metadata
    final meta = {
      'id': id,
      'patientId': patientId,
      'consultationId': consultationId,
      'sourceFilePath': sourceFilePath,
      'registrationNumber': registrationNumber,
      'patientName': patientName,
      'imageCount': imageBytesList.length,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'queued', // queued | retrying | failed
      'retryCount': 0,
      'lastError': null,
    };

    final metaFile = File('${reportDir.path}/meta.json');
    await metaFile.writeAsString(jsonEncode(meta));

    // Update manifest
    final manifest = await _readManifest();
    manifest.add(meta);
    await _writeManifest(manifest);

    _log.info(
      'Queued report $id for patient $patientId '
      '(${imageBytesList.length} pages)',
    );
    return id;
  }

  /// Returns all pending reports.
  static Future<List<PendingReport>> getPending() async {
    final manifest = await _readManifest();
    return manifest
        .where((e) => e['status'] != 'completed')
        .map(PendingReport.fromJson)
        .toList();
  }

  /// Loads the saved images for a queued report.
  static Future<List<Uint8List>> loadImages(String reportId) async {
    final dir = await _queueDir();
    final reportDir = Directory('${dir.path}/$reportId');
    if (!reportDir.existsSync()) return [];

    final metaFile = File('${reportDir.path}/meta.json');
    if (!metaFile.existsSync()) return [];

    final meta =
        jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
    final imageCount = meta['imageCount'] as int? ?? 0;

    final images = <Uint8List>[];
    for (var i = 0; i < imageCount; i++) {
      final imgFile = File('${reportDir.path}/page_$i.png');
      if (imgFile.existsSync()) {
        images.add(await imgFile.readAsBytes());
      }
    }
    return images;
  }

  /// Updates the status of a pending report in the manifest.
  /// Set [resetRetries] to true when the user manually triggers a retry
  /// to clear the retry count and allow processing again.
  static Future<void> updateStatus(
    String id,
    String status, {
    String? error,
    bool resetRetries = false,
  }) async {
    final manifest = await _readManifest();
    for (final entry in manifest) {
      if (entry['id'] == id) {
        entry['status'] = status;
        if (error != null) entry['lastError'] = error;
        if (resetRetries) {
          entry['retryCount'] = 0;
          entry['lastError'] = null;
        } else if (status == 'retrying' || status == 'failed') {
          entry['retryCount'] = (entry['retryCount'] as int? ?? 0) + 1;
        }
      }
    }
    await _writeManifest(manifest);
  }

  /// Updates the patient info for a pending report (used for recovery).
  static Future<void> recoverPatient(
    String id, {
    required String patientId,
    String? patientName,
    String? registrationNumber,
  }) async {
    final manifest = await _readManifest();
    for (final entry in manifest) {
      if (entry['id'] == id) {
        entry['patientId'] = patientId;
        if (patientName != null) entry['patientName'] = patientName;
        if (registrationNumber != null) {
          entry['registrationNumber'] = registrationNumber;
        }
      }
    }
    await _writeManifest(manifest);
  }

  /// Resets all 'failed' items to 'queued' so they are retried.
  static Future<void> retryAllFailed() async {
    final manifest = await _readManifest();
    var changed = false;
    for (final entry in manifest) {
      if (entry['status'] == 'failed') {
        entry['status'] = 'queued';
        entry['retryCount'] = 0;
        entry['lastError'] = null;
        changed = true;
      }
    }
    if (changed) {
      await _writeManifest(manifest);
      _log.info('Reset failed offline reports to queued for retry');
    }
  }

  /// Resets any reports that were stuck in 'processing' or 'retrying' state
  /// (e.g. app crash) back to 'queued' so they can be picked up again.
  static Future<void> resetStuckReports() async {
    final manifest = await _readManifest();
    var changed = false;
    for (final entry in manifest) {
      final status = entry['status'];
      if (status == 'processing' || status == 'retrying') {
        entry['status'] = 'queued';
        entry['retryCount'] = 0;
        entry['lastError'] = null;
        changed = true;
        _log.info(
          'Reset stuck report ${entry['id']} from $status to queued (retryCount reset)',
        );
      }
    }
    if (changed) {
      await _writeManifest(manifest);
    }
  }

  /// Removes all failed reports from the queue and deletes their files.
  static Future<void> removeAllFailed() async {
    final manifest = await _readManifest();
    final failedIds = manifest
        .where((e) => e['status'] == 'failed')
        .map((e) => e['id'] as String)
        .toList();

    for (final id in failedIds) {
      await remove(id);
    }
    _log.info('Removed ${failedIds.length} failed reports');
  }

  /// Removes a completed or cancelled report and its files.
  static Future<void> remove(String id) async {
    // Remove files
    final dir = await _queueDir();
    final reportDir = Directory('${dir.path}/$id');
    if (reportDir.existsSync()) {
      await reportDir.delete(recursive: true);
    }

    // Remove from manifest
    final manifest = await _readManifest();
    manifest.removeWhere((e) => e['id'] == id);
    await _writeManifest(manifest);

    _log.info('Removed queued report $id');
  }

  /// Returns the count of pending reports.
  static Future<int> pendingCount() async {
    final manifest = await _readManifest();
    return manifest.where((e) => e['status'] != 'completed').length;
  }

  /// Clears all pending reports and their files.
  static Future<void> clear() async {
    final dir = await _queueDir();
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
    _log.info('Cleared all pending reports');
  }
}

/// Represents a report queued for later generation.
class PendingReport {
  final String id;
  final String patientId;
  final String consultationId;
  final String? sourceFilePath;
  final String? registrationNumber;
  final String? patientName;
  final int imageCount;
  final DateTime createdAt;
  final String status;
  final int retryCount;
  final String? lastError;

  PendingReport({
    required this.id,
    required this.patientId,
    required this.consultationId,
    this.sourceFilePath,
    this.registrationNumber,
    this.patientName,
    required this.imageCount,
    required this.createdAt,
    required this.status,
    this.retryCount = 0,
    this.lastError,
  });

  factory PendingReport.fromJson(Map<String, dynamic> json) {
    return PendingReport(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      consultationId: json['consultationId'] as String,
      sourceFilePath: json['sourceFilePath'] as String?,
      registrationNumber: json['registrationNumber'] as String?,
      patientName: json['patientName'] as String?,
      imageCount: json['imageCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: json['status'] as String? ?? 'queued',
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'queued':
        return 'Queued';
      case 'retrying':
        return 'Retrying...';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
