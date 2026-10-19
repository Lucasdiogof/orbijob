import 'package:flutter/material.dart';

import '../design/design.dart';
import '../motion/motion.dart';
import '../widgets/focus_ring.dart';

/// The one card surface of the product: a [surface] tile lit from above, with a hairline edge, a generous radius and, in light mode, a quiet lift.
/// With [onTap] it is a single touch target with hover/pressed/focus states and a small press; with [selected] it takes the brand edge.
class OrbiCard extends StatefulWidget {
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
  State<OrbiCard> createState() => _OrbiCardState();
}

class _OrbiCardState extends State<OrbiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tappable = widget.onTap != null;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(
        color: widget.selected
            ? c.cardBorderSelected
            : (_hover && tappable ? c.cardBorderHover : c.cardBorder),
        width: widget.selected ? 1.5 : 1,
      ),
    );
    // A tinted card ([color]) stays flat; the default one is lit from above.
    final surface = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: widget.color,
        gradient: widget.color == null ? c.cardGradient : null,
        shadows: widget.color == null ? c.cardShadow : null,
      ),
      child: Material(
        color: c.clear,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: tappable
            ? InkWell(
                onTap: widget.onTap,
                hoverColor: c.hoverLayer,
                highlightColor: c.pressedLayer,
                child: Padding(padding: widget.padding, child: widget.child),
              )
            : Padding(padding: widget.padding, child: widget.child),
      ),
    );
    final body = tappable
        ? MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: Pressable(scale: 0.985, child: surface),
          )
        : surface;
    final ringed = tappable
        ? FocusRing(radius: AppRadius.lg, child: body)
        : body;
    return widget.semanticLabel == null
        ? ringed
        : Semantics(
            container: true,
            label: widget.semanticLabel,
            child: ringed,
          );
  }
}
