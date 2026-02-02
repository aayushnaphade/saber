import 'package:flutter/material.dart';

import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/design_system/spacing.dart';
import 'package:saber/design_system/radius.dart';

class LiveQueueCard extends StatefulWidget {
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

  @override
  State<LiveQueueCard> createState() => _LiveQueueCardState();
}

class _LiveQueueCardState extends State<LiveQueueCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Alignment> _topAlignmentAnimation;
  late Animation<Alignment> _bottomAlignmentAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _topAlignmentAnimation = Tween<Alignment>(
      begin: Alignment.topLeft,
      end: Alignment.topRight,
    ).animate(_controller);

    _bottomAlignmentAnimation = Tween<Alignment>(
      begin: Alignment.bottomRight,
      end: Alignment.bottomLeft,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Calculate safe waiting count (excluding current patient if in progress)
  int get _displayWaitingCount {
    if (widget.currentPatient == null) return 0;
    return widget.waitingCount > 0 ? widget.waitingCount : 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Define flowing gradient colors based on theme/logo
    // Using opacity to keep it subtle but visible
    // Brand Colors: #0A4D8B (Deep Blue) and #50B9E8 (Bright Blue)
    final gradientColors = isDark
        ? [
            colorScheme.surface,
            const Color(0xFF0A4D8B).withOpacity(0.3), // Deep Brand Blue
            const Color(0xFF50B9E8).withOpacity(0.2), // Bright Accent
          ]
        : [
            colorScheme.surface,
            const Color(0xFFE0F2FE), // Lightest Blue (primary-100)
            const Color(0xFFBAE6FD), // Lighter Blue (primary-200)
          ];
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            gradient: LinearGradient(
              begin: _topAlignmentAnimation.value,
              end: _bottomAlignmentAnimation.value,
              colors: gradientColors,
            ),
            borderRadius: AppRadius.xlRadius,
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    color: colorScheme.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.4),
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
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$_displayWaitingCount Waiting',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (widget.currentPatient != null) ...[
              Text(
                widget.currentPatient!.status.toLowerCase() == 'in consultation'
                    ? 'Active Session'
                    : 'Next Patient',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                widget.currentPatient!.patientName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${widget.currentPatient!.age} yrs',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildGenderTag(widget.currentPatient!.gender, theme),
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.currentPatient!.status,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onStartSession,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        widget.currentPatient!.status.toLowerCase() ==
                                'in consultation'
                            ? 'Continue Session'
                            : 'Start Session',
                      ),
                    ),
                  ),
                  if (widget.onViewProfile != null) ...[
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: widget.onViewProfile,
                      icon: const Icon(Icons.person_outline),
                      tooltip: 'View Patient Profile',
                    ),
                  ],
                  if (widget.onCancel != null) ...[
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Cancel Appointment'),
                            content: Text(
                              'Are you sure you want to cancel the appointment for ${widget.currentPatient!.patientName}?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('No'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onCancel!();
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: colorScheme.error,
                                  foregroundColor: colorScheme.onError,
                                ),
                                child: const Text('Yes, Cancel'),
                              ),
                            ],
                          ),
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.errorContainer,
                        foregroundColor: colorScheme.error,
                      ),
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel Appointment',
                    ),
                  ],
                ],
              ),
            ] else
              Container(
                height: 200,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All Caught Up!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderTag(String gender, ThemeData theme) {
    final lowerGender = gender.toLowerCase().trim();
    Color backgroundColor;
    Color textColor;

    if (lowerGender == 'male' || lowerGender == 'm') {
      backgroundColor = Colors.blue.withOpacity(0.1);
      textColor = Colors.blue.shade700;
    } else if (lowerGender == 'female' || lowerGender == 'f') {
      backgroundColor = Colors.pink.withOpacity(0.1);
      textColor = Colors.pink.shade700;
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurfaceVariant;
    }

    // Adjust for dark mode if needed
    if (theme.brightness == Brightness.dark) {
      if (lowerGender == 'male' || lowerGender == 'm') {
        backgroundColor = Colors.blue.withOpacity(0.2);
        textColor = Colors.blue.shade200;
      } else if (lowerGender == 'female' || lowerGender == 'f') {
        backgroundColor = Colors.pink.withOpacity(0.2);
        textColor = Colors.pink.shade200;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withOpacity(0.2)),
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
