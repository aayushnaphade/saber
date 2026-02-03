import 'dart:math' as math;
import 'package:flutter/material.dart';

class SiriCircularWaveform extends StatefulWidget {
  final List<Color>? colors;
  final Duration duration;
  final double size;

  const SiriCircularWaveform({
    super.key,
    this.colors,
    this.duration = const Duration(seconds: 10),
    this.size = 200,
  });

  @override
  State<SiriCircularWaveform> createState() => _SiriCircularWaveformState();
}

class _SiriCircularWaveformState extends State<SiriCircularWaveform>
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
    final siriColors =
        widget.colors ??
        [
          const Color(0xFF00319C), // Deep Navy
          const Color(0xFF2796D5), // Medium Azure
          const Color(0xFF93D6F6), // Sky Blue
          const Color(0xFF0050E6), // Vibrant Cobalt
          const Color(0xFFFFFFFF), // White highlights
        ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _SiriCircularWaveformPainter(
            progress: _controller.value,
            colors: siriColors,
          ),
          size: Size(widget.size, widget.size),
        );
      },
    );
  }
}

class _SiriCircularWaveformPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _SiriCircularWaveformPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Base Layer: Deep Sphere Depth
    // We start with a dark periphery to create that "marble" depth
    final baseGradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        colors[1].withOpacity(0.8), // Inner transition
        colors[0].withOpacity(1.0), // Deep navy at edge
      ],
      stops: const [0.4, 1.0],
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = baseGradient.createShader(rect),
    );

    // 2. Animated Fluid internal spheres (Coherently Distinguished)
    // We draw 5 distinct blobs, each assigned a specific color from the brand palette
    for (int i = 0; i < 5; i++) {
      final layerProgress = (progress + (i * 0.2)) % 1.0;

      // Each sphere has a unique orbital path and speed
      final angle =
          (layerProgress * 2 * math.pi) * (i.isEven ? 1 : -1) +
          (i * math.pi / 2.5);
      final orbitalRadius =
          radius * (0.15 + 0.1 * math.sin(layerProgress * 3 * math.pi + i));

      final blobCenter =
          center +
          Offset(
            math.cos(angle) * orbitalRadius,
            math.sin(angle * 1.2) * orbitalRadius,
          );

      // Distinct pulse for each sphere
      final blobRadius =
          radius * (0.45 + 0.15 * math.cos(layerProgress * 2 * math.pi + i));

      // Use distinct brand colors for each "internal sphere"
      final color = colors[i % colors.length];

      final blobPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(0.55), // Vibrant center
            color.withOpacity(0.0), // Soft edge
          ],
          stops: const [0.2, 1.0],
        ).createShader(Rect.fromCircle(center: blobCenter, radius: blobRadius))
        ..blendMode = BlendMode.screen;

      canvas.drawCircle(blobCenter, blobRadius, blobPaint);
    }

    // 3. Central Core Glow (White focus)
    final coreGlow = RadialGradient(
      center: Alignment.center,
      radius: 0.4,
      colors: [
        Colors.white.withOpacity(0.85),
        colors[2].withOpacity(0.4), // Sky Blue aura
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 1.0],
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = coreGlow.createShader(rect),
    );

    // 4. Glass Surface Reflection (Top Highlight)
    // Subtle white crescent to sell the "glass ball" look
    // We'll just draw a simple soft spot for now to keep it elegant
    canvas.drawCircle(
      center + Offset(0, -radius * 0.4),
      radius * 0.3,
      Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.2),
    );

    // 5. Outer Rim Glow (The sharp cyan ring)
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..shader = SweepGradient(
        colors: [
          colors[2].withValues(alpha: 0.8), // Cyan/Sky Blue
          colors[3].withValues(alpha: 0.5), // Cobalt
          colors[2].withValues(alpha: 0.8),
        ],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(rect);

    // Soft outer glow for the rim
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..color = colors[2].withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, radius - 1, glowPaint);
    canvas.drawCircle(center, radius - 1, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _SiriCircularWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
