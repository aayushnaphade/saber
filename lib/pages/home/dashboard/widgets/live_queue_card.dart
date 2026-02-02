import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/design_system/spacing.dart';
import 'package:saber/design_system/radius.dart';

class LiveQueueCard extends StatelessWidget {
  final QueueItem? currentPatient;
  final int waitingCount;
  final VoidCallback onStartSession;
  final VoidCallback? onCancel;
  final VoidCallback? onViewProfile;

  const LiveQueueCard({
    super.key,
    this.currentPatient,
    required this.waitingCount,
    required this.onStartSession,
    this.onCancel,
    this.onViewProfile,
  });

  /// Calculate safe waiting count (excluding current patient if in progress)
  int get _displayWaitingCount {
    if (currentPatient == null) return 0;
    return waitingCount > 0 ? waitingCount : 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.xlRadius),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF0B1120), // Very dark blue/slate
                          const Color(0xFF1E1B4B), // Indigo 950
                        ]
                      : [
                          Colors.indigo.shade900,
                          Colors.deepPurple.shade900,
                        ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white24,
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'LIVE QUEUE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$_displayWaitingCount Waiting',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (currentPatient != null) ...[
                  Text(
                    currentPatient!.status.toLowerCase() == 'in consultation' 
                        ? 'Active Session' 
                        : 'Next Patient',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentPatient!.patientName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${currentPatient!.age} yrs',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildGenderTag(currentPatient!.gender, theme),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentPatient!.status,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onStartSession,
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.white,
                            foregroundColor: isDark
                                ? Colors.white
                                : theme.colorScheme.primary,
                            padding: const EdgeInsets.all(16),
                            elevation: 0,
                            side: isDark
                                ? BorderSide(
                                    color: Colors.white.withOpacity(0.2))
                                : BorderSide.none,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            currentPatient!.status.toLowerCase() == 'in consultation'
                                ? 'Continue Session'
                                : 'Start Session',
                          ),
                        ),
                      ),
                      if (onViewProfile != null) ...[
                        const SizedBox(width: 12),
                        IconButton.filled(
                          onPressed: onViewProfile,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.2)),
                          ),
                          icon: const Icon(Icons.person_outline),
                          tooltip: 'View Patient Profile',
                        ),
                      ],
                      if (onCancel != null) ...[
                        const SizedBox(width: 12),
                        IconButton.filled(
                          onPressed: onCancel,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.2)),
                          ),
                          icon: const Icon(Icons.close),
                          tooltip: 'Cancel Appointment',
                        ),
                      ],
                    ],
                  ),
                ] else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'All Caught Up!',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderTag(String gender, ThemeData theme) {
    final lowerGender = gender.toLowerCase().trim();
    Color backgroundColor;
    Color textColor;

    if (lowerGender == 'male' || lowerGender == 'm') {
      backgroundColor = Colors.blue.withOpacity(0.2);
      textColor = Colors.blue.shade100;
    } else if (lowerGender == 'female' || lowerGender == 'f') {
      backgroundColor = Colors.pink.withOpacity(0.2);
      textColor = Colors.pink.shade100;
    } else {
      backgroundColor = Colors.white.withOpacity(0.2);
      textColor = Colors.white.withOpacity(0.9);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: textColor.withOpacity(0.3),
        ),
      ),
      child: Text(
        gender,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
