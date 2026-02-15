import 'dart:async';
import 'package:logging/logging.dart';
import 'package:saber/data/models/patient.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/services/offline_patient_cache.dart';
import 'package:saber/data/services/sync_outbox.dart';
import 'package:saber/data/supabase/supabase_client.dart';
import 'package:uuid/uuid.dart';

/// Service for managing patient data in Supabase
class SupabasePatientService {
  static final log = Logger('SupabasePatientService');

  /// Get all patients for the current doctor (including archived)
  static Future<List<Patient>> getAllPatients() async {
    try {
      log.info('Fetching all patients');

      // 1. If offline, return cached data immediately
      if (!stows.isOnline.value) {
        log.info('Offline: Fetching patients from cache');
        final cached = await OfflinePatientCache.loadPatients();
        if (cached.isNotEmpty) {
          return cached;
        }
        // If cache is empty, fall through to try network (which might throw, but correct behavior)
      }

      final response = await supabase
          .from('patients')
          .select('*, psychiatric_intakes(registration_number)')
          .order('created_at', ascending: false);

      final patients = (response as List)
          .map((json) => Patient.fromJson(json as Map<String, dynamic>))
          .toList();

      // 2. Cache the fresh data
      await OfflinePatientCache.savePatients(patients);

      log.info('Fetched ${patients.length} patients');
      return patients;
    } catch (e) {
      log.severe('Failed to fetch patients', e);
      rethrow;
    }
  }

  /// Get active patients only (not archived)
  static Future<List<Patient>> getActivePatients() async {
    log.info('Fetching active patients');

    // Helper to get from cache
    Future<List<Patient>> getFromCache() async {
      log.info('Offline: Fetching active patients from cache');
      try {
        final allCached = await OfflinePatientCache.loadPatients();
        return allCached.where((p) => p.isActive).toList();
      } catch (e) {
        log.warning('Failed to load active patients from cache', e);
        return [];
      }
    }

    if (!stows.isOnline.value) {
      return getFromCache();
    }

    try {
      final response = await supabase
          .from('patients')
          .select('*, psychiatric_intakes(registration_number)')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final patients = (response as List)
          .map((json) => Patient.fromJson(json as Map<String, dynamic>))
          .toList();

      log.info('Fetched ${patients.length} active patients');
      // We don't overwrite the whole cache here because this is a partial list.
      // But we could merge... for now, rely on getAllPatients or watchPatients to keep cache full.
      return patients;
    } catch (e) {
      log.warning(
        'Failed to fetch active patients online, falling back to cache',
        e,
      );
      return getFromCache();
    }
  }

  /// Get patients in waiting queue
  static Future<List<Patient>> getWaitingPatients() async {
    log.info('Fetching waiting patients');

    // Helper to get from cache
    Future<List<Patient>> getFromCache() async {
      log.info('Offline: Fetching waiting patients from cache');
      try {
        final allCached = await OfflinePatientCache.loadPatients();
        final waiting = allCached
            .where((p) => p.status == PatientStatus.waiting && p.isActive)
            .toList();
        // Sort by created_at ascending (FIFO)
        waiting.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return waiting;
      } catch (e) {
        log.warning('Failed to load waiting patients from cache', e);
        return [];
      }
    }

    if (!stows.isOnline.value) {
      return getFromCache();
    }

    try {
      final response = await supabase
          .from('patients')
          .select()
          .eq('status', 'waiting')
          .eq('is_active', true)
          .order('created_at', ascending: true); // FIFO order

      final patients = (response as List)
          .map((json) => Patient.fromJson(json as Map<String, dynamic>))
          .toList();

      log.info('Fetched ${patients.length} waiting patients');
      return patients;
    } catch (e) {
      log.warning(
        'Failed to fetch waiting patients online, falling back to cache',
        e,
      );
      return getFromCache();
    }
  }

  /// Get a single patient by ID
  static Future<Patient?> getPatient(String patientId) async {
    log.info('Fetching patient: $patientId');

    // Helper to find in cache
    Future<Patient?> findInCache() async {
      log.info('Fetching patient $patientId from cache');
      try {
        final allCached = await OfflinePatientCache.loadPatients();
        return allCached.firstWhere((p) => p.id == patientId);
      } catch (_) {
        return null; // Not found in cache
      }
    }

    // 1. If offline, find in cache immediately
    if (!stows.isOnline.value) {
      return findInCache();
    }

    // 2. Try Network
    try {
      final response = await supabase
          .from('patients')
          .select('*, psychiatric_intakes(registration_number)')
          .eq('id', patientId)
          .maybeSingle();

      if (response == null) {
        log.info('Patient not found on server: $patientId');
        return null;
      }

      final patient = Patient.fromJson(response);

      // 3. Update Cache with fresh data
      // We don't await this to keep UI snappy, or we can await if we want strict consistency
      unawaited(OfflinePatientCache.updatePatient(patient));

      log.info('Fetched patient: ${patient.fullName}');
      return patient;
    } catch (e) {
      log.warning(
        'Failed to fetch patient from network, falling back to cache',
        e,
      );
      // 4. Fallback to cache on network error
      final cached = await findInCache();
      if (cached != null) {
        return cached;
      }
      // If not in cache either, rethrow
      rethrow;
    }
  }

  /// Search patients by name
  static Future<List<Patient>> searchPatients(String query) async {
    log.info('Searching patients with query: $query');

    // Helper to search in cache
    Future<List<Patient>> searchInCache() async {
      log.info('Offline: Searching patients "$query" from cache');
      try {
        final allCached = await OfflinePatientCache.loadPatients();
        final q = query.toLowerCase();
        return allCached
            .where((p) => p.fullName.toLowerCase().contains(q))
            .toList();
      } catch (e) {
        log.warning('Failed to search in cache', e);
        return [];
      }
    }

    if (!stows.isOnline.value) {
      return searchInCache();
    }

    try {
      final response = await supabase
          .from('patients')
          .select('*, psychiatric_intakes(registration_number)')
          .ilike('full_name', '%$query%')
          .order('created_at', ascending: false);

      final patients = (response as List)
          .map((json) => Patient.fromJson(json as Map<String, dynamic>))
          .toList();

      log.info('Found ${patients.length} patients matching "$query"');
      return patients;
    } catch (e) {
      log.warning('Failed to search patients online, falling back to cache', e);
      return searchInCache();
    }
  }

  /// Create a new patient
  static Future<Patient> createPatient({
    required String fullName,
    int? age,
    String? gender,
    String? phoneNumber,
    String? email,
    String? address,
    Map<String, dynamic>? medicalHistory,
  }) async {
    try {
      log.info('Creating patient: $fullName');

      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final patient = Patient(
        id: const Uuid().v4(), // Generate ID locally for offline support
        createdAt: DateTime.now(),
        fullName: fullName,
        age: age,
        gender: gender,
        status: PatientStatus.waiting,
        lastVisit: null,
        doctorId: currentUserId,
        phoneNumber: phoneNumber,
        email: email,
        address: address,
        medicalHistory: medicalHistory,
        isActive: true,
      );

      // 1. Optimistic Update: Save to local cache immediately
      await OfflinePatientCache.updatePatient(patient);

      // 2. If offline, queue to Outbox
      if (!stows.isOnline.value) {
        log.info('Offline: Queuing patient creation');
        await SyncOutbox.enqueue(
          OutboxEntry(
            operation: 'create_patient',
            payload: patient.toInsertJson()..['id'] = patient.id, // Include ID
          ),
        );
        return patient;
      }

      // 3. If online, try sending (but use our ID)
      final response = await supabase
          .from('patients')
          .insert(patient.toInsertJson()..['id'] = patient.id) // Force our ID
          .select()
          .single();

      final createdPatient = Patient.fromJson(response);
      log.info('Created patient: ${createdPatient.id}');

      // Update cache with confirmed server data (should match)
      await OfflinePatientCache.updatePatient(createdPatient);

      return createdPatient;
    } catch (e) {
      log.severe('Failed to create patient', e);
      rethrow;
    }
  }

  /// Update patient information
  static Future<Patient> updatePatient(
    String patientId,
    Map<String, dynamic> updates,
  ) async {
    try {
      log.info('Updating patient: $patientId');

      // 1. Optimistic Update in Cache
      // We need the full object to update the cache correctly.
      // We'll fetch from cache, apply updates, and save back.
      try {
        final cachedList = await OfflinePatientCache.loadPatients();
        final index = cachedList.indexWhere((p) => p.id == patientId);
        if (index != -1) {
          final original = cachedList[index];
          // Determine new values (simplified for common fields,
          // deep merge is hard without specific logic, but we do best effort)
          final updated = original.copyWith(
            fullName: updates['full_name'] as String?,
            phoneNumber:
                updates['phone_number'] as String? ??
                updates['contact_number'] as String?,
            email: updates['email'] as String?,
            address: updates['address'] as String?,
            status: updates['status'] != null
                ? PatientStatus.fromString(updates['status'] as String)
                : null,
            isActive: updates['is_active'] as bool?,
            lastVisit: updates['last_visit'] != null
                ? DateTime.parse(updates['last_visit'] as String)
                : null,
            // ... add other fields if necessary
          );
          await OfflinePatientCache.updatePatient(updated);
        }
      } catch (e) {
        log.warning('Failed to perform optimistic cache update', e);
      }

      // 2. If offline, queue
      if (!stows.isOnline.value) {
        log.info('Offline: Queuing patient update');
        await SyncOutbox.enqueue(
          OutboxEntry(
            operation: 'update_patient',
            payload: {'id': patientId, ...updates},
          ),
        );
        // We can't return the *server* confirmed object, so we return the optimistic one
        // or re-fetch from cache.
        final cached = await OfflinePatientCache.loadPatients();
        return cached.firstWhere(
          (p) => p.id == patientId,
          orElse: () =>
              throw Exception('Patient not found locally after update'),
        );
      }

      final response = await supabase
          .from('patients')
          .update(updates)
          .eq('id', patientId)
          .select()
          .single();

      final updatedPatient = Patient.fromJson(response);
      await OfflinePatientCache.updatePatient(updatedPatient);

      log.info('Updated patient: ${updatedPatient.id}');
      return updatedPatient;
    } catch (e) {
      log.severe('Failed to update patient: $patientId', e);
      rethrow;
    }
  }

  /// Update patient status
  static Future<Patient> updatePatientStatus(
    String patientId,
    PatientStatus status,
  ) async {
    try {
      log.info('Updating patient status: $patientId -> $status');

      final updates = {
        'status': status.value,
        if (status == PatientStatus.discharged)
          'last_visit': DateTime.now().toUtc().toIso8601String(),
      };

      return await updatePatient(patientId, updates);
    } catch (e) {
      log.severe('Failed to update patient status: $patientId', e);
      rethrow;
    }
  }

  /// Mark patient as inactive (soft delete)
  static Future<void> deactivatePatient(String patientId) async {
    try {
      log.info('Deactivating patient: $patientId');

      // Optimistic update
      await OfflinePatientCache.removePatient(patientId); // Or mark inactive

      if (!stows.isOnline.value) {
        await SyncOutbox.enqueue(
          OutboxEntry(
            operation: 'update_patient',
            payload: {'id': patientId, 'is_active': false},
          ),
        );
        return;
      }

      await supabase
          .from('patients')
          .update({'is_active': false})
          .eq('id', patientId);

      log.info('Deactivated patient: $patientId');
    } catch (e) {
      log.severe('Failed to deactivate patient: $patientId', e);
      rethrow;
    }
  }

  /// Permanently delete patient and cascade to related data
  static Future<void> deletePatient(String patientId) async {
    try {
      log.info('Deleting patient: $patientId');

      // Delete patient.
      // Related rows (e.g. consultations) are deleted by the database via ON DELETE CASCADE.
      await supabase.from('patients').delete().eq('id', patientId);

      // Delete from Storage (best-effort cleanup)
      // We need to list and delete all files in the patient's folder
      try {
        final storage = supabase.storage.from('medical_notes');
        final files = await storage.list(path: patientId);

        if (files.isNotEmpty) {
          final filePaths = files.map((f) => '$patientId/${f.name}').toList();
          await storage.remove(filePaths);
        }

        // Also try to delete subfolders if any (Storage doesn't support recursive delete easily,
        // but we can try to delete known structure if needed. For now, we assume flat or simple structure)
      } catch (storageError) {
        log.warning(
          'Failed to clean up storage for patient: $patientId',
          storageError,
        );
        // Continue even if storage cleanup fails, as DB record is gone
      }

      log.info('Deleted patient: $patientId');
    } catch (e) {
      log.severe('Failed to delete patient: $patientId', e);
      rethrow;
    }
  }

  /// Watch for real-time changes to patients
  static Stream<List<Patient>> watchPatients() {
    late StreamController<List<Patient>> controller;

    controller = StreamController<List<Patient>>(
      onListen: () async {
        // 1. Emit Cache immediately
        try {
          final cached = await OfflinePatientCache.loadPatients();
          if (!controller.isClosed && cached.isNotEmpty) {
            controller.add(cached);
          }
        } catch (e) {
          log.warning('Failed to load cache in stream', e);
        }

        // 2. Start Network Stream
        final networkStream = supabase
            .from('patients')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .map((data) => data.map((json) => Patient.fromJson(json)).toList());

        networkStream.listen(
          (patients) {
            if (!controller.isClosed) {
              controller.add(patients);
              // Update cache with fresh data
              OfflinePatientCache.savePatients(patients);
            }
          },
          onError: (e) {
            log.warning('Realtime stream error (swallowed)', e);
            // Don't emit error to UI, keep showing cached data
          },
          onDone: () {
            if (!controller.isClosed) controller.close();
          },
        );
      },
    );

    return controller.stream;
  }

  /// Watch for real-time changes to waiting queue
  static Stream<List<Patient>> watchWaitingQueue() {
    late StreamController<List<Patient>> controller;

    controller = StreamController<List<Patient>>(
      onListen: () async {
        // 1. Emit Cache immediately (filtered for waiting)
        try {
          final cached = await OfflinePatientCache.loadPatients();
          if (!controller.isClosed) {
            final waiting = cached
                .where((p) => p.status == PatientStatus.waiting && p.isActive)
                .toList();
            // Sort by createdAt ASC for queue
            waiting.sort((a, b) => a.createdAt.compareTo(b.createdAt));

            if (waiting.isNotEmpty) {
              controller.add(waiting);
            }
          }
        } catch (e) {
          log.warning('Failed to load cache in stream', e);
        }

        // 2. Start Network Stream
        final networkStream = supabase
            .from('patients')
            .stream(primaryKey: ['id'])
            .eq('status', 'waiting')
            .order('created_at', ascending: true)
            .map((data) => data.map((json) => Patient.fromJson(json)).toList());

        networkStream.listen(
          (patients) {
            if (!controller.isClosed) {
              controller.add(patients);
              // Note: We don't save *just* the queue to the full patient cache
              // to avoid partial overwrites logic.
              // We rely on `watchPatients` or `getAllPatients` to keep the cache full.
            }
          },
          onError: (e) {
            log.warning('Realtime queue stream error (swallowed)', e);
          },
          onDone: () {
            if (!controller.isClosed) controller.close();
          },
        );
      },
    );

    return controller.stream;
  }
}
