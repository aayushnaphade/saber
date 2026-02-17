import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/services/offline_dashboard_cache.dart';

/// Fake path_provider that returns a temp directory
class FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  late final Directory tempDir;

  FakePathProvider() {
    tempDir = Directory.systemTemp.createTempSync('offline_cache_test_');
  }

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;
}

void main() {
  late FakePathProvider fakePathProvider;

  setUp(() {
    fakePathProvider = FakePathProvider();
    PathProviderPlatform.instance = fakePathProvider;
  });

  tearDown(() {
    // Clean up temp files
    if (fakePathProvider.tempDir.existsSync()) {
      fakePathProvider.tempDir.deleteSync(recursive: true);
    }
  });

  group('OfflineDashboardCache', () {
    test('saveQueue and loadQueue round-trip correctly', () async {
      final items = [
        QueueItem(
          id: '1',
          patientName: 'John Doe',
          patientId: 'p1',
          registrationNumber: 'REG001',
          age: 45,
          patientType: 'Follow-up',
          estimatedWaitTime: const Duration(minutes: 15),
          position: 1,
          status: 'waiting',
          gender: 'Male',
          registeredTime: DateTime(2026, 2, 13, 8, 45),
        ),
        QueueItem(
          id: '2',
          patientName: 'Jane Smith',
          patientId: 'p2',
          registrationNumber: 'REG002',
          age: 32,
          patientType: 'New Visit',
          estimatedWaitTime: const Duration(minutes: 30),
          position: 2,
          status: 'waiting',
          gender: 'Female',
          registeredTime: DateTime(2026, 2, 13, 9, 0),
        ),
      ];

      await OfflineDashboardCache.saveQueue(items);
      final loaded = await OfflineDashboardCache.loadQueue();

      expect(loaded, isNotNull);
      expect(loaded!.length, 2);
      expect(loaded[0].id, '1');
      expect(loaded[0].patientName, 'John Doe');
      expect(loaded[0].registrationNumber, 'REG001');
      expect(loaded[0].age, 45);
      expect(loaded[1].id, '2');
      expect(loaded[1].patientName, 'Jane Smith');
    });

    test('loadQueue returns null when no cache exists', () async {
      final loaded = await OfflineDashboardCache.loadQueue();
      expect(loaded, isNull);
    });

    test('saveStats and loadStats round-trip correctly', () async {
      const stats = DashboardStats(
        consultationsToday: 5,
        pendingConsultations: 3,
        completedSessions: 12,
        totalConsultationMinutes: 180,
        consultationsTrend: 2.0,
        timeTrend: -0.5,
      );

      await OfflineDashboardCache.saveStats(stats);
      final loaded = await OfflineDashboardCache.loadStats();

      expect(loaded, isNotNull);
      expect(loaded!.consultationsToday, 5);
      expect(loaded.pendingConsultations, 3);
      expect(loaded.completedSessions, 12);
      expect(loaded.totalConsultationMinutes, 180);
    });

    test(
      'saveAppointments and loadAppointments round-trip correctly',
      () async {
        final appointments = [
          Appointment(
            id: 'apt1',
            patientName: 'Alice',
            patientId: 'p3',
            time: DateTime(2026, 2, 13, 10, 0),
            reason: 'Checkup',
            appointmentType: 'scheduled',
            status: AppointmentStatus.upcoming,
          ),
        ];

        await OfflineDashboardCache.saveAppointments(appointments);
        final loaded = await OfflineDashboardCache.loadAppointments();

        expect(loaded, isNotNull);
        expect(loaded!.length, 1);
        expect(loaded[0].id, 'apt1');
        expect(loaded[0].patientName, 'Alice');
      },
    );

    test('lastCacheTime returns timestamp after save', () async {
      final items = [
        QueueItem(
          id: '1',
          patientName: 'Test',
          patientId: 'p4',
          registrationNumber: 'T001',
          age: 30,
          patientType: 'Test',
          estimatedWaitTime: Duration.zero,
          position: 1,
          status: 'waiting',
          gender: 'Other',
          registeredTime: DateTime.now(),
        ),
      ];

      final before = DateTime.now();
      await OfflineDashboardCache.saveQueue(items);
      final cacheTime = await OfflineDashboardCache.lastCacheTime();

      expect(cacheTime, isNotNull);
      expect(
        cacheTime!.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('clear removes all cached data', () async {
      await OfflineDashboardCache.saveQueue([
        QueueItem(
          id: '1',
          patientName: 'Test',
          patientId: 'p5',
          registrationNumber: 'T001',
          age: 30,
          patientType: 'Test',
          estimatedWaitTime: Duration.zero,
          position: 1,
          status: 'waiting',
          gender: 'Other',
          registeredTime: DateTime.now(),
        ),
      ]);

      await OfflineDashboardCache.clear();

      final loaded = await OfflineDashboardCache.loadQueue();
      expect(loaded, isNull);
    });

    test('handles corrupted cache file gracefully', () async {
      // Write invalid JSON to cache file
      final dir = fakePathProvider.tempDir;
      final cacheDir = Directory('${dir.path}/cache');
      cacheDir.createSync(recursive: true);
      final cacheFile = File('${cacheDir.path}/dashboard_cache.json');
      await cacheFile.writeAsString('not valid json {{{');

      // Should return null instead of crashing
      final loaded = await OfflineDashboardCache.loadQueue();
      expect(loaded, isNull);
    });

    test('handles empty cache file gracefully', () async {
      final dir = fakePathProvider.tempDir;
      final cacheDir = Directory('${dir.path}/cache');
      cacheDir.createSync(recursive: true);
      final cacheFile = File('${cacheDir.path}/dashboard_cache.json');
      await cacheFile.writeAsString('');

      final loaded = await OfflineDashboardCache.loadQueue();
      expect(loaded, isNull);
    });
  });
}
