import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design.dart';

/// The OrbiJob loader: the brand symbol itself (two opposing arcs on one ring around a violet core) set in motion.
/// Each cycle the ring makes a half turn with an eased start and stop (the symbol looks identical at both ends, so the loop
/// has no seam), the arcs breathe slightly shorter in the middle of the turn, and the core pulses with a soft ripple.
/// With "reduce motion" the exact logo is drawn still. Pure vector (CustomPainter): no asset, light and dark through tokens.
///
/// By default the arcs use the ink colour and the core the primary colour (as in the logo). Passing [color] draws everything
/// in that single colour (buttons, where the text colour must win).
class OrbiLoadingIndicator extends StatefulWidget {
  const OrbiLoadingIndicator({
    super.key,
    this.size = 40,
    this.color,
    this.semanticLabel,
  });

  final double size;

  /// A single colour for the whole mark; null uses the brand colours.
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
    duration: const Duration(milliseconds: 1500),
  );
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    if (_reduce) {
      _ctl.stop();
      _ctl.value = 0;
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
    final colors = context.colors;
    final arcs = widget.color ?? colors.ink;
    final core = widget.color ?? colors.primary;
    final painter = AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: OrbiOrbitPainter(
          progress: _reduce ? 0 : _ctl.value,
          color: arcs,
          coreColor: core,
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

/// Draws the brand symbol (viewBox 84x84: ring radius 31, stroke 13, core radius 9, arcs of 162 degrees starting at -36 and 144).
/// [progress] in 0..1 is one cycle; at 0 (and 1) the picture is exactly the logo.
class OrbiOrbitPainter extends CustomPainter {
  const OrbiOrbitPainter({
    required this.progress,
    required this.color,
    Color? coreColor,
    this.ripple = true,
    this.shorten = true,
  }) : coreColor = coreColor ?? color;

  final double progress;
  final Color color;
  final Color coreColor;

  /// The soft ring that grows from the core (off for the launch hand-over, which should look like the plain logo).
  final bool ripple;
  final bool shorten;

  static const _baseSweep = 162 * math.pi / 180;
  static const _baseStart = -36 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 84;
    final c = size.center(Offset.zero);
    final ringR = 31 * k;
    final stroke = 13 * k;
    final t = progress.clamp(0.0, 1.0);
    // eased half turn, and arcs breathing 25% shorter at the middle of it
    final eased = Curves.easeInOutCubic.transform(t);
    final turn = eased * math.pi;
    final sweep =
        _baseSweep * (1 - (shorten ? 0.25 : 0) * math.sin(math.pi * t));
    // keep the arcs centred on the same bisector while they shorten
    final shrink = (_baseSweep - sweep) / 2;
    final ring = Rect.fromCircle(center: c, radius: ringR);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..color = color;
    for (final base in [_baseStart, _baseStart + math.pi]) {
      canvas.drawArc(ring, base + turn + shrink, sweep, false, arc);
    }
    // the core: a soft ripple that grows and fades, then the core itself pulsing a little
    if (ripple) {
      final r = Curves.easeOut.transform(t);
      canvas.drawCircle(
        c,
        (9 + 14 * r) * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * k
          ..color = coreColor.withValues(alpha: 0.35 * (1 - r)),
      );
    }
    final pulse = ripple ? 1 + 0.12 * math.sin(math.pi * t) : 1.0;
    canvas.drawCircle(c, 9 * k * pulse, Paint()..color = coreColor);
  }

  @override
  bool shouldRepaint(OrbiOrbitPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.coreColor != coreColor ||
      old.ripple != ripple;
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
