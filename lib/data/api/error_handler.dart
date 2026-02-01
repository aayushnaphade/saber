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
      return 'No internet connection. Please check your connection.';
    }

    final errorString = error.toString().toLowerCase();
    if (errorString.contains('socketexception') ||
        errorString.contains('connection timed out') ||
        errorString.contains('connection failed') ||
        errorString.contains('timed out')) {
      return 'No internet connection. Please check your connection.';
    }

    return error.toString();
  }
}
