import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/api/report_generator.dart';
import 'package:saber/data/models/patient.dart';

enum ReportGenerationStatus { idle, capturing, processing, completed, error }

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

  String _currentMessage = 'Synapse AI is thinking...';
  String get currentMessage => _currentMessage;

  void startGeneration({
    required List<Uint8List> imageBytesList,
    required Patient? patient,
    required String? filePath,
    String? rawNotes,
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
      _errorMessage = e.toString();
      _status = ReportGenerationStatus.error;
      _currentMessage = 'Generation failed';
      _log.severe('Async report generation failed: $e');
      notifyListeners();
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
    _currentMessage = 'Synapse AI is thinking...';
    notifyListeners();
  }
}
