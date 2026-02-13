import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/supabase/supabase_auth_service.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConnectivityService with WidgetsBindingObserver {
  static final log = Logger('ConnectivityService');
  static Timer? _connectivityTimer;
  static var _isChecking = false;

  // Singleton instance to handle lifecycle observer
  static final _instance = ConnectivityService._();
  ConnectivityService._();

  static void initialize() {
    WidgetsBinding.instance.addObserver(_instance);

    _checkConnectivity();
    // Check connectivity every 20 seconds to be less intrusive
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkConnectivity(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      log.info('App resumed, triggering delayed connectivity check');
      // Give the OS 2 seconds to re-establish WiFi/Cellular after wake-up
      Future.delayed(const Duration(seconds: 2), () {
        _checkConnectivity();
      });
    }
  }

  static Future<void> _checkConnectivity() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
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
            .timeout(const Duration(seconds: 8)); // Slightly shorter timeout

        if (!stows.isOnline.value) {
          log.info('Internet connection restored (Supabase reachable)');
          stows.isOnline.value = true;
        }
      } catch (e) {
        // If we got a response from Supabase (even an error like 401/403),
        // it means we ARE online because the server responded.
        if (e is PostgrestException || e is AuthException) {
          if (!stows.isOnline.value) {
            log.info(
              'Internet connection confirmed (Supabase responded with error: $e)',
            );
            stows.isOnline.value = true;
          }
          return;
        }

        // It might be a network error (SocketException, TimeoutException, etc.).
        // Let's verify with a neutral global ping.
        var globallyOnline = await _verifyGlobalConnectivity();

        // RESILIENCE: If global ping fails and we think we were online,
        // retry once after a small delay before declaring we are offline.
        // This handles cases where the device just woke up and the network is laggy.
        if (!globallyOnline && stows.isOnline.value) {
          log.info('Global ping failed, retrying in 3 seconds...');
          await Future.delayed(const Duration(seconds: 3));
          globallyOnline = await _verifyGlobalConnectivity();
        }

        if (globallyOnline) {
          if (!stows.isOnline.value) {
            log.info(
              'Supabase unreachable, but global internet is available. Setting isOnline to true.',
            );
            stows.isOnline.value = true;
          }
        } else {
          if (stows.isOnline.value) {
            log.warning('Internet connection lost: $e');
            stows.isOnline.value = false;
          }
        }
      }
    } finally {
      _isChecking = false;
    }
  }

  /// Verifies if the device has global internet access by hitting a reliable endpoint.
  static Future<bool> _verifyGlobalConnectivity() async {
    try {
      // HEAD request to Google is light and fast
      final response = await http
          .head(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      // Any response below 500 means we reached a server
      return response.statusCode < 500;
    } catch (_) {
      try {
        // Fallback to Cloudflare if Google is blocked/unreachable
        final response = await http
            .head(Uri.parse('https://1.1.1.1'))
            .timeout(const Duration(seconds: 5));
        return response.statusCode < 500;
      } catch (_) {
        return false;
      }
    }
  }

  static void dispose() {
    WidgetsBinding.instance.removeObserver(_instance);
    _connectivityTimer?.cancel();
  }
}
