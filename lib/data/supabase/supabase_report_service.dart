import 'package:saber/data/supabase/supabase_client.dart';

class ClinicalReport {
  final String id;
  final String patientId;
  final String doctorId;
  final DateTime createdAt;
  final DateTime sessionDate;
  final String? sourceDocumentPath;
  final Map<String, dynamic> structuredData;
  final String? markdownContent;

  ClinicalReport({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.createdAt,
    required this.sessionDate,
    this.sourceDocumentPath,
    required this.structuredData,
    this.markdownContent,
  });

  factory ClinicalReport.fromJson(Map<String, dynamic> json) {
    return ClinicalReport(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      doctorId: json['doctor_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      sessionDate: DateTime.parse(json['session_date'] as String),
      sourceDocumentPath: json['source_document_path'] as String?,
      structuredData: json['structured_data'] as Map<String, dynamic>,
      markdownContent: json['markdown_content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'created_at': createdAt.toIso8601String(),
      'session_date': sessionDate.toIso8601String().split('T')[0],
      'source_document_path': sourceDocumentPath,
      'structured_data': structuredData,
      'markdown_content': markdownContent,
    };
  }
}

class SupabaseReportService {
  static Future<ClinicalReport> createReport({
    required String patientId,
    required Map<String, dynamic> structuredData,
    required String markdownContent,
    String? sourceDocumentPath,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final response = await supabase.from('clinical_reports').insert({
      'patient_id': patientId,
      'doctor_id': user.id,
      'session_date': DateTime.now().toIso8601String().split('T')[0],
      'source_document_path': sourceDocumentPath,
      'structured_data': structuredData,
      'markdown_content': markdownContent,
    }).select().single();

    return ClinicalReport.fromJson(response);
  }

  static Future<List<ClinicalReport>> getReportsForPatient(String patientId) async {
    final response = await supabase
        .from('clinical_reports')
        .select()
        .eq('patient_id', patientId)
        .order('session_date', ascending: false);
    
    return (response as List).map((e) => ClinicalReport.fromJson(e)).toList();
  }
}
