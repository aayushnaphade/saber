import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/design_system/radius.dart';
import 'package:saber/design_system/spacing.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16), // Faster for visible liquid motion
    )..repeat(); // Standard repeat is now seamless because we use modulo math (sin/cos)
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

    // Extracted Logo Colors
    const blob1Color = Color(0xFF0A4D8B); // Navy
    const blob2Color = Color(0xFF50B9E8); // Sky
    const blob3Color = Color(0xFF0D9488); // Teal

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Organic fluid motion using non-linear math
        final t = _controller.value * 2 * math.pi;

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: AppRadius.xlRadius,
            border: Border.all(
              color: isDark
                  ? colorScheme.primary.withValues(alpha: 0.12)
                  : colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : colorScheme.primary).withValues(
                  alpha: 0.06,
                ),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Liquid Blobs - Oversized to ensure "whole card is filled"
              Positioned(
                top: -250 + 130 * math.sin(t * 0.4),
                left: -250 + 130 * math.cos(t * 0.4),
                child: _buildFluidBlob(blob1Color, isDark ? 0.5 : 0.2, 700),
              ),
              Positioned(
                bottom: -220 + 140 * math.cos(t * 0.5),
                right: -220 + 140 * math.sin(t * 0.5),
                child: _buildFluidBlob(blob2Color, isDark ? 0.4 : 0.25, 600),
              ),
              Positioned(
                top: 40 + 100 * math.sin(t * 0.6),
                right: -180 + 100 * math.cos(t * 0.6),
                child: _buildFluidBlob(blob3Color, isDark ? 0.35 : 0.22, 550),
              ),
              Positioned(
                bottom: 80 + 110 * math.cos(t * 0.3),
                left: -120 + 110 * math.sin(t * 0.3),
                child: _buildFluidBlob(blob2Color, isDark ? 0.3 : 0.18, 650),
              ),
              if (child != null) child,
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
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
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
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
                              color: colorScheme.primary.withValues(alpha: 0.4),
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
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
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
      backgroundColor = Colors.blue.withValues(alpha: 0.1);
      textColor = Colors.blue.shade700;
    } else if (lowerGender == 'female' || lowerGender == 'f') {
      backgroundColor = Colors.pink.withValues(alpha: 0.1);
      textColor = Colors.pink.shade700;
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurfaceVariant;
    }

    // Adjust for dark mode if needed
    if (theme.brightness == Brightness.dark) {
      if (lowerGender == 'male' || lowerGender == 'm') {
        backgroundColor = Colors.blue.withValues(alpha: 0.2);
        textColor = Colors.blue.shade200;
      } else if (lowerGender == 'female' || lowerGender == 'f') {
        backgroundColor = Colors.pink.withValues(alpha: 0.2);
        textColor = Colors.pink.shade200;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
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

  Widget _buildFluidBlob(Color color, double opacity, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
