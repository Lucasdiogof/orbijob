import 'package:flutter/material.dart';

import '../design/design.dart';

/// Draws a visible keyboard-focus outline around [child] (only when navigating with a keyboard/remote,
/// never after a touch or mouse press) so focus is not conveyed by colour alone: it is a 2 px outline.
class FocusRing extends StatefulWidget {
  const FocusRing({super.key, required this.child, this.radius = AppRadius.md});

  final Widget child;
  final double radius;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onMode);
    super.dispose();
  }

  void _onMode(FocusHighlightMode _) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final show =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (v) => setState(() => _focused = v),
      child: DecoratedBox(
        key: show ? const ValueKey('focus-ring-active') : null,
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: show
              ? Border.all(
                  color: context.colors.focus,
                  width: AppSize.focusRingWidth,
                )
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
