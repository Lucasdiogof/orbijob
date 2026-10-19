import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design.dart';
import '../motion/motion.dart';

/// A discreet brand composition for empty and gated states: an icon tile at the centre of two concentric orbits,
/// with a small satellite. Static vector art (CustomPainter), drawn from the theme tokens.
class OrbiArt extends StatelessWidget {
  const OrbiArt({
    super.key,
    required this.icon,
    this.size = 112,
    this.error = false,
  });

  final IconData icon;
  final double size;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = error ? c.error : c.primary;
    final tile = size * 0.5;
    return ExcludeSemantics(
      child: _ArtEntrance(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _OrbitsPainter(color: accent),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: error ? c.errorContainer : c.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  // Lit from above like the cards, with a soft halo of the accent behind the tile.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(
                        error ? c.errorContainer : c.primaryContainer,
                        c.ink,
                        c.isDark ? 0.08 : 0.0,
                      )!,
                      error ? c.errorContainer : c.primaryContainer,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: c.isDark ? 0.22 : 0.16),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: SizedBox.square(
                  dimension: tile,
                  child: Icon(
                    icon,
                    size: tile * 0.52,
                    color: error ? c.onErrorContainer : c.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The art settles in once (fade and a small scale); static with reduced motion.
class _ArtEntrance extends StatelessWidget {
  const _ArtEntrance({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.scale(scale: 0.92 + 0.08 * v, child: child),
      ),
      child: child,
    );
  }
}

class _OrbitsPainter extends CustomPainter {
  const _OrbitsPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.22);
    canvas.drawCircle(c, r - 1, line);
    canvas.drawCircle(c, r * 0.74, line..color = color.withValues(alpha: 0.14));
    final dot = Paint()..color = color;
    canvas.drawCircle(
      c + Offset(math.cos(-0.9), math.sin(-0.9)) * (r - 1),
      4.5,
      dot,
    );
    canvas.drawCircle(
      c + Offset(math.cos(2.4), math.sin(2.4)) * (r * 0.74),
      3,
      dot..color = color.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_OrbitsPainter old) => old.color != color;
}
