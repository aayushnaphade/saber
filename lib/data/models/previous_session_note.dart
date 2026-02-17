import 'package:logging/logging.dart';

/// Model for previous session note screenshots and metadata
class PreviousSessionNote {
  static final _log = Logger('PreviousSessionNote');
  final List<String> pageUrls;
  final int sessionNumber;
  final DateTime createdAt;
  final String fileName;
  final int pageCount;

  PreviousSessionNote({
    required this.pageUrls,
    required this.sessionNumber,
    required this.createdAt,
    required this.fileName,
    this.pageCount = 1,
  }) {
    // Defensive check even in null-safe Dart to catch runtime misbehavior/casting issues
    // ignore: unnecessary_null_comparison
    if (pageUrls == null) {
      _log.severe('CRITICAL: pageUrls is NULL for session $sessionNumber');
    } else if (pageUrls.isEmpty) {
      _log.warning(
        'Note created with empty pageUrls for session $sessionNumber',
      );
    } else {
      _log.info(
        'PreviousSessionNote created for session $sessionNumber with ${pageUrls.length} pages',
      );
    }
  }

  String? get imageUrl {
    try {
      // ignore: unnecessary_null_comparison
      if (pageUrls == null) return null;
      return pageUrls.isNotEmpty ? pageUrls.first : null;
    } catch (e) {
      _log.severe('Error in imageUrl getter: $e');
      return null;
    }
  }

  @override
  String toString() =>
      'PreviousSessionNote(session: $sessionNumber, date: $createdAt, pages: ${pageUrls.length})';
}
