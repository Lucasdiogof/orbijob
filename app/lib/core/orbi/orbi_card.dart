import 'package:flutter/material.dart';

import '../design/design.dart';
import '../widgets/focus_ring.dart';

/// The one card surface of the product: a [surface] tile with a hairline edge, a generous radius and no shadow.
/// With [onTap] it is a single touch target with hover/pressed/focus states; with [selected] it takes the brand edge.
class OrbiCard extends StatelessWidget {
  const OrbiCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.s4),
    this.selected = false,
    this.color,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool selected;

  /// Overrides the surface colour (a tinted card, e.g. the profile summary).
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(
        color: selected ? c.cardBorderSelected : c.cardBorder,
        width: selected ? 1.5 : 1,
      ),
    );
    final body = Material(
      color: color ?? c.cardBg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              hoverColor: c.hoverLayer,
              highlightColor: c.pressedLayer,
              child: Padding(padding: padding, child: child),
            ),
    );
    final ringed = onTap == null
        ? body
        : FocusRing(radius: AppRadius.lg, child: body);
    return semanticLabel == null
        ? ringed
        : Semantics(container: true, label: semanticLabel, child: ringed);
  }
}
