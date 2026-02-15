import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saber/data/models/patient.dart';

/// Lightweight JSON file cache for patient data.
///
/// Stores the full list of patients so they are available offline.
class OfflinePatientCache {
  static final _log = Logger('OfflinePatientCache');

  static Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/cache');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    return File('${cacheDir.path}/patient_cache.json');
  }

  static Future<Map<String, dynamic>> _readCache() async {
    try {
      final file = await _cacheFile();
      if (!file.existsSync()) return {};
      final content = await file.readAsString();
      if (content.isEmpty) return {};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      _log.warning('Error reading patient cache: $e');
      return {};
    }
  }

  static Future<void> _writeCache(Map<String, dynamic> data) async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      _log.warning('Error writing patient cache: $e');
    }
  }

  static Map<String, dynamic> _patientToJson(Patient patient) {
    return patient.toJson();
  }

  static Patient _patientFromJson(Map<String, dynamic> json) {
    return Patient.fromJson(json);
  }

  /// Save full list of patients to cache
  static Future<void> savePatients(List<Patient> patients) async {
    final cache = await _readCache();
    cache['patients'] = patients.map(_patientToJson).toList();
    cache['cachedAt'] = DateTime.now().toIso8601String();
    await _writeCache(cache);
    _log.info('Cached ${patients.length} patients');
  }

  /// Load full list of patients from cache
  static Future<List<Patient>> loadPatients() async {
    final cache = await _readCache();
    final list = cache['patients'] as List?;
    if (list == null) return [];

    try {
      return list
          .map((e) => _patientFromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.warning('Error deserializing cached patients: $e');
      return [];
    }
  }

  /// Update or add a single patient in the cache without full re-fetch
  static Future<void> updatePatient(Patient patient) async {
    final patients = await loadPatients();
    final index = patients.indexWhere((p) => p.id == patient.id);

    if (index != -1) {
      patients[index] = patient;
    } else {
      patients.insert(0, patient); // Add to top if new
    }

    await savePatients(patients);
    _log.info('Updated patient ${patient.id} in cache');
  }

  /// Remove a patient from cache
  static Future<void> removePatient(String patientId) async {
    final patients = await loadPatients();
    patients.removeWhere((p) => p.id == patientId);
    await savePatients(patients);
    _log.info('Removed patient $patientId from cache');
  }

  /// Get last cache time
  static Future<DateTime?> lastCacheTime() async {
    final cache = await _readCache();
    final ts = cache['cachedAt'] as String?;
    if (ts == null) return null;
    try {
      return DateTime.parse(ts);
    } catch (_) {
      return null;
    }
  }

  /// Clear cache
  static Future<void> clear() async {
    try {
      final file = await _cacheFile();
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      _log.warning('Error clearing patient cache: $e');
    }
  }
}
