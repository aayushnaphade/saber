import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/api/report_generator.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/services/offline_report_queue.dart';

enum ReportGenerationStatus {
  idle,
  capturing,
  processing,
  completed,
  error,
  queued,
}

class ReportGenerationManager extends ChangeNotifier {
  static final _log = Logger('ReportGenerationManager');
  static final _instance = ReportGenerationManager._internal();
  factory ReportGenerationManager() => _instance;
  ReportGenerationManager._internal();

  ReportGenerationStatus _status = ReportGenerationStatus.idle;
  ReportGenerationStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Map<String, dynamic>? _reportData;
  Map<String, dynamic>? get reportData => _reportData;

  List<Uint8List> _imageBytesList = [];
  List<Uint8List> get imageBytesList => _imageBytesList;

  Patient? _patient;
  Patient? get patient => _patient;

  String? _filePath;
  String? get filePath => _filePath;

  String? _rawNotes;
  String? get rawNotes => _rawNotes;

  String? _queuedReportId;
  String? get queuedReportId => _queuedReportId;

  String? _consultationId;
  String? get consultationId => _consultationId;

  var _currentMessage = 'Synapse AI is thinking...';
  String get currentMessage => _currentMessage;

  void startGeneration({
    required List<Uint8List> imageBytesList,
    required Patient? patient,
    required String? filePath,
    String? rawNotes,
    String? consultationId,
  }) async {
    if (_status == ReportGenerationStatus.processing ||
        _status == ReportGenerationStatus.capturing) {
      _log.warning('Report generation already in progress');
      return;
    }

    _log.info(
      'Starting async report generation for patient: ${patient?.fullName}',
    );
    _imageBytesList = imageBytesList;
    _patient = patient;
    _filePath = filePath;
    _rawNotes = rawNotes;
    _status = ReportGenerationStatus.processing;
    _errorMessage = null;
    _reportData = null;
    _queuedReportId = null;
    _consultationId = consultationId;
    _currentMessage = 'Synapse AI is thinking...';
    notifyListeners();

    try {
      final data = await ReportGenerator.generateReport(
        _imageBytesList,
        registrationNumber: _patient?.registrationNumber,
      );

      _reportData = data;
      _status = ReportGenerationStatus.completed;
      _currentMessage = 'Report generated successfully!';
      _log.info('Async report generation completed successfully');
      notifyListeners();
    } catch (e) {
      if (_isNetworkError(e)) {
        // Queue for later generation instead of showing an error
        _log.warning('Network error during report generation, queuing...');
        try {
          final reportId = await OfflineReportQueue.saveForLater(
            imageBytesList: _imageBytesList,
            patientId: _patient?.id ?? '',
            consultationId: consultationId ?? '',
            sourceFilePath: _filePath,
            registrationNumber: _patient?.registrationNumber,
            patientName: _patient?.fullName,
          );
          _queuedReportId = reportId;
          _status = ReportGenerationStatus.queued;
          _currentMessage =
              'Report queued — will generate when internet is stable';
          _log.info('Report queued with ID: $reportId');
          notifyListeners();
        } catch (queueError) {
          _errorMessage = 'Failed to queue report: $queueError';
          _status = ReportGenerationStatus.error;
          _currentMessage = 'Generation failed';
          _log.severe('Failed to queue report: $queueError');
          notifyListeners();
        }
      } else {
        _errorMessage = e.toString();
        _status = ReportGenerationStatus.error;
        _currentMessage = 'Generation failed';
        _log.severe('Async report generation failed: $e');
        notifyListeners();
      }
    }
  }

  void updateMessage(String message) {
    _currentMessage = message;
    notifyListeners();
  }

  void reset() {
    _status = ReportGenerationStatus.idle;
    _reportData = null;
    _errorMessage = null;
    _imageBytesList = [];
    _patient = null;
    _filePath = null;
    _rawNotes = null;
    _queuedReportId = null;
    _consultationId = null;
    _currentMessage = 'Synapse AI is thinking...';
    notifyListeners();
  }

  static bool _isNetworkError(Object e) {
    final msg = e.toString();
    return e is SocketException ||
        msg.contains('SocketException') ||
        msg.contains('Connection timed out') ||
        msg.contains('connection abort') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Network is unreachable') ||
        msg.contains('Network error') ||
        msg.contains('TimeoutException') ||
        msg.contains('ClientException') ||
        msg.contains('HandshakeException') ||
        msg.contains('HttpException') ||
        msg.contains('CERTIFICATE_VERIFY_FAILED') ||
        msg.contains('Connection refused') ||
        msg.contains('Connection reset');
  }
}
