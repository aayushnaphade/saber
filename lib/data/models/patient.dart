/// Patient data model matching Supabase schema
class Patient {
  final String id;
  final DateTime createdAt;
  final String fullName;
  final int? age;
  final String? gender;
  final PatientStatus status;
  final DateTime? lastVisit;
  final String doctorId;

  // Additional fields
  final String? phoneNumber;
  final String? email;
  final Map<String, dynamic>? medicalHistory;
  final bool isActive;

  // Demographic fields
  final double? weight; // in kg

  final String? allergies;
  final String? address;
  final String? referencedBy;
  final String? registrationNumber;

  const Patient({
    required this.id,
    required this.createdAt,
    required this.fullName,
    this.age,
    this.gender,
    required this.status,
    this.lastVisit,
    required this.doctorId,
    this.phoneNumber,
    this.email,
    this.medicalHistory,
    this.isActive = true,
    this.weight,

    this.allergies,
    this.address,
    this.referencedBy,
    this.registrationNumber,
  });

  /// Create Patient from Supabase JSON
  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      fullName: json['full_name']?.toString() ?? '',
      age: json['age'] as int?,
      gender: json['gender']?.toString(),
      status: PatientStatus.fromString(json['status']?.toString() ?? 'waiting'),
      lastVisit: json['last_visit'] != null
          ? DateTime.parse(json['last_visit'].toString())
          : null,
      doctorId: json['doctor_id']?.toString() ?? '',
      phoneNumber: (json['phone_number'] ?? json['contact_number'])?.toString(),
      email: json['email']?.toString(),
      medicalHistory: json['medical_history'] as Map<String, dynamic>?,
      isActive: json['is_active'] as bool? ?? true,
      weight: json['weight'] != null
          ? (json['weight'] as num).toDouble()
          : null,

      allergies: json['allergies']?.toString(),
      address: json['address']?.toString(),
      referencedBy: json['referenced_by']?.toString(),
      registrationNumber: _parseRegistrationNumber(json),
    );
  }

  static String? _parseRegistrationNumber(Map<String, dynamic> json) {
    final intake = json['psychiatric_intakes'];
    if (intake is List && intake.isNotEmpty) {
      return intake[0]['registration_number']?.toString();
    } else if (intake is Map) {
      return intake['registration_number']?.toString();
    }
    return json['registration_number']?.toString();
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toUtc().toIso8601String(),
      'full_name': fullName,
      'age': age,
      'gender': gender,
      'status': status.value,
      'last_visit': lastVisit?.toUtc().toIso8601String(),
      'doctor_id': doctorId,
      'phone_number': phoneNumber,
      'email': email,
      'medical_history': medicalHistory,
      'is_active': isActive,
      'weight': weight,

      'allergies': allergies,
      'address': address,
      'referenced_by': referencedBy,
      'registration_number': registrationNumber,
    };
  }

  /// Create JSON for INSERT/UPDATE (without auto-generated fields)
  Map<String, dynamic> toInsertJson() {
    return {
      'full_name': fullName,
      'age': age,
      'gender': gender,
      'status': status.value,
      'last_visit': lastVisit?.toUtc().toIso8601String(),
      'doctor_id': doctorId,
      'phone_number': phoneNumber,
      'email': email,
      'medical_history': medicalHistory,
      'is_active': isActive,
      'weight': weight,

      'allergies': allergies,
      'address': address,
      'referenced_by': referencedBy,
    };
  }

  /// Get local folder path for this patient
  String get localFolderPath => '/patients/$id';

  /// Get folder path for specific document type
  String documentFolderPath(DocumentType type) {
    return '$localFolderPath/${type.folderName}';
  }

  /// Copy with new values
  Patient copyWith({
    String? id,
    DateTime? createdAt,
    String? fullName,
    int? age,
    String? gender,
    PatientStatus? status,
    DateTime? lastVisit,
    String? doctorId,
    String? phoneNumber,
    String? email,
    Map<String, dynamic>? medicalHistory,
    bool? isActive,
    double? weight,

    String? allergies,
    String? address,
    String? referencedBy,
    String? registrationNumber,
  }) {
    return Patient(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      status: status ?? this.status,
      lastVisit: lastVisit ?? this.lastVisit,
      doctorId: doctorId ?? this.doctorId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      isActive: isActive ?? this.isActive,
      weight: weight ?? this.weight,
      allergies: allergies ?? this.allergies,
      address: address ?? this.address,
      referencedBy: referencedBy ?? this.referencedBy,
      registrationNumber: registrationNumber ?? this.registrationNumber,
    );
  }

  @override
  String toString() => 'Patient(id: $id, fullName: $fullName, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Patient && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Patient status enum matching DB CHECK constraint
enum PatientStatus {
  waiting('waiting'),
  active('active'), // Was in_consultation
  archived('archived'),
  discharged('discharged'); // Was completed

  final String value;
  const PatientStatus(this.value);

  static PatientStatus fromString(String value) {
    // Handle legacy values mapping
    if (value == 'in_consultation') return PatientStatus.active;
    if (value == 'completed') return PatientStatus.discharged;

    return PatientStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => PatientStatus.waiting,
    );
  }

  @override
  String toString() => value;
}

/// Document type for organizing patient files
enum DocumentType {
  examinationReport('examination_reports', 'Examination Reports'),
  prescription('prescriptions', 'Prescriptions'),
  sessionNote('session_notes', 'Session Notes');

  final String folderName;
  final String displayName;

  const DocumentType(this.folderName, this.displayName);

  static DocumentType fromFolderName(String name) {
    return DocumentType.values.firstWhere(
      (type) => type.folderName == name,
      orElse: () => DocumentType.sessionNote,
    );
  }
}

/// Session information model
class SessionInfo {
  final int sessionNumber;
  final String folderName;
  final int fileCount;
  final DateTime createdDate;

  SessionInfo({
    required this.sessionNumber,
    required this.folderName,
    required this.fileCount,
    required this.createdDate,
  });
}
