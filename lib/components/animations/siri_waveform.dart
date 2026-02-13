import 'dart:math' as math;
import 'package:flutter/material.dart';

class SiriWaveform extends StatefulWidget {
  final List<Color>? colors;
  final Duration duration;
  final double frequency;
  final double amplitude;

  const SiriWaveform({
    super.key,
    this.colors,
    this.duration = const Duration(seconds: 3),
    this.frequency = 1.0,
    this.amplitude = 1.0,
  });

  @override
  State<SiriWaveform> createState() => _SiriWaveformState();
}

class _SiriWaveformState extends State<SiriWaveform>
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
    // Premium Siri-esque iridescent colors
    final siriColors =
        widget.colors ??
        [
          const Color(0xFF9300FF), // Purple
          const Color(0xFF00B2FF), // Blue
          const Color(0xFFFF00D6), // Pink
          const Color(0xFF00FFD1), // Cyan
        ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _SiriWaveformPainter(
            progress: _controller.value,
            colors: siriColors,
            amplitudeFactor: widget.amplitude,
            frequencyFactor: widget.frequency,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _SiriWaveformPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  final double amplitudeFactor;
  final double frequencyFactor;

  _SiriWaveformPainter({
    required this.progress,
    required this.colors,
    required this.amplitudeFactor,
    required this.frequencyFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final width = size.width;

    // Background glow
    final glowRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.8,
      height: size.height * 0.4,
    );
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[1].withValues(alpha: 0.15),
          colors[0].withValues(alpha: 0.0),
        ],
      ).createShader(glowRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawRect(glowRect, glowPaint);

    // Draw multiple overlapping waves
    for (int i = 0; i < 5; i++) {
      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 + (i * 0.5)
        ..strokeCap = StrokeCap.round;

      // Pulse factor to make it feel "alive"
      final pulse = 0.8 + 0.2 * math.sin(progress * 4 * math.pi + i);

      // Each wave has a different phase, frequency, and color
      final phaseOffset = (i * math.pi / 2.5);
      final frequency =
          (i.isEven ? 1.0 : 1.3) * 2.5 * math.pi / width * frequencyFactor;
      final waveProgress = (progress * 2 * math.pi);

      // Iridescent color shift
      final color = colors[i % colors.length].withValues(
        alpha: 0.4 + 0.2 * math.sin(waveProgress + i),
      );
      wavePaint.color = color;

      // Apply blur to some waves for a softer, liquid look
      if (i > 1) {
        wavePaint.maskFilter = MaskFilter.blur(BlurStyle.normal, (i + 1) * 2.0);
      }

      final path = Path();

      // Amplitude modulation: higher in the middle, lower at the edges (envelope)
      for (double x = 0; x <= width; x += 2) {
        // Sine wave formula: y = A * sin(wx + phase)
        // Envelope: reduces amplitude at edges (Gaussian-like or sine squared)
        final envelope = math.pow(math.sin(math.pi * x / width), 2);

        final y =
            centerY +
            (size.height * 0.15 * amplitudeFactor * pulse) *
                envelope *
                math.sin(x * frequency + waveProgress + phaseOffset);

        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SiriWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
