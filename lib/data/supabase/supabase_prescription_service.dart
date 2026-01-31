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

      // If consultationId is missing, try to find an active one for today
      if (resolvedConsultationId == null) {
        _log.info('Consultation ID missing, searching for active consultation...');
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
        
        final consultation = await supabase
            .from('consultations')
            .select('id')
            .eq('patient_id', patientId)
            .eq('doctor_id', user.id)
            .gte('created_at', startOfDay)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
            
        if (consultation != null) {
          resolvedConsultationId = consultation['id'] as String;
          _log.info('Resolved consultation ID: $resolvedConsultationId');
        }
      }

      // If still null, the database WILL error because it's not-nullable.
      // We'll let it fail or log a more specific error.
      if (resolvedConsultationId == null) {
        throw Exception(
          'Cannot create prescription: No active consultation found for this session. '
          'Please ensure the patient is checked in via the dashboard.'
        );
      }

      final prescriptionData = {
        'patient_id': patientId,
        'doctor_id': user.id,
        'consultation_id': resolvedConsultationId,
        'content': {
          'medications': medications,
          'patient_name': patientName,
        },
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
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
