import 'package:flutter/material.dart';

enum AppointmentStatus { upcoming, completed, cancelled, inProgress }

class Appointment {
  final String id;
  final String patientName;
  final String patientId;
  final DateTime time;
  final String reason;
  final AppointmentStatus status;
  final String? avatarUrl;
  final String appointmentType;
  final String? gender;
  final int? age;
  final String? registrationNumber;
  final int? sessionNumber;

  const Appointment({
    required this.id,
    required this.patientName,
    required this.patientId,
    required this.time,
    required this.reason,
    required this.status,
    this.avatarUrl,
    this.appointmentType = 'walk-in',
    this.gender,
    this.age,
    this.registrationNumber,
    this.sessionNumber,
  });

  bool get isScheduled => appointmentType == 'scheduled';
}

class QueueItem {
  final String id;
  final String patientName;
  final String patientId;
  final int position;
  final Duration estimatedWaitTime;
  final String status; // "Waiting", "In Vitals", "Ready"
  final int age;
  final String gender;
  final DateTime registeredTime;
  final String patientType;
  final String? registrationNumber;
  final String? avatarUrl;

  const QueueItem({
    required this.id,
    required this.patientName,
    required this.patientId,
    required this.position,
    required this.estimatedWaitTime,
    required this.status,
    required this.age,
    required this.gender,
    required this.registeredTime,
    required this.patientType,
    this.registrationNumber,
    this.avatarUrl,
  });
}

class DashboardStats {
  final int consultationsToday;
  final int pendingConsultations;
  final int completedSessions;
  final int totalConsultationMinutes;
  final double? consultationsTrend; // Percentage change
  final double? timeTrend; // Percentage change

  const DashboardStats({
    required this.consultationsToday,
    required this.pendingConsultations,
    required this.completedSessions,
    required this.totalConsultationMinutes,
    this.consultationsTrend = 0.0,
    this.timeTrend = 0.0,
  });
}

enum InsightType { trend, action, alert, info }

class AIInsight {
  final String id;
  final String title;
  final String description;
  final InsightType type;
  final DateTime timestamp;

  const AIInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.timestamp,
  });

  IconData get icon {
    switch (type) {
      case InsightType.trend:
        return Icons.trending_up;
      case InsightType.action:
        return Icons.assignment_outlined;
      case InsightType.alert:
        return Icons.warning_amber_rounded;
      case InsightType.info:
        return Icons.lightbulb_outline;
    }
  }

  Color get color {
    switch (type) {
      case InsightType.trend:
        return Colors.blue;
      case InsightType.action:
        return Colors.green;
      case InsightType.alert:
        return Colors.orange;
      case InsightType.info:
        return Colors.purple;
    }
  }

  String get actionLabel {
    switch (type) {
      case InsightType.trend:
        return 'View Report';
      case InsightType.action:
        return 'View';
      case InsightType.alert:
        return 'Review';
      case InsightType.info:
        return 'Dismiss';
    }
  }
}

// Mock Data Generator
class MockDashboardData {
  static DashboardStats getStats() {
    return const DashboardStats(
      consultationsToday: 12,
      pendingConsultations: 3,
      completedSessions: 5,
      totalConsultationMinutes: 45,
      consultationsTrend: 12.5,
      timeTrend: -5.0,
    );
  }

  static List<Appointment> getTodayAppointments() {
    final now = DateTime.now();
    return [
      Appointment(
        id: '1',
        patientName: 'Sarah Johnson',
        patientId: 'P-1001',
        time: DateTime(now.year, now.month, now.day, 9, 0),
        reason: 'Annual Checkup',
        status: AppointmentStatus.completed,
      ),
      Appointment(
        id: '2',
        patientName: 'Michael Chen',
        patientId: 'P-1002',
        time: DateTime(now.year, now.month, now.day, 10, 30),
        reason: 'Migraine Follow-up',
        status: AppointmentStatus.inProgress,
      ),
      Appointment(
        id: '3',
        patientName: 'Emma Davis',
        patientId: 'P-1003',
        time: DateTime(now.year, now.month, now.day, 11, 15),
        reason: 'Vaccination',
        status: AppointmentStatus.upcoming,
      ),
      Appointment(
        id: '4',
        patientName: 'James Wilson',
        patientId: 'P-1004',
        time: DateTime(now.year, now.month, now.day, 14, 0),
        reason: 'Back Pain',
        status: AppointmentStatus.upcoming,
      ),
    ];
  }

  static List<QueueItem> getLiveQueue() {
    return [
      QueueItem(
        id: 'q1',
        patientName: 'Michael Chen',
        patientId: 'P-1002',
        position: 0,
        estimatedWaitTime: Duration.zero,
        status: 'In Consultation',
        age: 45,
        gender: 'Male',
        registeredTime: DateTime.now().subtract(const Duration(minutes: 30)),
        patientType: 'Follow-up',
      ),
      QueueItem(
        id: 'q2',
        patientName: 'Emma Davis',
        patientId: 'P-1003',
        position: 1,
        estimatedWaitTime: const Duration(minutes: 15),
        status: 'In Vitals',
        age: 28,
        gender: 'Female',
        registeredTime: DateTime.now().subtract(const Duration(minutes: 15)),
        patientType: 'New Patient',
      ),
      QueueItem(
        id: 'q3',
        patientName: 'Robert Taylor',
        patientId: 'P-1005',
        position: 2,
        estimatedWaitTime: const Duration(minutes: 30),
        status: 'Waiting',
        age: 62,
        gender: 'Male',
        registeredTime: DateTime.now().subtract(const Duration(minutes: 5)),
        patientType: 'Follow-up',
      ),
    ];
  }

  static List<AIInsight> getInsights() {
    return [
      AIInsight(
        id: 'mock1',
        title: 'Pending Summaries',
        description: '3 sessions need your review',
        type: InsightType.alert,
        timestamp: DateTime.now(),
      ),
      AIInsight(
        id: 'mock2',
        title: 'Transcription Ready',
        description: 'Session with Sarah Johnson processed',
        type: InsightType.action,
        timestamp: DateTime.now(),
      ),
    ];
  }
}

class ClinicalReport {
  final String id;
  final String patientId;
  final String clinicId;
  final DateTime createdAt;
  final DateTime sessionDate;
  final String? patientName;
  final String? sourceDocumentPath;
  final Map<String, dynamic> structuredData;
  final String? markdownContent;
  final String status;

  ClinicalReport({
    required this.id,
    required this.patientId,
    required this.clinicId,
    required this.createdAt,
    required this.sessionDate,
    this.patientName,
    this.sourceDocumentPath,
    required this.structuredData,
    this.markdownContent,
    this.status = 'verified',
  });

  factory ClinicalReport.fromJson(Map<String, dynamic> json) {
    // Extract patient name from joined patients table first,
    // then fall back to structured_data
    String? name;
    if (json['patients'] != null && json['patients']['full_name'] != null) {
      name = json['patients']['full_name'].toString();
    } else if (json['structured_data'] != null &&
        json['structured_data']['patient_name'] != null) {
      name = json['structured_data']['patient_name'].toString();
    }

    return ClinicalReport(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      clinicId: json['clinic_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      sessionDate: DateTime.parse(json['session_date'] as String).toLocal(),
      patientName: name,
      sourceDocumentPath: json['source_document_path'] as String?,
      structuredData: json['structured_data'] as Map<String, dynamic>,
      markdownContent: json['markdown_content'] as String?,
      status: json['status'] as String? ?? 'verified',
    );
  }

  /// Creates a lightweight placeholder from a locally-queued offline report.
  /// Used to keep the pending-review banner visible while the report is being
  /// generated and uploaded by OfflineReportWorker.
  // factory ClinicalReport.fromOfflineReport(PendingReport r) { ... }
  // NOTE: Moving this constructor requires importing PendingReport/OfflineReportQueue
  // which causes circular dependency. Since we are removing the usage of this
  // constructor in dashboard_page.dart ANYWAY, we can omit it here!
  // Or if we need it, we should move PendingReport model to dashboard_models.dart too.
  // For now, omitting it as per the fix plan.

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'clinic_id': clinicId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'session_date': sessionDate.toIso8601String().split('T')[0],
      'source_document_path': sourceDocumentPath,
      'structured_data': structuredData,
      'markdown_content': markdownContent,
      'status': status,
    };
  }
}
