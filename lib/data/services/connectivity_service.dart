import 'dart:async';

import 'package:logging/logging.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/supabase/supabase_auth_service.dart';
import 'package:saber/data/supabase/supabase_client.dart';

class ConnectivityService {
  static final log = Logger('ConnectivityService');
  static Timer? _connectivityTimer;

  static void initialize() {
    _checkConnectivity();
    // Check connectivity every 10 seconds
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnectivity(),
    );
  }

  static Future<void> _checkConnectivity() async {
    // Only check if doctor is logged in
    if (SupabaseAuthService.currentUser == null) {
      if (!stows.isOnline.value) {
        log.info('User not logged in, setting isOnline to true');
        stows.isOnline.value = true;
      }
      return;
    }

    try {
      // Try to ping Supabase to check connectivity
      // We use a simple select on profiles which should always be available
      await supabase
          .from('profiles')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));

      if (!stows.isOnline.value) {
        log.info('Internet connection restored');
        stows.isOnline.value = true;
      }
    } catch (e) {
      if (stows.isOnline.value) {
        log.warning('Internet connection lost: $e');
        stows.isOnline.value = false;
      }
    }
  }

  static void dispose() {
    _connectivityTimer?.cancel();
  }
}
