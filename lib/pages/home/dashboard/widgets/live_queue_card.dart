import 'dart:math' as math;

/**
 * 🔒 VISUAL INTEGRITY GUARD: 
 * This widget contains premium Mesh Gradient animations (Apple-style).
 * DO NOT modify the background logic, MeshGradientPoints, or blend values
 * without explicit designer approval. This component is part of the 
 * SynapseAI Core Design Language.
 */

import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:saber/data/models/dashboard_models.dart';
import 'package:saber/data/session_manager.dart';
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
      duration: const Duration(
        seconds: 60,
      ), // Much longer loop to avoid repetition
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showCancelConfirmation(BuildContext context) {
    if (widget.currentPatient == null) return;

    final theme = Theme.of(context);
    final isInProgress = widget.currentPatient!.status == 'in_progress';
    final patientName = widget.currentPatient!.patientName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isInProgress ? 'Terminate Session' : 'Cancel Appointment'),
        content: Text(
          isInProgress
              ? 'Are you sure you want to terminate the current session with $patientName?'
              : 'Are you sure you want to cancel the appointment for $patientName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.onCancel?.call();
            },
            child: Text(isInProgress ? 'Terminate' : 'Cancel'),
          ),
        ],
      ),
    );
  }

  int get _displayWaitingCount {
    if (widget.currentPatient == null) return 0;
    return widget.waitingCount > 0 ? widget.waitingCount : 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Extracted Logo Colors from tailwind.config.ts
    // Deep Blue: #0A4D8B, Sky: #50B9E8, Success: #10B981
    final colors = [
      const Color(0xFF0A4D8B), // Navy
      const Color(0xFF50B9E8), // Sky
      const Color(0xFF10B981), // Emerald/Teal
      const Color(0xFF0D9488), // Deep Teal
      if (isDark) Colors.black87 else Colors.white, // Blending base
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;

        // Apple-style mesh points: Organic, overlapping orbits
        // Multipliers adjusted for 60s duration to maintain speed (approx 3x original coefficients)
        final meshPoints = [
          MeshGradientPoint(
            position: Offset(
              0.5 + 0.45 * math.sin(t * 0.6),
              0.5 + 0.35 * math.cos(t * 0.45),
            ),
            color: colors[0].withValues(alpha: 0.8),
          ),
          MeshGradientPoint(
            position: Offset(
              0.5 + 0.5 * math.sin(t * 1.05 + 1),
              0.3 + 0.4 * math.cos(t * 1.2 + 2),
            ),
            color: colors[1].withValues(alpha: 0.7),
          ),
          MeshGradientPoint(
            position: Offset(
              0.2 + 0.4 * math.sin(t * 0.75 + math.pi),
              0.7 + 0.3 * math.cos(t * 0.9 + 4),
            ),
            color: colors[2].withValues(alpha: 0.6),
          ),
          MeshGradientPoint(
            position: Offset(
              0.8 + 0.3 * math.sin(t * 1.35 + 5),
              0.9 + 0.2 * math.cos(t * 0.6 + 6),
            ),
            color: colors[3].withValues(alpha: 0.5),
          ),
          MeshGradientPoint(
            position: Offset(
              0.5 + 0.2 * math.sin(t * 2.4),
              0.5 + 0.2 * math.cos(t * 2.1),
            ),
            color: colors[4],
          ),
        ];

        final canHero = !SessionManager().hasActiveSession;

        Widget cardDecoration = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.xlRadius,
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : colorScheme.primary).withValues(
                  alpha: 0.08,
                ),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.xlRadius,
            child: Stack(
              children: [
                // 1. Base Mesh Gradient
                Positioned.fill(
                  child: MeshGradient(
                    points: meshPoints,
                    options: MeshGradientOptions(
                      blend: 4.5, // High blend for smooth mixing
                      noiseIntensity: 0.08, // Subtle film grain feel
                    ),
                  ),
                ),

                // 2. Faint Layer for extra smoothness (Glass effect)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black12 : Colors.white10),
                    ),
                  ),
                ),

                // 3. The Actual Content
                child!,
              ],
            ),
          ),
        );

        if (canHero) {
          return Hero(tag: 'active_session', child: cardDecoration);
        }

        return cardDecoration;
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.xlRadius,
          border: Border.all(
            color: isDark
                ? colorScheme.primary.withValues(alpha: 0.15)
                : colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
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
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
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
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Live Queue',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_displayWaitingCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.onSurface.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_alt_rounded,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_displayWaitingCount Waiting',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (widget.currentPatient != null) ...[
              Text(
                'Current Patient',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      widget.currentPatient!.patientName.isNotEmpty
                          ? widget.currentPatient!.patientName[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentPatient!.patientName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18, // Slightly reduced to avoid overflow
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.currentPatient!.status == 'in_progress')
                          Text(
                            'Session in Progress',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          Text(
                            'Next in line',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Use Wrap to handle button overflows gracefully on small screens
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: (MediaQuery.of(context).size.width < 400)
                        ? double.infinity
                        : 200,
                    child: FilledButton.icon(
                      onPressed: widget.onStartSession,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        widget.currentPatient!.status == 'in_progress'
                            ? 'Continue Session'
                            : 'Start Session',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  if (widget.onViewProfile != null)
                    OutlinedButton(
                      onPressed: widget.onViewProfile,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        minimumSize: const Size(56, 56),
                      ),
                      child: const Icon(Icons.person_outline),
                    ),
                  if (widget.onCancel != null)
                    OutlinedButton(
                      onPressed: () => _showCancelConfirmation(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        minimumSize: const Size(56, 56),
                        foregroundColor: colorScheme.error,
                        side: BorderSide(
                          color: colorScheme.error.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 32),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.coffee_outlined,
                      size: 48,
                      color: colorScheme.outline.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No patients in queue',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }
}
