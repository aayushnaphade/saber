import 'package:saber/data/supabase/supabase_client.dart';
import 'package:logging/logging.dart';

class StaffMember {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final DateTime createdAt;

  StaffMember({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory StaffMember.fromMap(Map<String, dynamic> map) {
    return StaffMember(
      id: map['id'] as String,
      fullName: map['full_name'] as String? ?? 'Unnamed',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'receptionist',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class SupabaseTeamService {
  static final _log = Logger('SupabaseTeamService');

  static Future<List<StaffMember>> getTeamMembers() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      final data = await supabase
          .from('profiles')
          .select('*')
          .eq('doctor_id', user.id)
          .order('created_at', ascending: false);

      return (data as List).map((m) => StaffMember.fromMap(m)).toList();
    } catch (e) {
      _log.severe('Error fetching team members: $e');
      rethrow;
    }
  }

  static Future<void> addStaffMember({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Note: Full staff creation requires an admin client or a custom RPC/Edge Function
      // Since Saber is a client app, it can't directly use admin.createUser.
      // We should ideally call a Supabase Edge Function or an RPC that handles this safely.
      // For now, we'll assume there is an Edge Function or we'll provide the logic to call it.

      final response = await supabase.functions.invoke(
        'create-staff-member',
        body: {
          'action': 'create',
          'fullName': fullName,
          'email': email,
          'password': password,
          'role': role,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to create staff member: ${response.data}');
      }
    } catch (e) {
      _log.severe('Error adding staff member: $e');
      rethrow;
    }
  }

  static Future<void> revokeStaffMember(String staffId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final response = await supabase.functions.invoke(
        'create-staff-member',
        body: {'action': 'revoke', 'staffId': staffId},
      );

      if (response.status != 200) {
        throw Exception('Failed to revoke staff member: ${response.data}');
      }
    } catch (e) {
      _log.severe('Error revoking staff member: $e');
      rethrow;
    }
  }
}
