import 'dart:math' as math;
import 'package:flutter/material.dart';

class GradientFlow extends StatefulWidget {
  final Widget? child;
  final List<Color>? colors;
  final Duration duration;

  const GradientFlow({
    super.key,
    this.child,
    this.colors,
    this.duration = const Duration(seconds: 10),
  });

  @override
  State<GradientFlow> createState() => _GradientFlowState();
}

class _GradientFlowState extends State<GradientFlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultColors = [
      const Color(0xFF00319C), // Dark Blue
      const Color(0xFF2796D5), // Medium Blue
      const Color(0xFF93D6F6), // Light Blue
      const Color(0xFF0050E6), // Primary Blue
    ];

    final colors = widget.colors ?? defaultColors;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _GradientFlowPainter(
            progress: _controller.value,
            colors: colors,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _GradientFlowPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _GradientFlowPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.fill;

    // Layer 1: Base shift (Slow background movement)
    final gradient1 = LinearGradient(
      begin: Alignment(
        -1.0 + math.sin(progress * math.pi) * 0.5,
        -1.0 + math.cos(progress * math.pi) * 0.5,
      ),
      end: Alignment(
        1.0 + math.cos(progress * math.pi) * 0.5,
        1.0 + math.sin(progress * math.pi) * 0.5,
      ),
      colors: [
        colors[0].withValues(alpha: 1.0),
        colors[1].withValues(alpha: 1.0),
        colors[2].withValues(alpha: 1.0),
      ],
      stops: const [0.0, 0.6, 1.0],
    );
    paint.shader = gradient1.createShader(rect);
    canvas.drawRect(rect, paint);

    // Layer 2: Directional "Liquid Light" flows (Moving from top-right towards bottom-left)
    for (int i = 0; i < 4; i++) {
      final layerProgress = (progress + (i * 0.25)) % 1.0;

      // Path logic: Top-rightish to Bottom-leftish
      final startX = size.width * (1.2 - i * 0.2);
      final startY = size.height * (-0.2 + i * 0.1);
      final endX = size.width * (-0.2 + i * 0.1);
      final endY = size.height * (1.2 - i * 0.2);

      final currentX = startX + (endX - startX) * layerProgress;
      final currentY = startY + (endY - startY) * layerProgress;

      final radius =
          size.shortestSide * (0.6 + 0.3 * math.sin(layerProgress * math.pi));

      // Radial gradient with sharp leading edge (asymmetric stops)
      final radialGradient = RadialGradient(
        center: Alignment(
          (currentX / size.width) * 2 - 1,
          (currentY / size.height) * 2 - 1,
        ),
        radius: radius / size.shortestSide,
        colors: [
          colors[3].withValues(alpha: 0.5), // Vibrant center
          colors[1].withValues(alpha: 0.2), // Mid tail
          colors[0].withValues(alpha: 0.0), // Fade out
        ],
        stops: const [0.0, 0.2, 1.0], // Sharper leading edge
      );

      paint.shader = radialGradient.createShader(rect);
      canvas.drawRect(rect, paint);
    }

    // Layer 3: Dynamic Highlights (sharp streaks)
    for (int j = 0; j < 2; j++) {
      final streakProgress = (progress * 2.0 + (j * 0.5)) % 1.0;
      final streakGradient = LinearGradient(
        begin: Alignment(1.5 - streakProgress * 3, -0.5),
        end: Alignment(1.0 - streakProgress * 3, 0.5),
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      );
      paint.shader = streakGradient.createShader(rect);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradientFlowPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.colors != colors;
  }
}
