import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:saber/data/services/sync_outbox.dart';

/// Fake path_provider for isolated tests
class FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  late final Directory tempDir;

  FakePathProvider() {
    tempDir = Directory.systemTemp.createTempSync('sync_outbox_test_');
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

  group('SyncOutbox', () {
    test('enqueue creates a persistent entry', () async {
      await SyncOutbox.enqueue(
        operation: 'completeConsultation',
        payload: {'consultationId': 'c123', 'status': 'completed'},
      );

      final pending = await SyncOutbox.getPendingEntries();
      expect(pending.length, 1);
      expect(pending[0]['operation'], 'completeConsultation');
      expect(pending[0]['payload']['consultationId'], 'c123');
      expect(pending[0]['status'], 'pending');
    });

    test('multiple enqueue operations are ordered FIFO', () async {
      await SyncOutbox.enqueue(operation: 'op1', payload: {'key': 'first'});
      await SyncOutbox.enqueue(operation: 'op2', payload: {'key': 'second'});
      await SyncOutbox.enqueue(operation: 'op3', payload: {'key': 'third'});

      final pending = await SyncOutbox.getPendingEntries();
      expect(pending.length, 3);
      expect(pending[0]['operation'], 'op1');
      expect(pending[1]['operation'], 'op2');
      expect(pending[2]['operation'], 'op3');
    });

    test('markCompleted removes entry from pending', () async {
      await SyncOutbox.enqueue(
        operation: 'completeConsultation',
        payload: {'consultationId': 'c123'},
      );

      final pending = await SyncOutbox.getPendingEntries();
      expect(pending.length, 1);

      final id = pending[0]['id'] as String;
      await SyncOutbox.markCompleted(id);

      final afterCompletion = await SyncOutbox.getPendingEntries();
      expect(afterCompletion.length, 0);
    });

    test('markFailed increments retry count', () async {
      await SyncOutbox.enqueue(
        operation: 'createReport',
        payload: {'patientId': 'p1'},
      );

      final pending = await SyncOutbox.getPendingEntries();
      final id = pending[0]['id'] as String;

      await SyncOutbox.markFailed(id);
      final afterFail = await SyncOutbox.getPendingEntries();

      expect(afterFail.length, 1);
      expect(afterFail[0]['retryCount'], 1);
    });

    test('multiple failures increment retry count correctly', () async {
      await SyncOutbox.enqueue(
        operation: 'createReport',
        payload: {'patientId': 'p1'},
      );

      final pending = await SyncOutbox.getPendingEntries();
      final id = pending[0]['id'] as String;

      await SyncOutbox.markFailed(id);
      await SyncOutbox.markFailed(id);
      await SyncOutbox.markFailed(id);

      final afterFails = await SyncOutbox.getPendingEntries();
      expect(afterFails[0]['retryCount'], 3);
    });

    test('pendingCount returns correct count', () async {
      expect(await SyncOutbox.pendingCount(), 0);

      await SyncOutbox.enqueue(operation: 'op1', payload: {});
      expect(await SyncOutbox.pendingCount(), 1);

      await SyncOutbox.enqueue(operation: 'op2', payload: {});
      expect(await SyncOutbox.pendingCount(), 2);

      final pending = await SyncOutbox.getPendingEntries();
      await SyncOutbox.markCompleted(pending[0]['id'] as String);
      expect(await SyncOutbox.pendingCount(), 1);
    });

    test('handles corrupted outbox file gracefully', () async {
      final dir = fakePathProvider.tempDir;
      final outboxDir = Directory('${dir.path}/offline_outbox');
      outboxDir.createSync(recursive: true);
      final outboxFile = File('${outboxDir.path}/outbox.json');
      await outboxFile.writeAsString('definitely not json!!!');

      // Should return empty list instead of throwing
      final pending = await SyncOutbox.getPendingEntries();
      expect(pending, isEmpty);
    });

    test('survives across reinitializaton (persistence check)', () async {
      // Enqueue an item
      await SyncOutbox.enqueue(
        operation: 'persistenceCheck',
        payload: {'test': true},
      );

      // Simulate "restart" by querying again
      // (in real life, the app would restart and re-read from disk)
      final pending = await SyncOutbox.getPendingEntries();
      expect(pending.length, 1);
      expect(pending[0]['operation'], 'persistenceCheck');
    });
  });
}
