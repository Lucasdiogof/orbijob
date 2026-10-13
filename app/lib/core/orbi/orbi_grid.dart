import 'package:flutter/material.dart';

import '../design/design.dart';

/// Lays [children] out in one column on phones and in two (three when very wide) on tablets and desktops, so cards keep a
/// readable width instead of stretching across the window. Children keep their natural height.
class OrbiAdaptiveGrid extends StatelessWidget {
  const OrbiAdaptiveGrid({
    super.key,
    required this.children,
    this.minColumnWidth = 340,
    this.maxColumns = 3,
    this.gap = AppSpace.s3,
  });

  final List<Widget> children;
  final double minColumnWidth;
  final int maxColumns;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final fit = ((box.maxWidth + gap) / (minColumnWidth + gap)).floor();
      final columns = fit.clamp(1, maxColumns);
      if (columns == 1) {
        return Column(
          children: [
            for (final c in children) ...[c, SizedBox(height: gap)],
          ],
        );
      }
      final w = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    },
  );
}
