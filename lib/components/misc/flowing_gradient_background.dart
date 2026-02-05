import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart'; // Ensure it's exported or available

class FlowingGradientBackground extends StatefulWidget {
  const FlowingGradientBackground({super.key});

  @override
  State<FlowingGradientBackground> createState() =>
      _FlowingGradientBackgroundState();
}

class _FlowingGradientBackgroundState extends State<FlowingGradientBackground>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF01579B), // Fallback Deep Blue
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2 * pi;

          // Create liquid-like points that move in smooth, overlapping orbits
          final points = [
            MeshGradientPoint(
              position: Offset(0.5 + 0.35 * sin(t), 0.5 + 0.35 * cos(t * 0.7)),
              color: const Color(0xFF01579B), // Deep Blue
            ),
            MeshGradientPoint(
              position: Offset(
                0.5 + 0.4 * sin(t * 0.5 + 1),
                0.5 + 0.4 * cos(t * 0.8 + 2),
              ),
              color: const Color(0xFF0288D1), // Medium Blue
            ),
            MeshGradientPoint(
              position: Offset(
                0.5 + 0.3 * sin(t * 0.9 + 3),
                0.5 + 0.3 * cos(t * 0.4 + 4),
              ),
              color: const Color(0xFF81D4FA), // Light Blue
            ),
            MeshGradientPoint(
              position: Offset(
                0.5 + 0.45 * sin(t * 0.6 + 5),
                0.5 + 0.45 * cos(t * 0.9 + 6),
              ),
              color: const Color(0xFF00B8D4), // Cyan
            ),
          ];

          return SizedBox.expand(
            child: MeshGradient(
              points: points,
              options: MeshGradientOptions(
                blend: 4.0, // Higher blend for more liquid feel
                noiseIntensity: 0.1,
              ),
            ),
          );
        },
      ),
    );
  }
}
