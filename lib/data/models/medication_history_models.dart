import 'package:flutter/material.dart';

enum MedicationEventType {
  started,
  increased,
  decreased,
  stopped,
  continued, // For events where dose stayed the same but was re-confirmed
}

class MedicationEvent {
  final DateTime date;
  final MedicationEventType type;
  final String? dose;
  final String? frequency;
  final String? remarks;
  final String? consultationId;

  const MedicationEvent({
    required this.date,
    required this.type,
    this.dose,
    this.frequency,
    this.remarks,
    this.consultationId,
  });

  factory MedicationEvent.fromJson(Map<String, dynamic> json) {
    return MedicationEvent(
      date: DateTime.parse(json['date']),
      type: _parseType(json['type']),
      dose: json['dose'],
      frequency: json['frequency'],
      remarks: json['remarks'],
      consultationId: json['consultation_id'],
    );
  }

  static MedicationEventType _parseType(String type) {
    switch (type.toLowerCase()) {
      case 'started':
        return MedicationEventType.started;
      case 'increased':
        return MedicationEventType.increased;
      case 'decreased':
        return MedicationEventType.decreased;
      case 'stopped':
        return MedicationEventType.stopped;
      case 'continued':
        return MedicationEventType.continued;
      default:
        return MedicationEventType.continued;
    }
  }

  String get typeLabel {
    switch (type) {
      case MedicationEventType.started:
        return 'Started';
      case MedicationEventType.increased:
        return 'Increased';
      case MedicationEventType.decreased:
        return 'Decreased';
      case MedicationEventType.stopped:
        return 'Stopped';
      case MedicationEventType.continued:
        return 'Continued';
    }
  }

  IconData get icon {
    switch (type) {
      case MedicationEventType.started:
        return Icons.add_circle_outline;
      case MedicationEventType.increased:
        return Icons.trending_up;
      case MedicationEventType.decreased:
        return Icons.trending_down;
      case MedicationEventType.stopped:
        return Icons.remove_circle_outline;
      case MedicationEventType.continued:
        return Icons.check_circle_outline;
    }
  }

  Color get color {
    switch (type) {
      case MedicationEventType.started:
        return Colors.green;
      case MedicationEventType.increased:
        return Colors.orange;
      case MedicationEventType.decreased:
        return Colors.blue;
      case MedicationEventType.stopped:
        return Colors.red;
      case MedicationEventType.continued:
        return Colors.grey;
    }
  }
}

class MedicationLifespan {
  final String name;
  final List<MedicationEvent> events;

  const MedicationLifespan({required this.name, required this.events});

  DateTime get startDate =>
      events.isNotEmpty ? events.first.date : DateTime.now();
  DateTime? get endDate =>
      events.any((e) => e.type == MedicationEventType.stopped)
      ? events.firstWhere((e) => e.type == MedicationEventType.stopped).date
      : null;

  bool get isActive => endDate == null;
}

class PatientMedicationHistory {
  final String patientId;
  final List<MedicationLifespan> lifespans;

  const PatientMedicationHistory({
    required this.patientId,
    required this.lifespans,
  });
}
