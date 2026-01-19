import 'package:flutter/material.dart';
import 'package:saber/design_system/radius.dart';

/// A shimmer skeleton loader component for better perceived performance
/// Uses shimmer animation to indicate loading state while preserving layout
class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  /// Creates a circular skeleton loader (e.g., for avatars)
  const SkeletonLoader.circle({
    super.key,
    required double size,
  }) : width = size,
       height = size,
       borderRadius = null,
       shape = BoxShape.circle;

  /// Creates a rectangular skeleton with rounded corners
  factory SkeletonLoader.rounded({
    Key? key,
    double? width,
    double? height,
    double radius = 12.0,
  }) {
    return SkeletonLoader(
      key: key,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Skeleton colors based on theme
    final baseColor = isDark 
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerHigh;
    final highlightColor = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surface;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle 
                ? null 
                : widget.borderRadius ?? AppRadius.mdRadius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                0.0,
                _animation.value.clamp(0.0, 1.0),
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton loader for text lines
class SkeletonText extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonText({
    super.key,
    this.width = double.infinity,
    this.height = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(height / 2),
    );
  }
}

/// Skeleton loader for list items
class SkeletonListTile extends StatelessWidget {
  final bool hasLeading;
  final bool hasTrailing;
  final int lineCount;

  const SkeletonListTile({
    super.key,
    this.hasLeading = true,
    this.hasTrailing = false,
    this.lineCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasLeading) ...[
            const SkeletonLoader.circle(size: 48),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonText(width: 120, height: 16),
                const SizedBox(height: 8),
                ...List.generate(
                  lineCount - 1,
                  (index) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SkeletonText(
                      width: index == lineCount - 2 ? 80 : double.infinity,
                      height: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasTrailing) ...[
            const SizedBox(width: 16),
            const SkeletonLoader(width: 60, height: 32),
          ],
        ],
      ),
    );
  }
}

/// Skeleton loader for cards
class SkeletonCard extends StatelessWidget {
  final double? width;
  final double? height;
  final bool hasHeader;

  const SkeletonCard({
    super.key,
    this.width,
    this.height = 200,
    this.hasHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      width: width,
      height: height,
      borderRadius: AppRadius.lgRadius,
    );
  }
}
