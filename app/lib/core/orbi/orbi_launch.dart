import 'package:flutter/material.dart';

import '../design/design.dart';
import 'orbi_loader.dart';

/// The short Flutter-side hand-over from the native splash: the same background and mark as the splash, one eased half turn
/// of the symbol, then a fade into the app. The app is already built underneath, so nothing waits for this; it is not
/// interactive, hidden from screen readers and skipped entirely when the platform asks to reduce motion.
/// It plays once per process.
class OrbiLaunchOverlay extends StatefulWidget {
  const OrbiLaunchOverlay({super.key, required this.child});
  final Widget child;

  static bool _played = false;

  /// Lets tests start from a clean state.
  static void resetForTests() => _played = false;

  @override
  State<OrbiLaunchOverlay> createState() => _OrbiLaunchOverlayState();
}

class _OrbiLaunchOverlayState extends State<OrbiLaunchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  bool _show = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OrbiLaunchOverlay._played) return;
    OrbiLaunchOverlay._played = true;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _show = true;
    _ctl.forward().whenComplete(() {
      if (mounted) setState(() => _show = false);
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return widget.child;
    final c = context.colors;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _ctl,
                builder: (context, _) {
                  final t = _ctl.value;
                  final turn = Curves.easeInOutCubic.transform(
                    ((t - 0.1) / 0.55).clamp(0.0, 1.0),
                  );
                  final fade =
                      1 -
                      Curves.easeIn.transform(
                        ((t - 0.6) / 0.4).clamp(0.0, 1.0),
                      );
                  return Opacity(
                    opacity: fade,
                    child: ColoredBox(
                      color: c.bg,
                      child: Center(
                        child: SizedBox.square(
                          dimension: 96,
                          child: CustomPaint(
                            painter: OrbiOrbitPainter(
                              progress: turn,
                              color: c.ink,
                              coreColor: c.primary,
                              ripple: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
