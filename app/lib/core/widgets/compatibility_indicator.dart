import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../design/design.dart';

/// 0-100 compatibility ring with the number inside (value is never colour-only).
class CompatibilityIndicator extends StatelessWidget {
  const CompatibilityIndicator({
    super.key,
    required this.score,
    this.size = 48,
    this.showLabel = false,
  });

  final int score;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    // The ring grows with the user's text scale so the number always fits (capped at 1.8x).
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
    final d = size * scale;
    final ring = SizedBox(
      width: d,
      height: d,
      child: CustomPaint(
        painter: _RingPainter(
          value: score / 100,
          track: c.divider,
          fill: c.primary,
          stroke: size * 0.11,
        ),
        child: Center(
          child: Text(
            '$score',
            textScaler: TextScaler.noScaling,
            style: context.text.titleMedium!.copyWith(
              fontSize: size * 0.36 * scale,
              height: 1,
            ),
          ),
        ),
      ),
    );
    return Semantics(
      label: l.compatibilityValue(score),
      container: true,
      excludeSemantics: true,
      child: showLabel
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ring,
                const SizedBox(width: AppSpace.s3),
                Flexible(
                  child: Text(
                    l.compatibilityLabel,
                    style: context.text.labelMedium,
                  ),
                ),
              ],
            )
          : ring,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.track,
    required this.fill,
    required this.stroke,
  });
  final double value;
  final Color track;
  final Color fill;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    base.color = fill;
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * value.clamp(0.0, 1.0),
      false,
      base,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.track != track ||
      old.fill != fill ||
      old.stroke != stroke;
}
