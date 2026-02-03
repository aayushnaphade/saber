import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton Supabase client for the application
class SupabaseClientConfig {
  static const supabaseUrl = 'https://hdrzwpsxljhcknmwstyq.supabase.co';
  static const supabaseAnonKey =
      'sb_publishable_R0EbhLSm11S0H_Dxj8xbQQ_LMxckpyv';

  static SupabaseClient? _instance;

  /// Get the initialized Supabase client instance
  static SupabaseClient get instance {
    if (_instance == null) {
      throw Exception(
        'Supabase client not initialized. Call initialize() first.',
      );
    }
    return _instance!;
  }

  /// Initialize the Supabase client
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        timeout: Duration(seconds: 20),
      ),
    );
    _instance = Supabase.instance.client;
  }

  /// Check if client is initialized
  static bool get isInitialized => _instance != null;
}

/// Global accessor for Supabase client
SupabaseClient get supabase => SupabaseClientConfig.instance;
