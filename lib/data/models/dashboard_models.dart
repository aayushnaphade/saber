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

  const Appointment({
    required this.id,
    required this.patientName,
    required this.patientId,
    required this.time,
    required this.reason,
    required this.status,
    this.avatarUrl,
  });
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
  final double averageTimePerPatient; // in minutes

  const DashboardStats({
    required this.patientsToday,
    required this.pendingReports,
    required this.completedSessions,
    required this.averageTimePerPatient,
  });
}

class AIInsight {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String actionLabel;

  const AIInsight({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.actionLabel,
  });
}

// Mock Data Generator
class MockDashboardData {
  static DashboardStats getStats() {
    return const DashboardStats(
      patientsToday: 12,
      pendingReports: 3,
      completedSessions: 5,
      averageTimePerPatient: 18.5,
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
      const AIInsight(
        title: 'Pending Summaries',
        description: '3 sessions need your review',
        icon: Icons.summarize_outlined,
        color: Colors.orange,
        actionLabel: 'Review',
      ),
      const AIInsight(
        title: 'Transcription Ready',
        description: 'Session with Sarah Johnson processed',
        icon: Icons.record_voice_over_outlined,
        color: Colors.green,
        actionLabel: 'View',
      ),
    ];
  }
}
