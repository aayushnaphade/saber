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
        return Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.xlRadius,
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
          child: ClipRRect(
            borderRadius: AppRadius.xlRadius,
            child: CustomPaint(
              painter: _FluidBlobPainter(
                animation: _controller,
                blob1Color: blob1Color,
                blob2Color: blob2Color,
                blob3Color: blob3Color,
                isDark: isDark,
                surfaceColor: colorScheme.surface,
              ),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.xlRadius,
          border: Border.all(
            color: isDark
                ? colorScheme.primary.withValues(alpha: 0.12)
                : colorScheme.outlineVariant.withValues(alpha: 0.35),
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
                      color: colorScheme.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.onSurface.withValues(alpha: 0.1),
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
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onStartSession,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        widget.currentPatient!.status == 'in_progress'
                            ? 'Continue Session'
                            : 'Start Session',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  if (widget.onViewProfile != null) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: widget.onViewProfile,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Icon(Icons.person_outline),
                    ),
                  ],
                  if (widget.onCancel != null) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => _showCancelConfirmation(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: colorScheme.error,
                        side: BorderSide(
                          color: colorScheme.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Icon(Icons.close_rounded),
                    ),
                  ],
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

class _FluidBlobPainter extends CustomPainter {
  final Animation<double> animation;
  final Color blob1Color;
  final Color blob2Color;
  final Color blob3Color;
  final bool isDark;
  final Color surfaceColor;

  _FluidBlobPainter({
    required this.animation,
    required this.blob1Color,
    required this.blob2Color,
    required this.blob3Color,
    required this.isDark,
    required this.surfaceColor,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background
    final bgPaint = Paint()..color = surfaceColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final t = animation.value * 2 * math.pi;

    // Draw blobs with INCREASED opacity
    _drawBlob(
      canvas,
      dx: -250 + 130 * math.cos(t * 0.4),
      dy: -250 + 130 * math.sin(t * 0.4),
      color: blob1Color,
      opacity: isDark ? 0.65 : 0.35, // Increased from 0.5/0.2
      radius: 350,
    );

    _drawBlob(
      canvas,
      dx: size.width - 100 + 130 * math.sin(t * 0.5),
      dy: size.height - 100 + 130 * math.cos(t * 0.5),
      color: blob2Color,
      opacity: isDark ? 0.55 : 0.4, // Increased from 0.4/0.25
      radius: 300,
    );

    _drawBlob(
      canvas,
      dx: size.width - 100 + 100 * math.cos(t * 0.6),
      dy: -50 + 100 * math.sin(t * 0.6),
      color: blob3Color,
      opacity: isDark ? 0.5 : 0.35, // Increased from 0.35/0.22
      radius: 275,
    );

    _drawBlob(
      canvas,
      dx: -50 + 110 * math.sin(t * 0.3),
      dy: size.height - 50 + 110 * math.cos(t * 0.3),
      color: blob2Color,
      opacity: isDark ? 0.45 : 0.3, // Increased from 0.3/0.18
      radius: 325,
    );
  }

  void _drawBlob(
    Canvas canvas, {
    required double dx,
    required double dy,
    required Color color,
    required double opacity,
    required double radius,
  }) {
    final center = Offset(dx, dy); // Center of the blob
    // Correct radial gradient center logic:
    // The previous implementation used a Container(width, height) with RadialGradient.
    // The gradient center is usually the center of that container.
    // Here we draw a circle at certain offset.

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _FluidBlobPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.surfaceColor != surfaceColor;
  }
}
