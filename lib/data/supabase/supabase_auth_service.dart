import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;

/// Handles Supabase authentication operations
class SupabaseAuthService {
  static final log = Logger('SupabaseAuthService');

  /// Stream of authentication state changes
  static Stream<supabase_flutter.AuthState> get onAuthStateChange =>
      supabase.auth.onAuthStateChange;

  /// Get current user session
  static supabase_flutter.Session? get currentSession =>
      supabase.auth.currentSession;

  /// Get current user
  static supabase_flutter.User? get currentUser => supabase.auth.currentUser;

  /// Sign in with email and password
  static Future<supabase_flutter.AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      log.info('Attempting to sign in with email: $email');

      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        await _saveSessionToPrefs(response.session!);
        log.info('Sign in successful for user: ${response.user?.id}');
      }

      return response;
    } catch (e) {
      log.severe('Sign in failed', e);
      rethrow;
    }
  }

  /// Sign up with email and password
  static Future<supabase_flutter.AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      log.info('Attempting to sign up with email: $email');

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );

      if (response.session != null) {
        await _saveSessionToPrefs(response.session!);
        log.info('Sign up successful for user: ${response.user?.id}');
      }

      return response;
    } catch (e) {
      log.severe('Sign up failed', e);
      rethrow;
    }
  }

  /// Sign in with magic link (OTP)
  static Future<void> signInWithOtp({required String email}) async {
    try {
      log.info('Sending magic link to: $email');

      await supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: kIsWeb ? null : 'io.supabase.saber://login-callback/',
      );

      log.info('Magic link sent successfully');
    } catch (e) {
      log.severe('Failed to send magic link', e);
      rethrow;
    }
  }

  /// Verify OTP code
  static Future<supabase_flutter.AuthResponse> verifyOtp({
    required String email,
    required String token,
    supabase_flutter.OtpType type = supabase_flutter.OtpType.signup,
  }) async {
    try {
      log.info('Verifying OTP for email: $email with type: $type');

      final response = await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: type,
      );

      if (response.session != null) {
        await _saveSessionToPrefs(response.session!);
        log.info('OTP verification successful');
      }

      return response;
    } catch (e) {
      log.severe('OTP verification failed', e);
      rethrow;
    }
  }

  /// Sign out the current user
  static Future<void> signOut() async {
    try {
      log.info('Signing out user');

      await supabase.auth.signOut();
      await _clearSessionFromPrefs();

      log.info('Sign out successful');
    } catch (e) {
      log.severe('Sign out failed', e);
      rethrow;
    }
  }

  /// Reset password for email
  static Future<void> resetPasswordForEmail(String email) async {
    try {
      log.info('Sending password reset email to: $email');

      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : 'io.supabase.saber://reset-callback/',
      );

      log.info('Password reset email sent successfully');
    } catch (e) {
      log.severe('Failed to send password reset email', e);
      rethrow;
    }
  }

  /// Update user password
  static Future<supabase_flutter.UserResponse> updatePassword(
    String newPassword,
  ) async {
    try {
      log.info('Updating user password');

      final response = await supabase.auth.updateUser(
        supabase_flutter.UserAttributes(password: newPassword),
      );

      log.info('Password updated successfully');
      return response;
    } catch (e) {
      log.severe('Failed to update password', e);
      rethrow;
    }
  }

  /// Refresh the current session
  static Future<supabase_flutter.AuthResponse> refreshSession() async {
    try {
      log.info('Refreshing session');

      final response = await supabase.auth.refreshSession();

      if (response.session != null) {
        await _saveSessionToPrefs(response.session!);
        log.info('Session refreshed successfully');
      }

      return response;
    } catch (e) {
      log.severe('Failed to refresh session', e);
      rethrow;
    }
  }

  /// Save session data to secure storage
  static Future<void> _saveSessionToPrefs(
    supabase_flutter.Session session,
  ) async {
    await Future.wait([
      stows.supabaseUserId.waitUntilRead(),
      stows.supabaseAccessToken.waitUntilRead(),
      stows.supabaseRefreshToken.waitUntilRead(),
      stows.supabaseUserEmail.waitUntilRead(),
    ]);

    stows.supabaseUserId.value = session.user.id;
    stows.supabaseAccessToken.value = session.accessToken;
    stows.supabaseRefreshToken.value = session.refreshToken ?? '';
    stows.supabaseUserEmail.value = session.user.email ?? '';

    log.info('Session saved to preferences');
  }

  /// Clear session data from secure storage
  static Future<void> _clearSessionFromPrefs() async {
    await Future.wait([
      stows.supabaseUserId.waitUntilRead(),
      stows.supabaseAccessToken.waitUntilRead(),
      stows.supabaseRefreshToken.waitUntilRead(),
      stows.supabaseUserEmail.waitUntilRead(),
    ]);

    stows.supabaseUserId.value = '';
    stows.supabaseAccessToken.value = '';
    stows.supabaseRefreshToken.value = '';
    stows.supabaseUserEmail.value = '';

    log.info('Session cleared from preferences');
  }

  /// Try to restore session from stored credentials
  static Future<bool> tryRestoreSession() async {
    try {
      await Future.wait([
        stows.supabaseAccessToken.waitUntilRead(),
        stows.supabaseRefreshToken.waitUntilRead(),
      ]);

      final accessToken = stows.supabaseAccessToken.value;
      final refreshToken = stows.supabaseRefreshToken.value;

      if (accessToken.isEmpty || refreshToken.isEmpty) {
        log.info('No stored session to restore');
        return false;
      }

      log.info('Attempting to restore session');

      // Supabase Flutter SDK automatically handles session restoration
      // We just need to check if the current session is valid
      final session = currentSession;

      if (session != null && !session.isExpired) {
        log.info('Session restored successfully');
        return true;
      }

      // Try to refresh if expired
      if (session != null && session.isExpired) {
        log.info('Session expired, attempting refresh');
        final response = await refreshSession();
        return response.session != null;
      }

      log.info('No valid session found');
      return false;
    } catch (e) {
      log.severe('Failed to restore session', e);
      await _clearSessionFromPrefs();
      return false;
    }
  }

  /// Check if user is currently authenticated
  static bool get isAuthenticated {
    final session = currentSession;
    return session != null && !session.isExpired;
  }
}
