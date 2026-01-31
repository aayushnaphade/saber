import 'package:logging/logging.dart';
import 'package:saber/data/models/psychiatric_intake.dart';
import 'package:saber/data/supabase/supabase_client.dart';

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

      final intake = PsychiatricIntake.fromJson(response as Map<String, dynamic>);
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
  static Future<PsychiatricIntake> upsertIntake(PsychiatricIntake intake) async {
    try {
      log.info('Upserting intake for patient: ${intake.patientId}');

      final data = intake.toJson();
      
      final response = await supabase
          .from('psychiatric_intakes')
          .upsert(data, onConflict: 'patient_id')
          .select()
          .single();

      final savedIntake = PsychiatricIntake.fromJson(response as Map<String, dynamic>);
      log.info('Saved intake for patient: ${intake.patientId}');
      return savedIntake;
    } catch (e) {
      log.severe('Failed to upsert intake for patient: ${intake.patientId}', e);
      rethrow;
    }
  }

  /// Create a new psychiatric intake
  static Future<PsychiatricIntake> createIntake(PsychiatricIntake intake) async {
    try {
      log.info('Creating intake for patient: ${intake.patientId}');

      final data = intake.toJson();
      
      final response = await supabase
          .from('psychiatric_intakes')
          .insert(data)
          .select()
          .single();

      final savedIntake = PsychiatricIntake.fromJson(response as Map<String, dynamic>);
      log.info('Created intake for patient: ${intake.patientId}');
      return savedIntake;
    } catch (e) {
      log.severe('Failed to create intake for patient: ${intake.patientId}', e);
      rethrow;
    }
  }

  /// Update existing psychiatric intake
  static Future<PsychiatricIntake> updateIntake(PsychiatricIntake intake) async {
    try {
      log.info('Updating intake for patient: ${intake.patientId}');

      final data = intake.toJson();
      
      final response = await supabase
          .from('psychiatric_intakes')
          .update(data)
          .eq('id', intake.id)
          .select()
          .single();

      final savedIntake = PsychiatricIntake.fromJson(response as Map<String, dynamic>);
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

      await supabase
          .from('psychiatric_intakes')
          .delete()
          .eq('id', intakeId);

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
          .map((json) => PsychiatricIntake.fromJson(json as Map<String, dynamic>))
          .toList();

      log.info('Fetched ${intakes.length} intakes');
      return intakes;
    } catch (e) {
      log.severe('Failed to fetch all intakes', e);
      rethrow;
    }
  }
}
