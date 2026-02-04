import 'package:flutter/material.dart';

/// Medical-specific semantic colors for the SynapseAI app
/// Provides consistent color usage across medical contexts
class MedicalColors {
  MedicalColors._(); // Private constructor to prevent instantiation

  // Patient Status Colors

  /// Patient is waiting for consultation
  static const waiting = Color(0xFFFF9800); // Orange

  /// Patient is currently being consulted
  static const active = Color(0xFF2196F3); // Blue

  /// Patient consultation is completed
  static const completed = Color(0xFF4CAF50); // Green

  /// Patient consultation was cancelled
  static const cancelled = Color(0xFFF44336); // Red

  /// Patient is discharged
  static const discharged = Color(0xFF9E9E9E); // Grey

  /// Patient is archived
  static const archived = Color(0xFF757575); // Dark Grey

  // Medical Context Colors

  /// Critical/Alert conditions (allergies, warnings)
  static const critical = Color(0xFFD32F2F);
  static const criticalBg = Color(0xFFFEEBEE);
  static const criticalBorder = Color(0xFFEF9A9A);

  /// Normal/Healthy indicators
  static const healthy = Color(0xFF388E3C);
  static const healthyBg = Color(0xFFE8F5E9);
  static const healthyBorder = Color(0xFFA5D6A7);

  /// Warning/Caution indicators
  static const warning = Color(0xFFF57C00);
  static const warningBg = Color(0xFFFFF3E0);
  static const warningBorder = Color(0xFFFFCC80);

  /// Information/Neutral
  static const info = Color(0xFF1976D2);
  static const infoBg = Color(0xFFE3F2FD);
  static const infoBorder = Color(0xFF90CAF9);

  // Data Visualization Colors

  /// Positive metrics (improvement, increase)
  static const positiveMetric = Color(0xFF4CAF50);

  /// Negative metrics (decline, decrease)
  static const negativeMetric = Color(0xFFF44336);

  /// Neutral/Stable metrics
  static const neutralMetric = Color(0xFF9E9E9E);

  // Specialty-specific Colors

  /// Cardiology
  static const cardiology = Color(0xFFE91E63);

  /// Neurology
  static const neurology = Color(0xFF9C27B0);

  /// Orthopedics
  static const orthopedics = Color(0xFF795548);

  /// Pediatrics
  static const pediatrics = Color(0xFFFF9800);

  /// General Medicine
  static const generalMedicine = Color(0xFF2196F3);

  // Additional Medical UI Colors

  /// Primary medical theme color
  static const medicalPrimary = Color(0xFF1976D2);

  /// Accent color 1 - for categories/types
  static const medicalAccent1 = Color(0xFF2196F3); // Blue

  /// Accent color 2 - for categories/types
  static const medicalAccent2 = Color(0xFF4CAF50); // Green

  /// Warning color for medical contexts
  static const medicalWarning = Color(0xFFFF9800); // Orange

  /// Error color for critical medical contexts
  static const statusError = Color(0xFFD32F2F); // Red

  // Status Badge Helpers

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return waiting;
      case 'active':
      case 'in_progress':
        return active;
      case 'completed':
        return completed;
      case 'cancelled':
        return cancelled;
      case 'discharged':
        return discharged;
      case 'archived':
        return archived;
      default:
        return neutralMetric;
    }
  }

  static Color getStatusBackground(String status, {double opacity = 0.1}) {
    return getStatusColor(status).withOpacity(opacity);
  }
}
