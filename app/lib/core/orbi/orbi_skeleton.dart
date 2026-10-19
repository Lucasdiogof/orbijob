import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../design/design.dart';
import 'orbi_card.dart';

/// One shimmer clock for a whole group of skeleton blocks (a list), so a loading screen runs one animation, not one per block.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});
  final Widget child;

  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PulseScope>()?.animation;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctl.stop();
    } else if (!_ctl.isAnimating) {
      _ctl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _PulseScope(animation: _ctl, child: widget.child);
}

class _PulseScope extends InheritedWidget {
  const _PulseScope({required this.animation, required super.child});
  final Animation<double> animation;

  @override
  bool updateShouldNotify(_PulseScope old) => old.animation != animation;
}

/// Placeholder block. A soft shimmer runs across it unless the platform asks to reduce motion; inside a [SkeletonPulse]
/// it follows the shared clock, alone it runs its own.
class OrbiSkeleton extends StatefulWidget {
  const OrbiSkeleton({super.key, this.width, this.height = 12, this.radius});

  final double? width;
  final double height;
  final double? radius;

  @override
  State<OrbiSkeleton> createState() => _OrbiSkeletonState();
}

class _OrbiSkeletonState extends State<OrbiSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _own;
  Animation<double>? _shared;
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    _shared = SkeletonPulse.maybeOf(context);
    if (_shared != null || _reduce) {
      _own?.stop();
    } else {
      _own ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      );
      if (!_own!.isAnimating) _own!.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final clock = _reduce ? null : (_shared ?? _own);
    Widget block(double v) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Color.lerp(
          c.skeletonBase,
          c.skeletonHighlight,
          Curves.easeInOut.transform(v),
        ),
        borderRadius: BorderRadius.circular(widget.radius ?? AppRadius.xs),
      ),
    );
    if (clock == null) return block(0);
    return AnimatedBuilder(
      animation: clock,
      builder: (_, _) => block(clock.value),
    );
  }
}

/// Loading placeholder shaped like a job card.
class OrbiJobCardSkeleton extends StatelessWidget {
  const OrbiJobCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const OrbiCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrbiSkeleton(width: 220, height: 18),
        SizedBox(height: AppSpace.s2),
        OrbiSkeleton(width: 140, height: 14),
        SizedBox(height: AppSpace.s3),
        OrbiSkeleton(width: 180),
        SizedBox(height: AppSpace.s3),
        Row(
          children: [
            OrbiSkeleton(width: 72, height: 22, radius: AppRadius.xs),
            SizedBox(width: AppSpace.s3),
            OrbiSkeleton(width: 96, height: 14),
          ],
        ),
        SizedBox(height: AppSpace.s3),
        OrbiSkeleton(width: 120, height: 10),
      ],
    ),
  );
}

/// A list of skeleton cards announced to screen readers as "Searching…".
class OrbiSkeletonList extends StatelessWidget {
  const OrbiSkeletonList({super.key, this.count = 3, this.shrinkWrap = false});

  final int count;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).searching,
    liveRegion: true,
    child: ExcludeSemantics(
      child: SkeletonPulse(
        child: ListView.separated(
          shrinkWrap: shrinkWrap,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
          itemBuilder: (_, _) => const OrbiJobCardSkeleton(),
        ),
      ),
    ),
  );
}
