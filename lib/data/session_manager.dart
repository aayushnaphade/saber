import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';

class SessionManager extends ChangeNotifier {
  static final _log = Logger('SessionManager');
  static final _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  EditorCoreInfo? _activeSession;
  String? _patientName;
  String? _patientId;
  String? _consultationId;
  var _isMinimized = false;

  EditorCoreInfo? get activeSession => _activeSession;
  String? get patientName => _patientName;
  String? get patientId => _patientId;
  String? get consultationId => _consultationId;
  bool get isMinimized => _isMinimized;
  bool get hasActiveSession => _activeSession != null;

  void startSession({
    required EditorCoreInfo coreInfo,
    required String? patientName,
    required String? patientId,
    required String? consultationId,
  }) {
    _log.info('Starting session for patient: $patientName (ID: $patientId)');
    _activeSession = coreInfo;
    _patientName = patientName;
    _patientId = patientId;
    _consultationId = consultationId;
    _isMinimized = false;
    notifyListeners();
  }

  void minimize() {
    if (hasActiveSession) {
      _log.info('Minimizing session for: $_patientName');
      _isMinimized = true;
      notifyListeners();
    } else {
      _log.warning('Attempted to minimize with no active session');
    }
  }

  void restore() {
    if (hasActiveSession) {
      _isMinimized = false;
      notifyListeners();
    }
  }

  Future<void> deleteActiveSessionFiles() async {
    final session = _activeSession;
    if (session == null) return;

    try {
      final path = session.filePath;
      final parentDir = p.dirname(path);
      final parentDirName = p.basename(parentDir);

      if (parentDirName.startsWith('session_')) {
        _log.info('Deleting session directory: $parentDir');
        await FileManager.deleteDirectory(parentDir);
      } else {
        _log.info('Deleting session file: $path');
        await FileManager.deleteFile(path);
      }
    } catch (e) {
      _log.severe('Failed to delete active session files: $e');
    }
  }

  void terminate() {
    _activeSession = null;
    _patientName = null;
    _patientId = null;
    _consultationId = null;
    _isMinimized = false;
    notifyListeners();
  }
}
