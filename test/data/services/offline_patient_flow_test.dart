import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/services/offline_patient_cache.dart';
import 'package:saber/data/services/sync_outbox.dart';
import 'package:saber/data/supabase/supabase_patient_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await OfflinePatientCache.clear();
    await SyncOutbox.clear();
  });

  test('Offline Patient Flow Verification', () async {
    // 1. Simulate Offline
    stows.isOnline.value = false;
    print('--- Step 1: Offline Mode ---');

    // 2. Create Patient (should go to cache + outbox)
    final patient = await SupabasePatientService.createPatient(
      fullName: 'Offline Tester',
      age: 30,
      gender: 'Male',
      phoneNumber: '555-0100',
    );
    print('Created patient: ${patient.id}');

    // 3. Verify in Cache
    final cached = await OfflinePatientCache.loadPatients();
    expect(cached.length, 1);
    expect(cached.first.fullName, 'Offline Tester');
    print('Verified patient in cache');

    // 4. Verify in Outbox
    final outbox = await SyncOutbox.getPending();
    expect(outbox.length, 1);
    expect(outbox.first.operation, 'create_patient');
    expect(outbox.first.payload['id'], patient.id);
    print('Verified create_patient in outbox');

    // 5. Update Patient (should update cache + add to outbox)
    await SupabasePatientService.updatePatient(patient.id, {
      'full_name': 'Offline Tester Updated',
    });

    // 6. Verify Update in Cache
    final cachedUpdated = await OfflinePatientCache.loadPatients();
    expect(cachedUpdated.first.fullName, 'Offline Tester Updated');
    print('Verified update in cache');

    // 7. Verify Update in Outbox
    final outboxUpdated = await SyncOutbox.getPending();
    expect(outboxUpdated.length, 2); // create + update
    expect(outboxUpdated.last.operation, 'update_patient');
    print('Verified update_patient in outbox');

    // Note: We cannot verify actual network sync in this unit test environment easily
    // without mocking Supabase completely, but we have verified the
    // "Offline -> Cache -> Outbox" flow which is our responsibility.
  });
}
