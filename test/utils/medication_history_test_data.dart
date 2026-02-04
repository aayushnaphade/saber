import 'package:saber/data/models/medication_history_models.dart';

/// Helper class to create test data for medication history tests
class MedicationHistoryTestData {
  /// Creates a simple medication history with one active medication
  static PatientMedicationHistory createSimpleHistory() {
    return PatientMedicationHistory(
      patientId: 'test-patient-1',
      lifespans: [
        MedicationLifespan(
          name: 'Sertraline',
          events: [
            MedicationEvent(
              date: DateTime(2025, 6, 1),
              type: MedicationEventType.started,
              dose: 'Tab Sertraline 50mg',
              frequency: '1-0-0',
              remarks: 'After breakfast',
            ),
          ],
        ),
      ],
    );
  }

  /// Creates a complex medication history with multiple medications and events
  static PatientMedicationHistory createComplexHistory() {
    return PatientMedicationHistory(
      patientId: 'test-patient-2',
      lifespans: [
        // Sertraline - Started, increased, still active
        MedicationLifespan(
          name: 'Sertraline',
          events: [
            MedicationEvent(
              date: DateTime(2025, 1, 15),
              type: MedicationEventType.started,
              dose: 'Tab Sertraline 25mg',
              frequency: '1-0-0',
              remarks: 'Start low dose',
              consultationId: 'consult-001',
            ),
            MedicationEvent(
              date: DateTime(2025, 3, 1),
              type: MedicationEventType.increased,
              dose: 'Tab Sertraline 50mg',
              frequency: '1-0-0',
              remarks: 'Increase dose',
              consultationId: 'consult-002',
            ),
            MedicationEvent(
              date: DateTime(2025, 5, 15),
              type: MedicationEventType.increased,
              dose: 'Tab Sertraline 100mg',
              frequency: '1-0-1',
              remarks: 'Therapeutic dose',
              consultationId: 'consult-003',
            ),
          ],
        ),
        // Clonazepam - Started, tapered, stopped
        MedicationLifespan(
          name: 'Clonazepam',
          events: [
            MedicationEvent(
              date: DateTime(2025, 1, 15),
              type: MedicationEventType.started,
              dose: 'Tab Clonazepam 1mg',
              frequency: '0-0-1',
              remarks: 'For sleep',
              consultationId: 'consult-001',
            ),
            MedicationEvent(
              date: DateTime(2025, 4, 1),
              type: MedicationEventType.decreased,
              dose: 'Tab Clonazepam 0.5mg',
              frequency: '0-0-1',
              remarks: 'Tapering',
              consultationId: 'consult-004',
            ),
            MedicationEvent(
              date: DateTime(2025, 6, 1),
              type: MedicationEventType.stopped,
              remarks: 'Discontinued',
              consultationId: 'consult-005',
            ),
          ],
        ),
        // Escitalopram - Started and stopped (switched to Sertraline)
        MedicationLifespan(
          name: 'Escitalopram',
          events: [
            MedicationEvent(
              date: DateTime(2024, 10, 1),
              type: MedicationEventType.started,
              dose: 'Tab Escitalopram 10mg',
              frequency: '1-0-0',
              consultationId: 'consult-000',
            ),
            MedicationEvent(
              date: DateTime(2025, 1, 15),
              type: MedicationEventType.stopped,
              remarks: 'Switching medication',
              consultationId: 'consult-001',
            ),
          ],
        ),
        // Quetiapine - Active, with dose adjustments
        MedicationLifespan(
          name: 'Quetiapine',
          events: [
            MedicationEvent(
              date: DateTime(2025, 2, 1),
              type: MedicationEventType.started,
              dose: 'Tab Quetiapine 25mg',
              frequency: '0-0-1',
              remarks: 'For sleep',
              consultationId: 'consult-006',
            ),
            MedicationEvent(
              date: DateTime(2025, 4, 1),
              type: MedicationEventType.increased,
              dose: 'Tab Quetiapine 50mg',
              frequency: '0-0-1',
              consultationId: 'consult-007',
            ),
          ],
        ),
      ],
    );
  }

  /// Creates a history with medications spanning different time periods
  static PatientMedicationHistory createTimeVariedHistory() {
    final now = DateTime.now();
    return PatientMedicationHistory(
      patientId: 'test-patient-3',
      lifespans: [
        // Medication started 2 years ago, still active
        MedicationLifespan(
          name: 'Lithium',
          events: [
            MedicationEvent(
              date: now.subtract(const Duration(days: 730)),
              type: MedicationEventType.started,
              dose: 'Tab Lithium 300mg',
              frequency: '1-0-1',
            ),
          ],
        ),
        // Medication started 6 months ago
        MedicationLifespan(
          name: 'Aripiprazole',
          events: [
            MedicationEvent(
              date: now.subtract(const Duration(days: 180)),
              type: MedicationEventType.started,
              dose: 'Tab Aripiprazole 10mg',
              frequency: '0-0-1',
            ),
          ],
        ),
        // Medication started 3 months ago
        MedicationLifespan(
          name: 'Propranolol',
          events: [
            MedicationEvent(
              date: now.subtract(const Duration(days: 90)),
              type: MedicationEventType.started,
              dose: 'Tab Propranolol 40mg',
              frequency: '1-0-0',
            ),
          ],
        ),
        // Medication started 1 month ago
        MedicationLifespan(
          name: 'Trihexyphenidyl',
          events: [
            MedicationEvent(
              date: now.subtract(const Duration(days: 30)),
              type: MedicationEventType.started,
              dose: 'Tab Trihexyphenidyl 2mg',
              frequency: '1-0-1',
            ),
          ],
        ),
      ],
    );
  }

  /// Creates mock prescription data for service testing
  static List<Map<String, dynamic>> createMockPrescriptions() {
    return [
      {
        'id': 'rx-001',
        'created_at': '2025-01-15T10:00:00Z',
        'consultation_id': 'consult-001',
        'content': {
          'medications': [
            {
              'name': 'Tab Sertraline 25mg',
              'frequency': '1-0-0',
              'duration': '30 days',
              'remarks': 'After breakfast',
            },
            {
              'name': 'Tab Clonazepam 1mg',
              'frequency': '0-0-1',
              'duration': '30 days',
              'remarks': 'Before sleep',
            },
          ],
        },
      },
      {
        'id': 'rx-002',
        'created_at': '2025-03-01T10:00:00Z',
        'consultation_id': 'consult-002',
        'content': {
          'medications': [
            {
              'name': 'Tab Sertraline 50mg',
              'frequency': '1-0-0',
              'duration': '30 days',
              'remarks': 'After breakfast',
            },
            {
              'name': 'Tab Clonazepam 1mg',
              'frequency': '0-0-1',
              'duration': '30 days',
              'remarks': 'Before sleep',
            },
          ],
        },
      },
      {
        'id': 'rx-003',
        'created_at': '2025-04-01T10:00:00Z',
        'consultation_id': 'consult-003',
        'content': {
          'medications': [
            {
              'name': 'Tab Sertraline 50mg',
              'frequency': '1-0-0',
              'duration': '30 days',
              'remarks': 'After breakfast',
            },
            {
              'name': 'Tab Clonazepam 0.5mg',
              'frequency': '0-0-1',
              'duration': '30 days',
              'remarks': 'Tapering dose',
            },
          ],
        },
      },
      {
        'id': 'rx-004',
        'created_at': '2025-06-01T10:00:00Z',
        'consultation_id': 'consult-004',
        'content': {
          'medications': [
            {
              'name': 'Tab Sertraline 100mg',
              'frequency': '1-0-1',
              'duration': '30 days',
              'remarks': 'After meals',
            },
          ],
        },
      },
    ];
  }

  /// Creates mock AI transition analysis response
  static List<Map<String, dynamic>> createMockAITransitions() {
    return [
      {
        'name': 'Sertraline',
        'type': 'INCREASED',
        'previous_dose': 'Tab Sertraline 25mg',
        'current_dose': 'Tab Sertraline 50mg',
        'current_frequency': '1-0-0',
        'remarks': 'Dose increased for better efficacy',
      },
      {
        'name': 'Clonazepam',
        'type': 'CONTINUED',
        'previous_dose': 'Tab Clonazepam 1mg',
        'current_dose': 'Tab Clonazepam 1mg',
        'current_frequency': '0-0-1',
        'remarks': 'Same dose',
      },
    ];
  }

  /// Creates an empty medication history
  static PatientMedicationHistory createEmptyHistory() {
    return const PatientMedicationHistory(
      patientId: 'test-patient-empty',
      lifespans: [],
    );
  }

  /// Creates a history with only stopped medications
  static PatientMedicationHistory createAllStoppedHistory() {
    return PatientMedicationHistory(
      patientId: 'test-patient-stopped',
      lifespans: [
        MedicationLifespan(
          name: 'Fluoxetine',
          events: [
            MedicationEvent(
              date: DateTime(2024, 1, 1),
              type: MedicationEventType.started,
              dose: 'Tab Fluoxetine 20mg',
              frequency: '1-0-0',
            ),
            MedicationEvent(
              date: DateTime(2024, 6, 1),
              type: MedicationEventType.stopped,
              remarks: 'Treatment completed',
            ),
          ],
        ),
        MedicationLifespan(
          name: 'Alprazolam',
          events: [
            MedicationEvent(
              date: DateTime(2024, 2, 1),
              type: MedicationEventType.started,
              dose: 'Tab Alprazolam 0.5mg',
              frequency: '1-0-1',
            ),
            MedicationEvent(
              date: DateTime(2024, 5, 1),
              type: MedicationEventType.stopped,
              remarks: 'Discontinued',
            ),
          ],
        ),
      ],
    );
  }
}
