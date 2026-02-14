import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/supabase/supabase_auth_service.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FileObject, FileOptions;

/// Service for syncing documents between local storage and Supabase Storage
class DocumentSyncService {
  static final log = Logger('DocumentSyncService');

  /// Upload a document file to Supabase Storage
  static Future<void> uploadDocument(
    String localPath, {
    bool overwrite = true,
  }) async {
    try {
      log.info('Uploading document: $localPath');

      // Check if file is in patients directory
      if (!localPath.contains('/patients/')) {
        log.fine('Skipping non-patient file: $localPath');
        return;
      }

      // Get cloud path
      final cloudPath = _getCloudPath(localPath);
      if (cloudPath == null) {
        log.warning('Could not determine cloud path for: $localPath');
        return;
      }

      // Read file
      final file = FileManager.getFile(localPath);
      if (!await file.exists()) {
        log.warning('File does not exist: $localPath');
        return;
      }

      final bytes = await file.readAsBytes();

      // Upload to storage
      await supabase.storage
          .from('medical_notes')
          .uploadBinary(
            cloudPath,
            bytes,
            fileOptions: FileOptions(upsert: overwrite),
          );

      log.info('Successfully uploaded: $localPath -> $cloudPath');

      // If this is a .sbn2 file, also upload the .sba assets folder
      if (localPath.endsWith('.sbn2')) {
        await _uploadAssetsFolder(localPath, cloudPath);
      }
    } catch (e, stackTrace) {
      log.severe('Failed to upload document: $localPath', e, stackTrace);
      rethrow;
    }
  }

  /// Download a document file from Supabase Storage
  static Future<void> downloadDocument(
    String cloudPath,
    String localPath,
  ) async {
    try {
      log.info('Downloading document: $cloudPath -> $localPath');

      // Download from storage
      final bytes = await supabase.storage
          .from('medical_notes')
          .download(cloudPath);

      // Ensure directory exists
      final file = FileManager.getFile(localPath);
      await file.parent.create(recursive: true);

      // Write file
      await file.writeAsBytes(bytes);

      log.info('Successfully downloaded: $cloudPath -> $localPath');

      // If this is a .sbn2 file, also download the .sba assets folder
      if (cloudPath.endsWith('.sbn2')) {
        await _downloadAssetsFolder(cloudPath, localPath);
      }
    } catch (e, stackTrace) {
      log.severe('Failed to download document: $cloudPath', e, stackTrace);
      rethrow;
    }
  }

  /// Ensure a document is local, downloading it if missing
  static Future<void> syncDownIfMissing({
    required String localPath,
    String? doctorId,
  }) async {
    final file = FileManager.getFile(localPath);
    if (await file.exists()) return;

    final effectiveDoctorId = doctorId ?? supabase.auth.currentUser?.id;
    if (effectiveDoctorId == null) return;

    // Convert local path to cloud path
    String cleanPath = localPath;
    if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
    if (cleanPath.startsWith('patients/')) {
      cleanPath = cleanPath.substring('patients/'.length);
    }

    final cloudPath = '$effectiveDoctorId/$cleanPath';

    try {
      await downloadDocument(cloudPath, localPath);
    } catch (e) {
      log.warning('Sync down if missing failed for $cloudPath: $e');
      // No rethrow, as editor can still open (empty) if sync fails
    }
  }

  /// Delete a document file from Supabase Storage
  static Future<void> deleteDocument(String localPath) async {
    try {
      log.info('Deleting document from cloud: $localPath');

      final cloudPath = _getCloudPath(localPath);
      if (cloudPath == null) {
        log.warning('Could not determine cloud path for: $localPath');
        return;
      }

      // Delete from storage
      await supabase.storage.from('medical_notes').remove([cloudPath]);

      log.info('Successfully deleted from cloud: $cloudPath');

      // If this is a .sbn2 file, also delete the .sba assets folder
      if (localPath.endsWith('.sbn2')) {
        await _deleteAssetsFolder(localPath, cloudPath);
      }
    } catch (e, stackTrace) {
      log.severe(
        'Failed to delete document from cloud: $localPath',
        e,
        stackTrace,
      );
      // Don't rethrow, just log error so local delete can proceed/succeed
    }
  }

  /// Delete assets folder (.sba) for a .sbn2 file from cloud
  static Future<void> _deleteAssetsFolder(
    String localSbn2Path,
    String cloudSbn2Path,
  ) async {
    try {
      final cloudAssetsPath =
          '${cloudSbn2Path.substring(0, cloudSbn2Path.length - 5)}.sba';

      // List files in assets folder
      final files = await supabase.storage
          .from('medical_notes')
          .list(path: cloudAssetsPath);

      if (files.isEmpty) return;

      final pathsToDelete = files
          .map((f) => '$cloudAssetsPath/${f.name}')
          .toList();

      await supabase.storage.from('medical_notes').remove(pathsToDelete);
    } catch (e) {
      log.warning(
        'Failed to delete assets folder from cloud: $cloudSbn2Path',
        e,
      );
    }
  }

  /// Sync all documents for a specific patient
  static Future<void> syncPatientDocuments(
    String patientId, {
    required Future<Map<String, bool>> Function(List<String> fileNames)
    onConflicts,
  }) async {
    try {
      log.info('Syncing documents for patient: $patientId');

      final doctorId = SupabaseAuthService.currentUser?.id;
      if (doctorId == null) {
        log.warning('No authenticated user');
        return;
      }

      final cloudPrefix = '$doctorId/$patientId';

      // List all files in patient's cloud folder
      // We need to list recursively to get files in subfolders (like session_notes/session_1/...)
      final cloudFiles = await _listCloudFilesRecursive(cloudPrefix);

      log.info('Found ${cloudFiles.length} cloud files for patient $patientId');

      final missingFiles = <String>[];
      final fileMap = <String, String>{}; // relativePath -> cloudPath

      // Identify missing files
      for (final cloudFile in cloudFiles) {
        // cloudFile.name is the full path: doctorId/patientId/folder/file
        // We want the path relative to the patient folder: folder/file
        if (!cloudFile.name.startsWith('$cloudPrefix/')) {
          continue; // Should not happen if list works correctly
        }

        final relativePath = cloudFile.name.substring(cloudPrefix.length + 1);
        final localPath = '/patients/$patientId/$relativePath';
        final localFile = FileManager.getFile(localPath);

        if (!await localFile.exists()) {
          missingFiles.add(relativePath);
          fileMap[relativePath] = cloudFile.name;
        } else {
          // TODO: Check timestamps and sync if cloud is newer
          log.fine('File already exists locally: $relativePath');
        }
      }

      // Handle conflicts if any
      if (missingFiles.isNotEmpty) {
        log.info('Found ${missingFiles.length} missing files');
        final resolutions = await onConflicts(missingFiles);

        for (final entry in resolutions.entries) {
          final relativePath = entry.key;
          final shouldRestore = entry.value;
          final cloudPath = fileMap[relativePath]!;
          final localPath = '/patients/$patientId/$relativePath';

          if (shouldRestore) {
            log.info('Restoring missing file: $relativePath');
            await downloadDocument(cloudPath, localPath);
          } else {
            log.info('Deleting orphaned cloud file: $relativePath');
            await deleteCloudDocument(cloudPath);
          }
        }
      }

      // Upload local files that don't exist in cloud
      // TODO: Implement scanning local patient folder and uploading new files

      log.info('Completed sync for patient: $patientId');
    } catch (e, stackTrace) {
      log.severe('Failed to sync patient documents: $patientId', e, stackTrace);
      rethrow;
    }
  }

  static Future<List<FileObject>> _listCloudFilesRecursive(
    String prefix,
  ) async {
    final files = <FileObject>[];

    // Helper to process a directory
    Future<void> processDir(String path) async {
      final result = await supabase.storage
          .from('medical_notes')
          .list(path: path);

      for (final item in result) {
        if (item.id == null) {
          // It's a folder (Supabase storage returns folders with null ID)
          await processDir(path.isEmpty ? item.name : '$path/${item.name}');
        } else {
          // It's a file
          // We need to reconstruct the full relative path
          final fullPath = path.isEmpty ? item.name : '$path/${item.name}';
          // Create a new FileObject with the full relative path as name
          files.add(
            FileObject(
              name: fullPath,
              bucketId: item.bucketId,
              owner: item.owner,
              id: item.id,
              updatedAt: item.updatedAt,
              createdAt: item.createdAt,
              lastAccessedAt: item.lastAccessedAt,
              metadata: item.metadata,
              buckets:
                  null, // Required parameter in newer storage_client versions
            ),
          );
        }
      }
    }

    await processDir(prefix);
    return files;
  }

  /// Convert local path to cloud storage path
  /// Format: {doctor_id}/{patient_id}/{document_type}/{session_folder}/{filename}
  static String? _getCloudPath(String localPath) {
    final doctorId = SupabaseAuthService.currentUser?.id;
    if (doctorId == null) return null;

    // Remove leading slash and "patients/" prefix
    String cleanPath = localPath;
    if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
    if (cleanPath.startsWith('patients/')) {
      cleanPath = cleanPath.substring('patients/'.length);
    }

    // Path format: {patient_id}/session_notes/session_1/notes.sbn2
    // Convert to: {doctor_id}/{patient_id}/session_notes/session_1/notes.sbn2
    return '$doctorId/$cleanPath';
  }

  /// Upload assets folder (.sba) for a .sbn2 file
  static Future<void> _uploadAssetsFolder(
    String localSbn2Path,
    String cloudSbn2Path,
  ) async {
    try {
      // Assets folder has same name as .sbn2 but with .sba extension
      final localAssetsPath =
          '${localSbn2Path.substring(0, localSbn2Path.length - 5)}.sba';
      final cloudAssetsPath =
          '${cloudSbn2Path.substring(0, cloudSbn2Path.length - 5)}.sba';

      final assetsDir = Directory(
        FileManager.documentsDirectory + localAssetsPath,
      );
      if (!await assetsDir.exists()) {
        log.fine('No assets folder for: $localSbn2Path');
        return;
      }

      log.info('Uploading assets folder: $localAssetsPath');

      // Upload all files in assets folder
      await for (final entity in assetsDir.list(recursive: false)) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          final cloudAssetPath = '$cloudAssetsPath/$fileName';
          final bytes = await entity.readAsBytes();

          await supabase.storage
              .from('medical_notes')
              .uploadBinary(
                cloudAssetPath,
                bytes,
                fileOptions: const FileOptions(upsert: true),
              );

          log.fine('Uploaded asset: $fileName');
        }
      }

      log.info('Completed assets upload for: $localSbn2Path');
    } catch (e, stackTrace) {
      log.warning(
        'Failed to upload assets folder: $localSbn2Path',
        e,
        stackTrace,
      );
      // Don't rethrow - assets are optional
    }
  }

  /// Download assets folder (.sba) for a .sbn2 file
  static Future<void> _downloadAssetsFolder(
    String cloudSbn2Path,
    String localSbn2Path,
  ) async {
    try {
      final cloudAssetsPath =
          '${cloudSbn2Path.substring(0, cloudSbn2Path.length - 5)}.sba';
      final localAssetsPath =
          '${localSbn2Path.substring(0, localSbn2Path.length - 5)}.sba';

      log.info('Downloading assets folder: $cloudAssetsPath');

      // List assets
      final assetFiles = await supabase.storage
          .from('medical_notes')
          .list(path: cloudAssetsPath);

      if (assetFiles.isEmpty) {
        log.fine('No assets found for: $cloudSbn2Path');
        return;
      }

      // Create local assets directory
      final assetsDir = Directory(
        FileManager.documentsDirectory + localAssetsPath,
      );
      await assetsDir.create(recursive: true);

      // Download each asset
      for (final file in assetFiles) {
        if (file.name.isEmpty) continue;

        final cloudAssetPath = '$cloudAssetsPath/${file.name}';
        final localAssetPath = '$localAssetsPath/${file.name}';

        final bytes = await supabase.storage
            .from('medical_notes')
            .download(cloudAssetPath);
        final localFile = File(FileManager.documentsDirectory + localAssetPath);
        await localFile.writeAsBytes(bytes);

        log.fine('Downloaded asset: ${file.name}');
      }

      log.info('Completed assets download for: $localSbn2Path');
    } catch (e, stackTrace) {
      log.warning(
        'Failed to download assets folder: $cloudSbn2Path',
        e,
        stackTrace,
      );
      // Don't rethrow - assets are optional
    }
  }

  /// Delete a document from cloud storage by cloud path
  static Future<void> deleteCloudDocument(String cloudPath) async {
    try {
      log.info('Deleting document: $cloudPath');

      await supabase.storage.from('medical_notes').remove([cloudPath]);

      // If this is a .sbn2 file, also delete the .sba assets folder
      if (cloudPath.endsWith('.sbn2')) {
        final cloudAssetsPath =
            '${cloudPath.substring(0, cloudPath.length - 5)}.sba';
        try {
          final assetFiles = await supabase.storage
              .from('medical_notes')
              .list(path: cloudAssetsPath);
          if (assetFiles.isNotEmpty) {
            final assetPaths = assetFiles
                .where((f) => f.name.isNotEmpty)
                .map((f) => '$cloudAssetsPath/${f.name}')
                .toList();
            await supabase.storage.from('medical_notes').remove(assetPaths);
          }
        } catch (e) {
          log.warning('Failed to delete assets folder: $cloudAssetsPath', e);
        }
      }

      log.info('Successfully deleted: $cloudPath');
    } catch (e, stackTrace) {
      log.severe('Failed to delete document: $cloudPath', e, stackTrace);
      rethrow;
    }
  }

  /// Queue a file for upload (to be processed when online)
  /// This is a simple implementation - for production, use a proper queue system
  static void queueUpload(String localPath) {
    log.info('Queueing upload (immediate): $localPath');
    // For now, just attempt upload immediately
    // TODO: Implement proper offline queue with retry logic
    uploadDocument(localPath).catchError((error) {
      log.warning('Failed to upload queued file: $localPath', error);
      // Queue for retry later
    });
  }
}
