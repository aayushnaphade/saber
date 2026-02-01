import 'package:saber/data/models/vitals.dart';
import 'package:saber/data/supabase/supabase_client.dart';

class SupabaseVitalsService {
  static const String _tableName = 'vitals';

  static Future<void> saveVitals({
    required String patientId,
    int? systolic,
    int? diastolic,
    int? heartRate,
    double? weight,
  }) async {
    await supabase.from(_tableName).insert({
      'patient_id': patientId,
      'systolic': systolic,
      'diastolic': diastolic,
      'heart_rate': heartRate,
      'weight': weight,
    });
  }

  static Future<List<Vitals>> getVitalsHistory(String patientId) async {
    final response = await supabase
        .from(_tableName)
        .select()
        .eq('patient_id', patientId)
        .order('captured_at', ascending: false) // Newest first
        .limit(50);

    return (response as List).map((e) => Vitals.fromJson(e)).toList();
  }

  static Future<Vitals?> getLatestVitals(String patientId) async {
    final response = await supabase
        .from(_tableName)
        .select()
        .eq('patient_id', patientId)
        .order('captured_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return Vitals.fromJson(response);
  }
}
