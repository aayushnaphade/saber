import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Repository for handling session-related data operations,
/// particularly thumbnail management and path resolution.
class SessionDataRepository {
  static final _log = Logger('SessionDataRepository');

  /// Resolves the most appropriate thumbnail for a given session path.
  /// Implements a "fallback ladder" to ensure a preview is shown:
  /// 1. Page-specific thumbnail (e.g., page_0_thumb.jpg)
  /// 2. Legacy composite thumbnail (thumbnail.jpg)
  /// 3. Placeholder or null if no thumbnail exists
  static Future<String?> getThumbnailPath(
    String sessionPath, {
    int pageIndex = 0,
  }) async {
    final sessionDir = p.dirname(sessionPath);

    // 1. Try page-specific thumbnail
    final pageThumbPath = p.join(sessionDir, 'page_${pageIndex}_thumb.jpg');
    if (await File(pageThumbPath).exists()) {
      return pageThumbPath;
    }

    // 2. Fallback to legacy composite thumbnail for page 0
    if (pageIndex == 0) {
      final legacyThumbPath = p.join(sessionDir, 'thumbnail.jpg');
      if (await File(legacyThumbPath).exists()) {
        return legacyThumbPath;
      }
    }

    _log.fine('No thumbnail found for $sessionPath at index $pageIndex');
    return null;
  }

  /// Lists all available thumbnails for a session.
  static Future<List<String>> getAllThumbnails(String sessionPath) async {
    final sessionDir = p.dirname(sessionPath);
    final List<String> thumbnails = [];

    try {
      final dir = Directory(sessionDir);
      if (await dir.exists()) {
        final files = await dir.list().toList();

        // Find all page_X_thumb.jpg files
        final pageThumbs = files
            .where((f) => f.path.contains(RegExp(r'page_\d+_thumb\.jpg')))
            .map((f) => f.path)
            .toList();

        // Sort numerically
        pageThumbs.sort((a, b) {
          final aNum =
              int.tryParse(
                RegExp(r'page_(\d+)_thumb').firstMatch(a)?.group(1) ?? '0',
              ) ??
              0;
          final bNum =
              int.tryParse(
                RegExp(r'page_(\d+)_thumb').firstMatch(b)?.group(1) ?? '0',
              ) ??
              0;
          return aNum.compareTo(bNum);
        });

        thumbnails.addAll(pageThumbs);

        // If no page thumbs but legacy thumb exists, add it as first entry
        if (thumbnails.isEmpty) {
          final legacyThumb = p.join(sessionDir, 'thumbnail.jpg');
          if (await File(legacyThumb).exists()) {
            thumbnails.add(legacyThumb);
          }
        }
      }
    } catch (e) {
      _log.severe('Error listing thumbnails for $sessionPath', e);
    }

    return thumbnails;
  }
}
