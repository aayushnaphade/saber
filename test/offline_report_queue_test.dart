import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:saber/data/services/offline_report_queue.dart';

/// Fake path_provider for isolated tests
class FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  late final Directory tempDir;

  FakePathProvider() {
    tempDir = Directory.systemTemp.createTempSync('report_queue_test_');
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
    if (fakePathProvider.tempDir.existsSync()) {
      fakePathProvider.tempDir.deleteSync(recursive: true);
    }
  });

  group('OfflineReportQueue', () {
    test('saveForLater stores images and returns an ID', () async {
      final images = [
        Uint8List.fromList([1, 2, 3, 4, 5]),
        Uint8List.fromList([6, 7, 8, 9, 10]),
      ];

      final id = await OfflineReportQueue.saveForLater(
        imageBytesList: images,
        patientId: 'patient1',
        consultationId: 'consult1',
        sourceFilePath: 'test/path',
        registrationNumber: 'REG001',
        patientName: 'John Doe',
      );

      expect(id, isNotEmpty);

      // Verify images were persisted
      final reportDir = Directory(
        '${fakePathProvider.tempDir.path}/pending_reports/$id',
      );
      expect(reportDir.existsSync(), isTrue);
      expect(File('${reportDir.path}/page_0.png').existsSync(), isTrue);
      expect(File('${reportDir.path}/page_1.png').existsSync(), isTrue);
      expect(File('${reportDir.path}/meta.json').existsSync(), isTrue);
    });

    test('getPending returns queued items', () async {
      await OfflineReportQueue.saveForLater(
        imageBytesList: [
          Uint8List.fromList([1, 2, 3]),
        ],
        patientId: 'p1',
        consultationId: 'c1',
        sourceFilePath: 'test/path',
        patientName: 'Alice',
      );
      await OfflineReportQueue.saveForLater(
        imageBytesList: [
          Uint8List.fromList([4, 5, 6]),
        ],
        patientId: 'p2',
        consultationId: 'c2',
        sourceFilePath: 'test/path',
        patientName: 'Bob',
      );

      final pending = await OfflineReportQueue.getPending();
      expect(pending.length, 2);
      expect(pending[0].patientName, 'Alice');
      expect(pending[0].status, 'queued');
      expect(pending[1].patientName, 'Bob');
    });

    test('loadImages retrieves saved images correctly', () async {
      final images = [
        Uint8List.fromList([10, 20, 30]),
        Uint8List.fromList([40, 50, 60, 70]),
      ];

      final id = await OfflineReportQueue.saveForLater(
        imageBytesList: images,
        patientId: 'p1',
        consultationId: 'c1',
        sourceFilePath: 'test/path',
      );

      final loaded = await OfflineReportQueue.loadImages(id);
      expect(loaded.length, 2);
      expect(loaded[0], images[0]);
      expect(loaded[1], images[1]);
    });

    test('updateStatus changes report status in manifest', () async {
      final id = await OfflineReportQueue.saveForLater(
        imageBytesList: [
          Uint8List.fromList([1]),
        ],
        patientId: 'p1',
        consultationId: 'c1',
        sourceFilePath: 'test/path',
      );

      await OfflineReportQueue.updateStatus(id, 'retrying');
      var pending = await OfflineReportQueue.getPending();
      expect(pending[0].status, 'retrying');
      expect(pending[0].retryCount, 1);

      await OfflineReportQueue.updateStatus(id, 'failed', error: 'timeout');
      pending = await OfflineReportQueue.getPending();
      expect(pending[0].status, 'failed');
      expect(pending[0].lastError, 'timeout');
    });

    test('remove deletes report files and manifest entry', () async {
      final id = await OfflineReportQueue.saveForLater(
        imageBytesList: [
          Uint8List.fromList([1, 2, 3]),
        ],
        patientId: 'p1',
        consultationId: 'c1',
        sourceFilePath: 'test/path',
      );

      expect(await OfflineReportQueue.pendingCount(), 1);

      await OfflineReportQueue.remove(id);

      expect(await OfflineReportQueue.pendingCount(), 0);

      // Verify files are deleted
      final reportDir = Directory(
        '${fakePathProvider.tempDir.path}/pending_reports/$id',
      );
      expect(reportDir.existsSync(), isFalse);
    });

    test('pendingCount excludes completed items', () async {
      final id1 = await OfflineReportQueue.saveForLater(
        imageBytesList: [
          Uint8List.fromList([1]),
        ],
        patientId: 'p1',
        consultationId: 'c1',
        sourceFilePath: 'test/path',
      );
      await OfflineReportQueue.saveForLater(
        imageBytesList: [
          Uint8List.fromList([2]),
        ],
        patientId: 'p2',
        consultationId: 'c2',
        sourceFilePath: 'test/path',
      );

      expect(await OfflineReportQueue.pendingCount(), 2);

      await OfflineReportQueue.updateStatus(id1, 'completed');
      expect(await OfflineReportQueue.pendingCount(), 1);
    });

    test('clear removes all reports', () async {
      await OfflineReportQueue.saveForLater(
        imageBytesList: [
          Uint8List.fromList([1]),
        ],
        patientId: 'p1',
        consultationId: 'c1',
        sourceFilePath: 'test/path',
      );
      await OfflineReportQueue.saveForLater(
        imageBytesList: [
          Uint8List.fromList([2]),
        ],
        patientId: 'p2',
        consultationId: 'c2',
        sourceFilePath: 'test/path',
      );

      await OfflineReportQueue.clear();

      final pending = await OfflineReportQueue.getPending();
      expect(pending, isEmpty);
    });

    test('PendingReport.timeAgo formats correctly', () {
      final justNow = PendingReport(
        id: '1',
        patientId: 'p1',
        consultationId: 'c1',
        sourceFilePath: 'test/path',
        imageCount: 1,
        createdAt: DateTime.now(),
        status: 'queued',
      );
      expect(justNow.timeAgo, 'just now');

      final fiveMinAgo = PendingReport(
        id: '2',
        patientId: 'p1',
        consultationId: 'c1',
        sourceFilePath: 'test/path',
        imageCount: 1,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        status: 'queued',
      );
      expect(fiveMinAgo.timeAgo, '5 min ago');

      final twoHoursAgo = PendingReport(
        id: '3',
        patientId: 'p1',
        consultationId: 'c1',
        sourceFilePath: 'test/path',
        imageCount: 1,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        status: 'queued',
      );
      expect(twoHoursAgo.timeAgo, '2h ago');

      final threeDaysAgo = PendingReport(
        id: '4',
        patientId: 'p1',
        consultationId: 'c1',
        sourceFilePath: 'test/path',
        imageCount: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        status: 'queued',
      );
      expect(threeDaysAgo.timeAgo, '3d ago');
    });

    test('PendingReport.statusDisplay maps correctly', () {
      expect(
        PendingReport(
          id: '1',
          patientId: 'p',
          consultationId: 'c',
          sourceFilePath: null,
          imageCount: 1,
          createdAt: DateTime.now(),
          status: 'queued',
        ).statusDisplay,
        'Queued',
      );
      expect(
        PendingReport(
          id: '1',
          patientId: 'p',
          consultationId: 'c',
          sourceFilePath: null,
          imageCount: 1,
          createdAt: DateTime.now(),
          status: 'retrying',
        ).statusDisplay,
        'Retrying...',
      );
      expect(
        PendingReport(
          id: '1',
          patientId: 'p',
          consultationId: 'c',
          imageCount: 1,
          createdAt: DateTime.now(),
          status: 'failed',
        ).statusDisplay,
        'Failed',
      );
    });
  });
}
