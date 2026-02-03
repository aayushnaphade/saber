import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class EtherealBackground extends StatefulWidget {
  const EtherealBackground({super.key});

  @override
  State<EtherealBackground> createState() => _EtherealBackgroundState();
}

class _EtherealBackgroundState extends State<EtherealBackground>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Base Dynamic Gradient Layer
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // slate-900 equivalent
                  Color(0xFF001220), // deep blue/black
                  Color(0xFF042F2E), // teal-950 equivalent
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Animated Blobs
        _buildBlob(
          color: const Color(0xFF0D9488).withValues(alpha: 0.35), // Teal
          size: size.width * 0.8,
          initialOffset: const Offset(0.8, -0.1),
          animationOffset: 0.0,
        ),
        _buildBlob(
          color: const Color(0xFF1D4ED8).withValues(alpha: 0.35), // Blue
          size: size.width * 0.9,
          initialOffset: const Offset(-0.2, 0.8),
          animationOffset: 2.0,
        ),
        _buildBlob(
          color: const Color(0xFF06B6D4).withValues(alpha: 0.25), // Cyan
          size: size.width * 0.6,
          initialOffset: const Offset(0.3, 0.3),
          animationOffset: 4.0,
        ),

        // Noise Overlay mimic (very subtle semi-transparent black overlay)
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ],
    );
  }

  Widget _buildBlob({
    required Color color,
    required double size,
    required Offset initialOffset,
    required double animationOffset,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = (_controller.value * 2 * pi) + animationOffset;
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        final dx = initialOffset.dx * screenWidth + sin(phase) * 60;
        final dy = initialOffset.dy * screenHeight + cos(phase) * 60;

        return Positioned(
          left: dx - size / 2,
          top: dy - size / 2,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
        );
      },
    );
  }
}
