import 'package:flutter/material.dart';
import 'package:saber/design_system/spacing.dart';
import 'package:saber/design_system/radius.dart';
import 'package:saber/design_system/colors.dart';
import 'package:saber/design_system/typography.dart';
import 'package:saber/design_system/animations.dart';

class StatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? trend;
  final bool isPositiveTrend;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.trend,
    this.isPositiveTrend = true,
    this.onTap,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.color ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) widget.onTap!();
      },
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(
          begin: 1.0,
          end: _isPressed ? AppAnimations.buttonPressScale : 1.0,
        ),
        duration: AppAnimations.buttonPress,
        curve: AppAnimations.buttonPressCurve,
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppRadius.xxlRadius,
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: AppRadius.xxlRadius,
              child: Stack(
                children: [
                  // Decorative background circles
                  Positioned(
                    right: -16,
                    top: -16,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: baseColor.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: baseColor.withOpacity(0.08),
                        shape: BoxShape.circle,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon Container
                            Container(
                              padding: EdgeInsets.all(AppSpacing.iconPadding),
                              decoration: BoxDecoration(
                                color: baseColor.withOpacity(0.1),
                                borderRadius: AppRadius.mdRadius,
                              ),
                              child: Icon(
                                widget.icon,
                                color: baseColor,
                                size: 20,
                              ),
                            ),

                            // Trend Pill
                            if (widget.trend != null)
                              Flexible(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.isPositiveTrend
                                        ? MedicalColors.positiveMetric
                                              .withOpacity(0.08)
                                        : MedicalColors.negativeMetric
                                              .withOpacity(0.08),
                                    borderRadius: AppRadius.pillRadius,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        widget.isPositiveTrend
                                            ? Icons.trending_up_rounded
                                            : Icons.trending_down_rounded,
                                        size: 14,
                                        color: widget.isPositiveTrend
                                            ? MedicalColors.positiveMetric
                                            : MedicalColors.negativeMetric,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        // Allow text to shrink
                                        child: Text(
                                          widget.trend!,
                                          style:
                                              AppTypography.labelSmall(
                                                context,
                                              ).copyWith(
                                                color: widget.isPositiveTrend
                                                    ? MedicalColors
                                                          .positiveMetric
                                                    : MedicalColors
                                                          .negativeMetric,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 10,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          widget.value,
                          style: AppTypography.dataValue(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: AppSpacing.xs + 2),
                        Text(
                          widget.label,
                          style: AppTypography.bodyMedium(context).copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
