import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/editor/editor_core_info.dart';

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

  void terminate() {
    _activeSession = null;
    _patientName = null;
    _patientId = null;
    _consultationId = null;
    _isMinimized = false;
    notifyListeners();
  }
}
