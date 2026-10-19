import 'package:flutter/material.dart';

import '../design/design.dart';

/// Ambient light behind a hero area: a soft brand glow in the top corner and two thin orbit lines that echo the logo ring.
/// Painted once and never animated (a repaint boundary keeps it out of the list's scrolling work); it carries no information.
class OrbitBackdrop extends StatelessWidget {
  const OrbitBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _OrbitPainter(glow: c.heroGlow, line: c.orbitLine),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.glow, required this.line});
  final RadialGradient glow;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = glow.createShader(rect));
    final centre = Offset(size.width * 0.92, size.height * 0.1);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [line, line.withValues(alpha: 0)],
        stops: const [0.2, 0.95],
      ).createShader(rect);
    canvas.save();
    canvas.clipRect(rect);
    for (final r in [size.shortestSide * 0.42, size.shortestSide * 0.66]) {
      canvas.drawCircle(centre, r, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.glow != glow || old.line != line;
}
