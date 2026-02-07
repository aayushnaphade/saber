import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class ErrorHandler {
  /// Returns a user-friendly error message for the given error.
  /// If the error is network-related, it returns a graceful "No internet connection" message.
  static String getFriendlyErrorMessage(dynamic error) {
    if (error is SocketException ||
        error is HttpException ||
        error is HandshakeException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return 'No internet connection. Please check your connection and try again.';
    }

    final errorString = error.toString().toLowerCase();

    // Check for network-related error strings (including within AuthException)
    if (errorString.contains('socketexception') ||
        errorString.contains('connection timed out') ||
        errorString.contains('connection failed') ||
        errorString.contains('timedout') ||
        errorString.contains('timed out') ||
        errorString.contains('connection refused') ||
        errorString.contains('network') ||
        errorString.contains('clientexception') ||
        errorString.contains('fetch error') ||
        errorString.contains('failed to fetch')) {
      return 'No internet connection. Please check your connection and try again.';
    }

    // Check for Google API / OAuth specific errors
    if (errorString.contains('429') ||
        errorString.contains('resource exhausted') ||
        errorString.contains('quota exceeded') ||
        errorString.contains('rate limit')) {
      return 'AI service is currently busy or quota reached. Please wait a minute and try again.';
    }

    if (errorString.contains('googleapis.com') ||
        errorString.contains('oauth2') ||
        errorString.contains('vertex ai')) {
      return 'Unable to connect to Google AI services. Please check your internet connection or network firewall settings.';
    }

    // Generic AuthException cleanup
    if (errorString.contains('invalid login credentials')) {
      return 'Invalid email or password. Please try again.';
    }

    // If it's an AuthException, just return the message part instead of the whole toString()
    if (errorString.startsWith('authexception:')) {
      return error.toString().substring('AuthException:'.length).trim();
    }

    return error.toString();
  }
}
