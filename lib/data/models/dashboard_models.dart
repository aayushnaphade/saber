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
  final String appointmentType; // 'walk-in' or 'scheduled'

  const Appointment({
    required this.id,
    required this.patientName,
    required this.patientId,
    required this.time,
    required this.reason,
    required this.status,
    this.avatarUrl,
    this.appointmentType = 'walk-in',
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

  const QueueItem({
    required this.id,
    required this.patientName,
    required this.patientId,
    required this.position,
    required this.estimatedWaitTime,
    required this.status,
  });
}

class DashboardStats {
  final int patientsToday;
  final int pendingReports;
  final int completedSessions;
  final int totalConsultationMinutes;

  const DashboardStats({
    required this.patientsToday,
    required this.pendingReports,
    required this.completedSessions,
    required this.totalConsultationMinutes,
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
      patientsToday: 12,
      pendingReports: 3,
      completedSessions: 5,
      totalConsultationMinutes: 45,
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
      const QueueItem(
        id: 'q1',
        patientName: 'Michael Chen',
        patientId: 'P-1002',
        position: 0,
        estimatedWaitTime: Duration.zero,
        status: 'In Consultation',
      ),
      const QueueItem(
        id: 'q2',
        patientName: 'Emma Davis',
        patientId: 'P-1003',
        position: 1,
        estimatedWaitTime: Duration(minutes: 15),
        status: 'In Vitals',
      ),
      const QueueItem(
        id: 'q3',
        patientName: 'Robert Taylor',
        patientId: 'P-1005',
        position: 2,
        estimatedWaitTime: Duration(minutes: 30),
        status: 'Waiting',
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
