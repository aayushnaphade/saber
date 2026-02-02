/// User profile model matching Supabase schema
class UserProfile {
  final String id;
  final String? displayName;
  final String? qualification;
  final String? registrationNumber;
  final String? signatureUrl;
  final String? avatarUrl;
  final String? role;
  final bool receptionMode;

  const UserProfile({
    required this.id,
    this.displayName,
    this.qualification,
    this.registrationNumber,
    this.signatureUrl,
    this.avatarUrl,
    this.role,
    this.receptionMode = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name']?.toString(),
      qualification: json['qualification']?.toString(),
      registrationNumber: json['registration_number']?.toString(),
      signatureUrl: json['signature_url']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      role: json['role']?.toString(),
      receptionMode: json['reception_mode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'qualification': qualification,
      'registration_number': registrationNumber,
      'signature_url': signatureUrl,
      'avatar_url': avatarUrl,
      'role': role,
      'reception_mode': receptionMode,
    };
  }
}

/// Clinic model matching Supabase schema
class Clinic {
  final String id;
  final String doctorId;
  final String name;
  final String? address;
  final String? phone;
  final String? website;
  final String? logoUrl;

  const Clinic({
    required this.id,
    required this.doctorId,
    required this.name,
    this.address,
    this.phone,
    this.website,
    this.logoUrl,
  });

  factory Clinic.fromJson(Map<String, dynamic> json) {
    return Clinic(
      id: json['id']?.toString() ?? '',
      doctorId: json['doctor_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      website: json['website']?.toString(),
      logoUrl: json['logo_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'name': name,
      'address': address,
      'phone': phone,
      'website': website,
      'logo_url': logoUrl,
    };
  }
}
