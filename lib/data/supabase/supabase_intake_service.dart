import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:saber/data/models/psychiatric_intake.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing psychiatric intake data in Supabase
class SupabaseIntakeService {
  static final log = Logger('SupabaseIntakeService');

  /// Get psychiatric intake for a patient
  static Future<PsychiatricIntake?> getIntake(String patientId) async {
    try {
      log.info('Fetching psychiatric intake for patient: $patientId');

      final response = await supabase
          .from('psychiatric_intakes')
          .select()
          .eq('patient_id', patientId)
          .maybeSingle();

      if (response == null) {
        log.info('No intake found for patient: $patientId');
        return null;
      }

      final intake = PsychiatricIntake.fromJson(response);
      log.info('Fetched intake for patient: $patientId');
      return intake;
    } catch (e) {
      log.severe('Failed to fetch intake for patient: $patientId', e);
      rethrow;
    }
  }

  /// Check if patient has an intake form
  static Future<bool> hasIntake(String patientId) async {
    try {
      log.info('Checking intake exists for patient: $patientId');

      final response = await supabase
          .from('psychiatric_intakes')
          .select('id')
          .eq('patient_id', patientId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      log.severe('Failed to check intake for patient: $patientId', e);
      return false;
    }
  }

  /// Create or update psychiatric intake
  static Future<PsychiatricIntake> upsertIntake(
    PsychiatricIntake intake,
  ) async {
    try {
      log.info('Upserting intake for patient: ${intake.patientId}');

      final data = intake.toJson();

      final response = await supabase
          .from('psychiatric_intakes')
          .upsert(data, onConflict: 'patient_id')
          .select()
          .single();

      final savedIntake = PsychiatricIntake.fromJson(response);
      log.info('Saved intake for patient: ${intake.patientId}');
      return savedIntake;
    } catch (e) {
      log.severe('Failed to upsert intake for patient: ${intake.patientId}', e);
      rethrow;
    }
  }

  /// Create a new psychiatric intake
  static Future<PsychiatricIntake> createIntake(
    PsychiatricIntake intake,
  ) async {
    try {
      log.info('Creating intake for patient: ${intake.patientId}');

      final data = intake.toJson();

      final response = await supabase
          .from('psychiatric_intakes')
          .insert(data)
          .select()
          .single();

      final savedIntake = PsychiatricIntake.fromJson(response);
      log.info('Created intake for patient: ${intake.patientId}');
      return savedIntake;
    } catch (e) {
      log.severe('Failed to create intake for patient: ${intake.patientId}', e);
      rethrow;
    }
  }

  /// Update existing psychiatric intake
  static Future<PsychiatricIntake> updateIntake(
    PsychiatricIntake intake,
  ) async {
    try {
      log.info('Updating intake for patient: ${intake.patientId}');

      final data = intake.toJson();

      final response = await supabase
          .from('psychiatric_intakes')
          .update(data)
          .eq('id', intake.id)
          .select()
          .single();

      final savedIntake = PsychiatricIntake.fromJson(response);
      log.info('Updated intake for patient: ${intake.patientId}');
      return savedIntake;
    } catch (e) {
      log.severe('Failed to update intake for patient: ${intake.patientId}', e);
      rethrow;
    }
  }

  /// Delete psychiatric intake
  static Future<void> deleteIntake(String intakeId) async {
    try {
      log.info('Deleting intake: $intakeId');

      await supabase.from('psychiatric_intakes').delete().eq('id', intakeId);

      log.info('Deleted intake: $intakeId');
    } catch (e) {
      log.severe('Failed to delete intake: $intakeId', e);
      rethrow;
    }
  }

  /// Get all intakes for a doctor (useful for reporting)
  static Future<List<PsychiatricIntake>> getAllIntakes() async {
    try {
      log.info('Fetching all intakes');

      final response = await supabase
          .from('psychiatric_intakes')
          .select()
          .order('created_at', ascending: false);

      final intakes = (response as List)
          .map(
            (json) => PsychiatricIntake.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      log.info('Fetched ${intakes.length} intakes');
      return intakes;
    } catch (e) {
      log.severe('Failed to fetch all intakes', e);
      rethrow;
    }
  }

  // ============================================================================
  // PHOTO STORAGE METHODS (for intake form photo imports)
  // ============================================================================

  /// Upload intake form photos to Supabase Storage
  /// Returns the file paths in storage
  static Future<Map<String, String>> uploadIntakeFormPhotos({
    required String patientId,
    required Uint8List frontPhotoBytes,
    required Uint8List backPhotoBytes,
  }) async {
    try {
      log.info('Uploading intake form photos for patient: $patientId');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final frontPath = 'intake-forms/$patientId/front_$timestamp.png';
      final backPath = 'intake-forms/$patientId/back_$timestamp.png';

      // Upload front photo
      await supabase.storage
          .from('intake-form-photos')
          .uploadBinary(
            frontPath,
            frontPhotoBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: false,
            ),
          );

      log.info('Uploaded front photo: $frontPath');

      // Upload back photo
      await supabase.storage
          .from('intake-form-photos')
          .uploadBinary(
            backPath,
            backPhotoBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: false,
            ),
          );

      log.info('Uploaded back photo: $backPath');

      return {'front': frontPath, 'back': backPath};
    } catch (e) {
      log.severe(
        'Failed to upload intake form photos for patient: $patientId',
        e,
      );
      rethrow;
    }
  }

  /// Get signed URL for intake form photo (valid for 1 hour)
  static Future<String> getIntakeFormPhotoUrl(String filePath) async {
    try {
      log.info('Getting signed URL for: $filePath');

      final url = await supabase.storage
          .from('intake-form-photos')
          .createSignedUrl(filePath, 3600); // 1 hour

      return url;
    } catch (e) {
      log.severe('Failed to get signed URL for: $filePath', e);
      rethrow;
    }
  }

  /// Delete intake form photos from storage
  static Future<void> deleteIntakeFormPhotos(List<String> filePaths) async {
    try {
      log.info('Deleting ${filePaths.length} intake form photos');

      await supabase.storage.from('intake-form-photos').remove(filePaths);

      log.info('Deleted intake form photos');
    } catch (e) {
      log.severe('Failed to delete intake form photos', e);
      rethrow;
    }
  }

  /// Clean up old intake form photos (older than 30 days)
  /// Note: This should be called periodically via a background job
  static Future<void> cleanupOldPhotos() async {
    try {
      log.info('Cleaning up old intake form photos (>30 days)');

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      // List all files in the bucket
      final files = await supabase.storage
          .from('intake-form-photos')
          .list(path: 'intake-forms');

      final filesToDelete = <String>[];

      for (final file in files) {
        // Parse timestamp from filename
        if (file.name.contains('_')) {
          final parts = file.name.split('_');
          if (parts.length >= 2) {
            final timestampStr = parts.last.replaceAll('.png', '');
            try {
              final timestamp = int.parse(timestampStr);
              final fileDate = DateTime.fromMillisecondsSinceEpoch(timestamp);

              if (fileDate.isBefore(thirtyDaysAgo)) {
                filesToDelete.add('intake-forms/${file.name}');
              }
            } catch (e) {
              log.warning(
                'Could not parse timestamp from filename: ${file.name}',
              );
            }
          }
        }
      }

      if (filesToDelete.isNotEmpty) {
        await deleteIntakeFormPhotos(filesToDelete);
        log.info('Cleaned up ${filesToDelete.length} old photos');
      } else {
        log.info('No old photos to clean up');
      }
    } catch (e) {
      log.severe('Failed to cleanup old photos', e);
      rethrow;
    }
  }

  /// Upload a single handwriting image to storage
  static Future<String> uploadHandwritingImage({
    required String patientId,
    required String sectionName,
    required Uint8List imageBytes,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path =
          'intake-forms/$patientId/handwriting/${sectionName}_$timestamp.png';

      await supabase.storage
          .from('intake-form-photos')
          .uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );

      return supabase.storage.from('intake-form-photos').getPublicUrl(path);
    } catch (e) {
      log.severe('Failed to upload handwriting image', e);
      rethrow;
    }
  }
}
