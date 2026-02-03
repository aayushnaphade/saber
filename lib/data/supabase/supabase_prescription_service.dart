import 'package:saber/data/supabase/supabase_client.dart';
import 'package:logging/logging.dart';

class SupabasePrescriptionService {
  static final _log = Logger('SupabasePrescriptionService');

  /// Creates a new prescription in Supabase
  static Future<void> createPrescription({
    required String patientId,
    String? consultationId,
    required List<Map<String, dynamic>> medications,
    String? patientName,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      String? resolvedConsultationId = consultationId;

      // If consultationId is missing, try to find an active or recent one
      if (resolvedConsultationId == null) {
        _log.info(
          'Consultation ID missing, searching for active consultation...',
        );

        // 1. Search for an in_progress or waiting consultation first
        var consultation = await supabase
            .from('consultations')
            .select('id')
            .eq('patient_id', patientId)
            .eq('doctor_id', user.id)
            .inFilter('status', ['in_progress', 'waiting'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        // 2. Fallback to any consultation from today if no active one exists
        if (consultation == null) {
          final today = DateTime.now();
          final startOfDay = DateTime(
            today.year,
            today.month,
            today.day,
          ).toUtc().toIso8601String();

          consultation = await supabase
              .from('consultations')
              .select('id')
              .eq('patient_id', patientId)
              .eq('doctor_id', user.id)
              .gte('created_at', startOfDay)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
        }

        if (consultation != null) {
          resolvedConsultationId = consultation['id'] as String;
          _log.info('Resolved consultation ID: $resolvedConsultationId');
        } else {
          // 3. Last resort: Create a walk-in consultation automatically
          // This ensures the prescription is NEVER lost even if the doctor
          // started a session in a way that bypassed checking in.
          _log.warning(
            'No active or recent consultation found. Auto-creating walk-in consultation...',
          );
          try {
            final response = await supabase
                .from('consultations')
                .insert({
                  'patient_id': patientId,
                  'doctor_id': user.id,
                  'status': 'in_progress',
                  'scheduled_time': DateTime.now().toUtc().toIso8601String(),
                  'appointment_type': 'walk-in',
                })
                .select()
                .single();
            resolvedConsultationId = response['id'];
            _log.info('Auto-created consultation ID: $resolvedConsultationId');
          } catch (e) {
            _log.severe('Failed to auto-create consultation', e);
            // If even this fails, we have to throw, but this is unlikely
            throw Exception(
              'Failed to create prescription: No consultation record could be found or created. '
              'Please ensure the patient is correctly registered.',
            );
          }
        }
      }

      final prescriptionData = {
        'patient_id': patientId,
        'doctor_id': user.id,
        'consultation_id': resolvedConsultationId,
        'content': {'medications': medications, 'patient_name': patientName},
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      _log.info('Creating prescription for patient: $patientId');

      await supabase.from('prescriptions').insert(prescriptionData);

      _log.info('Prescription created successfully');
    } catch (e) {
      _log.severe('Failed to create prescription', e);
      rethrow;
    }
  }
}
