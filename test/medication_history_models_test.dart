import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/models/medication_history_models.dart';

void main() {
  group('MedicationEvent', () {
    test('should parse event type from string correctly', () {
      final startedEvent = MedicationEvent.fromJson({
        'date': '2026-01-01T10:00:00Z',
        'type': 'started',
      });
      expect(startedEvent.type, MedicationEventType.started);

      final increasedEvent = MedicationEvent.fromJson({
        'date': '2026-01-01T10:00:00Z',
        'type': 'increased',
      });
      expect(increasedEvent.type, MedicationEventType.increased);

      final decreasedEvent = MedicationEvent.fromJson({
        'date': '2026-01-01T10:00:00Z',
        'type': 'decreased',
      });
      expect(decreasedEvent.type, MedicationEventType.decreased);

      final stoppedEvent = MedicationEvent.fromJson({
        'date': '2026-01-01T10:00:00Z',
        'type': 'stopped',
      });
      expect(stoppedEvent.type, MedicationEventType.stopped);

      final continuedEvent = MedicationEvent.fromJson({
        'date': '2026-01-01T10:00:00Z',
        'type': 'continued',
      });
      expect(continuedEvent.type, MedicationEventType.continued);
    });

    test('should handle unknown event type as continued', () {
      final event = MedicationEvent.fromJson({
        'date': '2026-01-01T10:00:00Z',
        'type': 'unknown_type',
      });
      expect(event.type, MedicationEventType.continued);
    });

    test('should deserialize complete event from JSON', () {
      final json = {
        'date': '2026-01-15T14:30:00Z',
        'type': 'started',
        'dose': 'Tab Sertraline 50mg',
        'frequency': '1-0-1',
        'remarks': 'After food',
        'consultation_id': 'consult-123',
      };

      final event = MedicationEvent.fromJson(json);

      expect(event.date, DateTime.parse('2026-01-15T14:30:00Z'));
      expect(event.type, MedicationEventType.started);
      expect(event.dose, 'Tab Sertraline 50mg');
      expect(event.frequency, '1-0-1');
      expect(event.remarks, 'After food');
      expect(event.consultationId, 'consult-123');
    });

    test('should return correct type labels', () {
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.started,
        ).typeLabel,
        'Started',
      );
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.increased,
        ).typeLabel,
        'Increased',
      );
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.decreased,
        ).typeLabel,
        'Decreased',
      );
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.stopped,
        ).typeLabel,
        'Stopped',
      );
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.continued,
        ).typeLabel,
        'Continued',
      );
    });

    test('should return correct icons for event types', () {
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.started,
        ).icon.codePoint,
        Icons.add_circle_outline.codePoint,
      );
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.increased,
        ).icon.codePoint,
        Icons.trending_up.codePoint,
      );
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.decreased,
        ).icon.codePoint,
        Icons.trending_down.codePoint,
      );
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.stopped,
        ).icon.codePoint,
        Icons.remove_circle_outline.codePoint,
      );
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.continued,
        ).icon.codePoint,
        Icons.check_circle_outline.codePoint,
      );
    });

    test('should return correct colors for event types', () {
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.started,
        ).color,
        Colors.green,
      );
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.increased,
        ).color,
        Colors.orange,
      );
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.decreased,
        ).color,
        Colors.blue,
      );
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.stopped,
        ).color,
        Colors.red,
      );
      expect(
        MedicationEvent(
          date: DateTime.now(),
          type: MedicationEventType.continued,
        ).color,
        Colors.grey,
      );
    });
  });

  group('MedicationLifespan', () {
    test('should calculate start date from first event', () {
      final events = [
        MedicationEvent(
          date: DateTime(2025, 6, 1),
          type: MedicationEventType.started,
        ),
        MedicationEvent(
          date: DateTime(2025, 9, 1),
          type: MedicationEventType.increased,
        ),
      ];

      final lifespan = MedicationLifespan(name: 'Sertraline', events: events);
      expect(lifespan.startDate, DateTime(2025, 6, 1));
    });

    test('should calculate end date from stopped event', () {
      final events = [
        MedicationEvent(
          date: DateTime(2025, 6, 1),
          type: MedicationEventType.started,
        ),
        MedicationEvent(
          date: DateTime(2025, 9, 1),
          type: MedicationEventType.increased,
        ),
        MedicationEvent(
          date: DateTime(2025, 12, 1),
          type: MedicationEventType.stopped,
        ),
      ];

      final lifespan = MedicationLifespan(name: 'Sertraline', events: events);
      expect(lifespan.endDate, DateTime(2025, 12, 1));
      expect(lifespan.isActive, false);
    });

    test('should return null end date for active medication', () {
      final events = [
        MedicationEvent(
          date: DateTime(2025, 6, 1),
          type: MedicationEventType.started,
        ),
        MedicationEvent(
          date: DateTime(2025, 9, 1),
          type: MedicationEventType.increased,
        ),
      ];

      final lifespan = MedicationLifespan(name: 'Sertraline', events: events);
      expect(lifespan.endDate, null);
      expect(lifespan.isActive, true);
    });

    test('should handle empty events list', () {
      const lifespan = MedicationLifespan(name: 'Sertraline', events: []);
      expect(lifespan.startDate.year, DateTime.now().year);
      expect(lifespan.endDate, null);
      expect(lifespan.isActive, true);
    });

    test('should identify active medication correctly', () {
      final activeLifespan = MedicationLifespan(
        name: 'Sertraline',
        events: [
          MedicationEvent(
            date: DateTime(2025, 6, 1),
            type: MedicationEventType.started,
          ),
        ],
      );
      expect(activeLifespan.isActive, true);

      final inactiveLifespan = MedicationLifespan(
        name: 'Fluoxetine',
        events: [
          MedicationEvent(
            date: DateTime(2025, 1, 1),
            type: MedicationEventType.started,
          ),
          MedicationEvent(
            date: DateTime(2025, 3, 1),
            type: MedicationEventType.stopped,
          ),
        ],
      );
      expect(inactiveLifespan.isActive, false);
    });
  });

  group('PatientMedicationHistory', () {
    test('should create patient medication history', () {
      final lifespans = [
        MedicationLifespan(
          name: 'Sertraline',
          events: [
            MedicationEvent(
              date: DateTime(2025, 6, 1),
              type: MedicationEventType.started,
            ),
          ],
        ),
        MedicationLifespan(
          name: 'Fluoxetine',
          events: [
            MedicationEvent(
              date: DateTime(2025, 1, 1),
              type: MedicationEventType.started,
            ),
            MedicationEvent(
              date: DateTime(2025, 3, 1),
              type: MedicationEventType.stopped,
            ),
          ],
        ),
      ];

      final history = PatientMedicationHistory(
        patientId: 'patient-123',
        lifespans: lifespans,
      );

      expect(history.patientId, 'patient-123');
      expect(history.lifespans.length, 2);
      expect(history.lifespans[0].name, 'Sertraline');
      expect(history.lifespans[1].name, 'Fluoxetine');
    });

    test('should handle empty lifespans', () {
      const history = PatientMedicationHistory(
        patientId: 'patient-123',
        lifespans: [],
      );

      expect(history.patientId, 'patient-123');
      expect(history.lifespans, isEmpty);
    });
  });

  group('MedicationEvent - Complex Scenarios', () {
    test('should handle medication dose increase over time', () {
      final events = [
        MedicationEvent(
          date: DateTime(2025, 1, 1),
          type: MedicationEventType.started,
          dose: 'Tab Sertraline 25mg',
          frequency: '1-0-0',
        ),
        MedicationEvent(
          date: DateTime(2025, 2, 1),
          type: MedicationEventType.increased,
          dose: 'Tab Sertraline 50mg',
          frequency: '1-0-0',
        ),
        MedicationEvent(
          date: DateTime(2025, 4, 1),
          type: MedicationEventType.increased,
          dose: 'Tab Sertraline 100mg',
          frequency: '1-0-1',
        ),
      ];

      expect(events[0].dose, 'Tab Sertraline 25mg');
      expect(events[1].dose, 'Tab Sertraline 50mg');
      expect(events[2].dose, 'Tab Sertraline 100mg');
      expect(events[2].frequency, '1-0-1');
    });

    test('should handle medication tapering (dose decrease)', () {
      final events = [
        MedicationEvent(
          date: DateTime(2025, 1, 1),
          type: MedicationEventType.started,
          dose: 'Tab Clonazepam 2mg',
          frequency: '0-0-1',
        ),
        MedicationEvent(
          date: DateTime(2025, 3, 1),
          type: MedicationEventType.decreased,
          dose: 'Tab Clonazepam 1mg',
          frequency: '0-0-1',
        ),
        MedicationEvent(
          date: DateTime(2025, 5, 1),
          type: MedicationEventType.decreased,
          dose: 'Tab Clonazepam 0.5mg',
          frequency: '0-0-1',
        ),
        MedicationEvent(
          date: DateTime(2025, 6, 1),
          type: MedicationEventType.stopped,
        ),
      ];

      final lifespan = MedicationLifespan(name: 'Clonazepam', events: events);
      expect(lifespan.isActive, false);
      expect(lifespan.endDate, DateTime(2025, 6, 1));
    });
  });
}
