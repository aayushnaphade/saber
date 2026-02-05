import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';

class MeshOrb extends StatefulWidget {
  final double size;
  final List<Color> colors;
  final Duration duration;

  const MeshOrb({
    super.key,
    this.size = 300,
    required this.colors,
    this.duration = const Duration(seconds: 10),
  });

  @override
  State<MeshOrb> createState() => _MeshOrbState();
}

class _MeshOrbState extends State<MeshOrb> with SingleTickerProviderStateMixin {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;

        // Siri-style points: Internal motion focused around the center
        // to create a "thinking/processing" feel
        final meshPoints = [
          // Center core
          MeshGradientPoint(
            position: Offset(
              0.5 + 0.15 * math.sin(t * 1.5),
              0.5 + 0.15 * math.cos(t * 1.2),
            ),
            color: widget.colors[0].withValues(alpha: 0.9),
          ),
          // Rotating outer points
          MeshGradientPoint(
            position: Offset(
              0.5 + 0.35 * math.sin(t * 0.8 + 1),
              0.5 + 0.35 * math.cos(t * 0.9 + 2),
            ),
            color: widget.colors[1].withValues(alpha: 0.8),
          ),
          MeshGradientPoint(
            position: Offset(
              0.5 + 0.4 * math.sin(t * 1.1 + 3),
              0.5 + 0.4 * math.cos(t * 0.7 + 4),
            ),
            color: widget.colors[2].withValues(alpha: 0.7),
          ),
          MeshGradientPoint(
            position: Offset(
              0.5 + 0.3 * math.sin(t * 1.4 + 5),
              0.5 + 0.3 * math.cos(t * 1.6 + 6),
            ),
            color: widget.colors[3].withValues(alpha: 0.6),
          ),
          // Bright Highlight
          MeshGradientPoint(
            position: Offset(
              0.5 + 0.25 * math.sin(t * 2.0),
              0.5 + 0.25 * math.cos(t * 2.2),
            ),
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ];

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // Inner Glow
              BoxShadow(
                color: widget.colors[1].withValues(alpha: 0.4),
                blurRadius: widget.size * 0.3,
                spreadRadius: -widget.size * 0.05,
              ),
              // Outer Aura
              BoxShadow(
                color: widget.colors[2].withValues(alpha: 0.2),
                blurRadius: widget.size * 0.6,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              children: [
                // 1. Mesh Gradient Background
                Positioned.fill(
                  child: MeshGradient(
                    points: meshPoints,
                    options: MeshGradientOptions(
                      blend: 5.0, // Maximum blend for liquid effect
                      noiseIntensity: 0.1,
                    ),
                  ),
                ),

                // 2. Glass Shine
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        radius: 0.6,
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Subtle outer rim light
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
