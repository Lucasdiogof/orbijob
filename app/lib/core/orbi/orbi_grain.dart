import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/design.dart';

/// A fine static grain over a hero area. Painted once from a fixed seed (no asset, no shader, no animation), kept in its own
/// repaint layer, and at an alpha low enough that text over it keeps its contrast (see the contrast test). Meant for small,
/// non-scrolling surfaces (a hero, a sign-in backdrop), never behind a long list.
class OrbiGrain extends StatelessWidget {
  const OrbiGrain({super.key, this.density = 0.012});

  /// Grains per logical pixel of area; the total is capped.
  final double density;

  /// The most dots ever drawn, whatever the area.
  static const maxDots = 6000;

  /// Alpha of a single grain (dark theme).
  static const alpha = 0.05;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Dark theme only: in the light theme the secondary text over the hero glow is already at 4.7:1, so any grain would
    // take it under 4.5:1. Depth there comes from the glow and the lit surfaces.
    if (!c.isDark) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _GrainPainter(
              color: c.ink.withValues(alpha: alpha),
              density: density,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.color, required this.density});
  final Color color;
  final double density;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final n = math.min(
      OrbiGrain.maxDots,
      (size.width * size.height * density).round(),
    );
    final rnd = math.Random(7);
    final pts = Float32List(n * 2);
    for (var i = 0; i < n; i++) {
      pts[i * 2] = rnd.nextDouble() * size.width;
      pts[i * 2 + 1] = rnd.nextDouble() * size.height;
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      pts,
      Paint()
        ..color = color
        ..strokeWidth = 1
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.color != color || old.density != density;
}
