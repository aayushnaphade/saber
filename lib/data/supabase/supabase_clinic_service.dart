import 'package:logging/logging.dart';
import 'package:saber/data/models/profile.dart';
import 'package:saber/data/supabase/supabase_client.dart';

/// Service for managing clinic data in Supabase
class SupabaseClinicService {
  static final log = Logger('SupabaseClinicService');

  /// Get clinic for a specific doctor
  static Future<Clinic?> getClinicForDoctor(String doctorId) async {
    try {
      log.info('Fetching clinic for doctor: $doctorId');

      final response = await supabase
          .from('clinics')
          .select()
          .eq('doctor_id', doctorId)
          .maybeSingle();

      if (response == null) {
        log.info('No clinic found for doctor: $doctorId');
        return null;
      }

      return Clinic.fromJson(response);
    } catch (e) {
      log.severe('Failed to fetch clinic', e);
      rethrow;
    }
  }

  /// Create or update clinic info
  static Future<Clinic> upsertClinic(Clinic clinic) async {
    return upsertClinicData(clinic.toJson());
  }

  /// Create or update clinic info from raw map
  static Future<Clinic> upsertClinicData(
    Map<String, dynamic> clinicData,
  ) async {
    try {
      log.info('Upserting clinic for doctor: ${clinicData['doctor_id']}');

      // Remove ID if it's explicitly null or empty string to let Postgres generate it
      final dataToSave = Map<String, dynamic>.from(clinicData);
      if (dataToSave['id'] == '' || dataToSave['id'] == null) {
        dataToSave.remove('id');
      }

      final response = await supabase
          .from('clinics')
          .upsert(dataToSave)
          .select()
          .single();

      return Clinic.fromJson(response);
    } catch (e) {
      log.severe('Failed to upsert clinic', e);
      rethrow;
    }
  }

  /// Update specifically the logo URL
  static Future<void> updateLogoUrl(String clinicId, String logoUrl) async {
    try {
      log.info('Updating logo for clinic: $clinicId');
      await supabase
          .from('clinics')
          .update({'logo_url': logoUrl})
          .eq('id', clinicId);
    } catch (e) {
      log.severe('Failed to update clinic logo', e);
      rethrow;
    }
  }
}
