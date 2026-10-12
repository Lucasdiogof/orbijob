import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design.dart';

/// The OrbiJob loader: the brand symbol (two opposing arcs around a central point) set in motion.
/// The arcs turn slowly in opposite directions and the core breathes. With "reduce motion" the same composition is drawn still.
/// Pure vector (CustomPainter), no asset, light and dark through the theme tokens.
class OrbiLoadingIndicator extends StatefulWidget {
  const OrbiLoadingIndicator({
    super.key,
    this.size = 40,
    this.color,
    this.semanticLabel,
  });

  final double size;

  /// Defaults to the theme's loading colour.
  final Color? color;

  /// Announced by screen readers; omit when a parent already labels the busy state.
  final String? semanticLabel;

  @override
  State<OrbiLoadingIndicator> createState() => _OrbiLoadingIndicatorState();
}

class _OrbiLoadingIndicatorState extends State<OrbiLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    if (_reduce) {
      _ctl.stop();
    } else if (!_ctl.isAnimating) {
      _ctl.repeat();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.colors.loading;
    final painter = AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: OrbiOrbitPainter(
          progress: _reduce ? 0.12 : _ctl.value,
          color: color,
        ),
      ),
    );
    final box = SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(child: painter),
    );
    return widget.semanticLabel == null
        ? ExcludeSemantics(child: box)
        : Semantics(
            label: widget.semanticLabel,
            liveRegion: true,
            child: ExcludeSemantics(child: box),
          );
  }
}

/// Draws the orbit composition. [progress] in 0..1 is one full turn of the outer arc.
class OrbiOrbitPainter extends CustomPainter {
  const OrbiOrbitPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final stroke = math.max(1.6, size.shortestSide / 13);
    final ringR = r - stroke;
    final turn = progress * 2 * math.pi;
    final ring = Rect.fromCircle(center: c, radius: ringR);

    // faint orbit track
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.5
        ..color = color.withValues(alpha: 0.14),
    );
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = color;
    // two opposing arcs, turning in opposite directions (the brand symbol)
    canvas.drawArc(ring, turn - math.pi / 2, math.pi * 0.62, false, arc);
    canvas.drawArc(
      ring.deflate(stroke * 1.9),
      -turn * 1.35 + math.pi / 2,
      math.pi * 0.62,
      false,
      arc..color = color.withValues(alpha: 0.55),
    );
    // satellite on the outer orbit
    final sat = c + Offset(math.cos(turn), math.sin(turn)) * ringR;
    canvas.drawCircle(sat, stroke * 0.7, Paint()..color = color);
    // the breathing core
    final pulse = 0.5 + 0.5 * math.sin(progress * 2 * math.pi * 2);
    canvas.drawCircle(
      c,
      stroke * (1.15 + 0.35 * pulse),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(OrbiOrbitPainter old) =>
      old.progress != progress || old.color != color;
}

/// Centred loader with an optional line of text, for a whole page or panel that is waiting.
class OrbiLoadingView extends StatelessWidget {
  const OrbiLoadingView({super.key, this.label, this.size = 48});

  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OrbiLoadingIndicator(size: size),
          if (label != null) ...[
            const SizedBox(height: AppSpace.s3),
            Text(label!, style: context.metadataStyle),
          ],
        ],
      ),
    ),
  );
}
