import 'package:flutter/material.dart';

/// Medical-specific semantic colors for the SynapseAI app
/// Provides consistent color usage across medical contexts
class MedicalColors {
  MedicalColors._(); // Private constructor to prevent instantiation

  // Patient Status Colors
  
  /// Patient is waiting for consultation
  static const Color waiting = Color(0xFFFF9800); // Orange
  
  /// Patient is currently being consulted
  static const Color active = Color(0xFF2196F3); // Blue
  
  /// Patient consultation is completed
  static const Color completed = Color(0xFF4CAF50); // Green
  
  /// Patient consultation was cancelled
  static const Color cancelled = Color(0xFFF44336); // Red
  
  /// Patient is discharged
  static const Color discharged = Color(0xFF9E9E9E); // Grey
  
  /// Patient is archived
  static const Color archived = Color(0xFF757575); // Dark Grey

  // Medical Context Colors
  
  /// Critical/Alert conditions (allergies, warnings)
  static const Color critical = Color(0xFFD32F2F);
  static const Color criticalBg = Color(0xFFFEEBEE);
  static const Color criticalBorder = Color(0xFFEF9A9A);
  
  /// Normal/Healthy indicators
  static const Color healthy = Color(0xFF388E3C);
  static const Color healthyBg = Color(0xFFE8F5E9);
  static const Color healthyBorder = Color(0xFFA5D6A7);
  
  /// Warning/Caution indicators
  static const Color warning = Color(0xFFF57C00);
  static const Color warningBg = Color(0xFFFFF3E0);
  static const Color warningBorder = Color(0xFFFFCC80);
  
  /// Information/Neutral
  static const Color info = Color(0xFF1976D2);
  static const Color infoBg = Color(0xFFE3F2FD);
  static const Color infoBorder = Color(0xFF90CAF9);

  // Data Visualization Colors
  
  /// Positive metrics (improvement, increase)
  static const Color positiveMetric = Color(0xFF4CAF50);
  
  /// Negative metrics (decline, decrease)
  static const Color negativeMetric = Color(0xFFF44336);
  
  /// Neutral/Stable metrics
  static const Color neutralMetric = Color(0xFF9E9E9E);

  // Specialty-specific Colors
  
  /// Cardiology
  static const Color cardiology = Color(0xFFE91E63);
  
  /// Neurology
  static const Color neurology = Color(0xFF9C27B0);
  
  /// Orthopedics
  static const Color orthopedics = Color(0xFF795548);
  
  /// Pediatrics
  static const Color pediatrics = Color(0xFFFF9800);
  
  /// General Medicine
  static const Color generalMedicine = Color(0xFF2196F3);

  // Additional Medical UI Colors
  
  /// Primary medical theme color
  static const Color medicalPrimary = Color(0xFF1976D2);
  
  /// Accent color 1 - for categories/types
  static const Color medicalAccent1 = Color(0xFF2196F3); // Blue
  
  /// Accent color 2 - for categories/types
  static const Color medicalAccent2 = Color(0xFF4CAF50); // Green
  
  /// Warning color for medical contexts
  static const Color medicalWarning = Color(0xFFFF9800); // Orange
  
  /// Error color for critical medical contexts
  static const Color statusError = Color(0xFFD32F2F); // Red

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
