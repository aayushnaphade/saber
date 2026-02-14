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
        OutboxEntry(
          operation: 'completeConsultation',
          payload: {'consultationId': 'c123', 'status': 'completed'},
        ),
      );

      final pending = await SyncOutbox.getPending();
      expect(pending.length, 1);
      expect(pending[0].operation, 'completeConsultation');
      expect(pending[0].payload['consultationId'], 'c123');
      expect(pending[0].status, OutboxStatus.pending);
    });

    test('multiple enqueue operations are ordered FIFO', () async {
      await SyncOutbox.enqueue(
        OutboxEntry(operation: 'op1', payload: {'key': 'first'}),
      );
      await SyncOutbox.enqueue(
        OutboxEntry(operation: 'op2', payload: {'key': 'second'}),
      );
      await SyncOutbox.enqueue(
        OutboxEntry(operation: 'op3', payload: {'key': 'third'}),
      );

      final pending = await SyncOutbox.getPending();
      expect(pending.length, 3);
      expect(pending[0].operation, 'op1');
      expect(pending[1].operation, 'op2');
      expect(pending[2].operation, 'op3');
    });

    test('markCompleted removes entry from pending', () async {
      await SyncOutbox.enqueue(
        OutboxEntry(
          operation: 'completeConsultation',
          payload: {'consultationId': 'c123'},
        ),
      );

      final pending = await SyncOutbox.getPending();
      expect(pending.length, 1);

      final id = pending[0].id;
      await SyncOutbox.markCompleted(id);

      final afterCompletion = await SyncOutbox.getPending();
      expect(afterCompletion.length, 0);
    });

    test('markTransientFailure increments retry count', () async {
      await SyncOutbox.enqueue(
        OutboxEntry(operation: 'createReport', payload: {'patientId': 'p1'}),
      );

      final pending = await SyncOutbox.getPending();
      final id = pending[0].id;

      await SyncOutbox.markTransientFailure(id, 'error');
      // Must read from disk/cache again to check persistence
      // Since getPending returns objects, we need fresh ones
      final afterFail = await SyncOutbox.getPending();

      expect(afterFail.length, 1);
      expect(afterFail[0].retryCount, 1);
      expect(afterFail[0].status, OutboxStatus.pending);
    });

    test('markPermanentFailure sets status to failed', () async {
      await SyncOutbox.enqueue(
        OutboxEntry(operation: 'createReport', payload: {'patientId': 'p1'}),
      );

      final pending = await SyncOutbox.getPending();
      final id = pending[0].id;

      await SyncOutbox.markPermanentFailure(id, 'error');

      // Should NOT appear in getPending() anymore
      final afterFail = await SyncOutbox.getPending();
      expect(afterFail, isEmpty);

      // But counts should differ? pendingCount also filters it out.
      expect(await SyncOutbox.pendingCount(), 0);
    });

    test('pendingCount returns correct count', () async {
      expect(await SyncOutbox.pendingCount(), 0);

      await SyncOutbox.enqueue(OutboxEntry(operation: 'op1', payload: {}));
      expect(await SyncOutbox.pendingCount(), 1);

      await SyncOutbox.enqueue(OutboxEntry(operation: 'op2', payload: {}));
      expect(await SyncOutbox.pendingCount(), 2);

      final pending = await SyncOutbox.getPending();
      await SyncOutbox.markCompleted(pending[0].id);
      expect(await SyncOutbox.pendingCount(), 1);
    });
  });
}
