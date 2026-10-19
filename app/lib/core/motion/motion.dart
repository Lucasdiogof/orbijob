import 'package:flutter/material.dart';

import '../design/design.dart';

/// True when the system asks for less movement; every animation of the product checks this one place.
bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Press feedback: the child shrinks a hair while a pointer or finger is down on it. It listens to raw pointer events, so it never competes with
/// the child's own tap handling, and it does nothing when motion is reduced.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.98,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || reduceMotion(context)) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}

/// One-time entrance: the child fades in while rising a few pixels, [index] steps after the first (capped, so a long page never waits).
/// Skipped with reduced motion. Meant for the first screenful only, never for rows that are rebuilt while scrolling.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final step = index.clamp(0, 6);
    final total = AppMotion.slow + Duration(milliseconds: 45 * step);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        step * 45 / total.inMilliseconds,
        1,
        curve: AppMotion.curve,
      ),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 10),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
