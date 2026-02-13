import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saber/data/models/dashboard_models.dart';

/// Lightweight JSON file cache for dashboard data.
///
/// Stores queue, stats, and appointments so the dashboard is never blank
/// when the device has no internet connectivity.
class OfflineDashboardCache {
  static final _log = Logger('OfflineDashboardCache');

  static Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/cache');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    return File('${cacheDir.path}/dashboard_cache.json');
  }

  static Future<Map<String, dynamic>> _readCache() async {
    try {
      final file = await _cacheFile();
      if (!file.existsSync()) return {};
      final content = await file.readAsString();
      if (content.isEmpty) return {};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      _log.warning('Error reading cache: $e');
      return {};
    }
  }

  static Future<void> _writeCache(Map<String, dynamic> data) async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      _log.warning('Error writing cache: $e');
    }
  }

  // ── Queue ──────────────────────────────────────────────────────────

  static Map<String, dynamic> _queueItemToJson(QueueItem item) {
    return {
      'id': item.id,
      'patientName': item.patientName,
      'patientId': item.patientId,
      'position': item.position,
      'estimatedWaitMinutes': item.estimatedWaitTime.inMinutes,
      'status': item.status,
      'age': item.age,
      'gender': item.gender,
      'registeredTime': item.registeredTime.toIso8601String(),
      'patientType': item.patientType,
      'registrationNumber': item.registrationNumber,
      'avatarUrl': item.avatarUrl,
    };
  }

  static QueueItem _queueItemFromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['id'] as String? ?? '',
      patientName: json['patientName'] as String? ?? 'Unknown',
      patientId: json['patientId'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      estimatedWaitTime: Duration(
        minutes: json['estimatedWaitMinutes'] as int? ?? 0,
      ),
      status: json['status'] as String? ?? 'Waiting',
      age: json['age'] as int? ?? 0,
      gender: json['gender'] as String? ?? 'Unknown',
      registeredTime: json['registeredTime'] != null
          ? DateTime.parse(json['registeredTime'] as String)
          : DateTime.now(),
      patientType: json['patientType'] as String? ?? 'New Patient',
      registrationNumber: json['registrationNumber'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  static Future<void> saveQueue(List<QueueItem> items) async {
    final cache = await _readCache();
    cache['queue'] = items.map(_queueItemToJson).toList();
    cache['queueCachedAt'] = DateTime.now().toIso8601String();
    await _writeCache(cache);
    _log.info('Cached ${items.length} queue items');
  }

  static Future<List<QueueItem>?> loadQueue() async {
    final cache = await _readCache();
    final list = cache['queue'] as List?;
    if (list == null || list.isEmpty) return null;
    try {
      return list
          .map((e) => _queueItemFromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.warning('Error deserializing cached queue: $e');
      return null;
    }
  }

  // ── Stats ──────────────────────────────────────────────────────────

  static Future<void> saveStats(DashboardStats stats) async {
    final cache = await _readCache();
    cache['stats'] = {
      'consultationsToday': stats.consultationsToday,
      'pendingConsultations': stats.pendingConsultations,
      'completedSessions': stats.completedSessions,
      'totalConsultationMinutes': stats.totalConsultationMinutes,
      'consultationsTrend': stats.consultationsTrend,
      'timeTrend': stats.timeTrend,
    };
    cache['statsCachedAt'] = DateTime.now().toIso8601String();
    await _writeCache(cache);
    _log.info('Cached dashboard stats');
  }

  static Future<DashboardStats?> loadStats() async {
    final cache = await _readCache();
    final data = cache['stats'] as Map<String, dynamic>?;
    if (data == null) return null;
    try {
      return DashboardStats(
        consultationsToday: data['consultationsToday'] as int? ?? 0,
        pendingConsultations: data['pendingConsultations'] as int? ?? 0,
        completedSessions: data['completedSessions'] as int? ?? 0,
        totalConsultationMinutes: data['totalConsultationMinutes'] as int? ?? 0,
        consultationsTrend:
            (data['consultationsTrend'] as num?)?.toDouble() ?? 0.0,
        timeTrend: (data['timeTrend'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      _log.warning('Error deserializing cached stats: $e');
      return null;
    }
  }

  // ── Appointments ───────────────────────────────────────────────────

  static Map<String, dynamic> _appointmentToJson(Appointment appt) {
    return {
      'id': appt.id,
      'patientName': appt.patientName,
      'patientId': appt.patientId,
      'time': appt.time.toIso8601String(),
      'reason': appt.reason,
      'status': appt.status.index,
      'avatarUrl': appt.avatarUrl,
      'appointmentType': appt.appointmentType,
      'gender': appt.gender,
      'age': appt.age,
      'registrationNumber': appt.registrationNumber,
      'sessionNumber': appt.sessionNumber,
    };
  }

  static Appointment _appointmentFromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String? ?? '',
      patientName: json['patientName'] as String? ?? 'Unknown',
      patientId: json['patientId'] as String? ?? '',
      time: json['time'] != null
          ? DateTime.parse(json['time'] as String)
          : DateTime.now(),
      reason: json['reason'] as String? ?? '',
      status: AppointmentStatus.values[(json['status'] as int?) ?? 0],
      avatarUrl: json['avatarUrl'] as String?,
      appointmentType: json['appointmentType'] as String? ?? 'walk-in',
      gender: json['gender'] as String?,
      age: json['age'] as int?,
      registrationNumber: json['registrationNumber'] as String?,
      sessionNumber: json['sessionNumber'] as int?,
    );
  }

  static Future<void> saveAppointments(List<Appointment> items) async {
    final cache = await _readCache();
    cache['appointments'] = items.map(_appointmentToJson).toList();
    cache['appointmentsCachedAt'] = DateTime.now().toIso8601String();
    await _writeCache(cache);
    _log.info('Cached ${items.length} appointments');
  }

  static Future<List<Appointment>?> loadAppointments() async {
    final cache = await _readCache();
    final list = cache['appointments'] as List?;
    if (list == null || list.isEmpty) return null;
    try {
      return list
          .map((e) => _appointmentFromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.warning('Error deserializing cached appointments: $e');
      return null;
    }
  }

  // ── Metadata ───────────────────────────────────────────────────────

  static Future<DateTime?> lastCacheTime() async {
    final cache = await _readCache();
    final ts = cache['queueCachedAt'] as String?;
    if (ts == null) return null;
    try {
      return DateTime.parse(ts);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final file = await _cacheFile();
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      _log.warning('Error clearing cache: $e');
    }
  }
}
