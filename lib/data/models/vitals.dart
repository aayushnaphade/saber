class Vitals {
  final String id;
  final String patientId;
  final int? systolic;
  final int? diastolic;
  final int? heartRate;
  final double? weight;
  final DateTime capturedAt;

  Vitals({
    required this.id,
    required this.patientId,
    this.systolic,
    this.diastolic,
    this.heartRate,
    this.weight,
    required this.capturedAt,
  });

  factory Vitals.fromJson(Map<String, dynamic> json) {
    return Vitals(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      systolic: json['systolic'] as int?,
      diastolic: json['diastolic'] as int?,
      heartRate: json['heart_rate'] as int?,
      weight: (json['weight'] as num?)?.toDouble(),
      capturedAt: DateTime.parse(json['captured_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'systolic': systolic,
      'diastolic': diastolic,
      'heart_rate': heartRate,
      'weight': weight,
      'captured_at': capturedAt.toUtc().toIso8601String(),
    };
  }
}
