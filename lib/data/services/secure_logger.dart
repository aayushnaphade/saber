import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// A secure logging wrapper that strips sensitive data in release builds.
///
/// Usage:
///   final log = SecureLogger('MyService');
///   log.debug('Processing item', {'itemId': id});
///   log.info('Operation complete');
///
/// In debug mode: prints detailed logs with metadata.
/// In release mode: only WARNING+ level logs are emitted, and no
/// sensitive parameters are included.
class SecureLogger {
  final Logger _logger;

  SecureLogger(String name) : _logger = Logger(name);

  /// Debug-only log. Completely stripped in release builds.
  void debug(String message, [Map<String, dynamic>? metadata]) {
    if (kDebugMode) {
      _logger.fine('$message${metadata != null ? ' | $metadata' : ''}');
    }
  }

  /// Informational log. Stripped in release builds.
  void info(String message) {
    if (kDebugMode) {
      _logger.info(message);
    }
  }

  /// Warning log. Available in all builds but never includes sensitive data.
  void warn(String message) {
    _logger.warning(message);
  }

  /// Error log. Available in all builds. Never includes raw user data.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }

  /// Sanitizes a value for logging — redacts anything that looks like a UUID,
  /// email, or token.
  static String sanitize(String value) {
    if (kReleaseMode) {
      // Redact UUIDs
      value = value.replaceAll(
        RegExp(
          r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
          caseSensitive: false,
        ),
        '[REDACTED-UUID]',
      );
      // Redact email patterns
      value = value.replaceAll(
        RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'),
        '[REDACTED-EMAIL]',
      );
      // Redact JWT-like tokens
      value = value.replaceAll(
        RegExp(r'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
        '[REDACTED-TOKEN]',
      );
    }
    return value;
  }
}
