import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../design/design.dart';

/// Placeholder block. Pulses gently unless the platform asks to reduce motion.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 12});

  final double? width;
  final double height;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    if (_reduce) {
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
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            c.skeletonBase,
            c.skeletonHighlight,
            _reduce ? 0 : _ctl.value,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      ),
    );
  }
}

/// Loading placeholder shaped like a job card.
class JobCardSkeleton extends StatelessWidget {
  const JobCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.cardBg,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 200, height: 18),
            SizedBox(height: AppSpace.s3),
            SkeletonBox(width: 140),
            SizedBox(height: AppSpace.s2),
            SkeletonBox(width: 180),
            SizedBox(height: AppSpace.s4),
            SkeletonBox(height: 28),
          ],
        ),
      ),
    );
  }
}

/// A list of skeleton cards announced to screen readers as "Searching…".
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).searching,
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
          itemBuilder: (_, _) => const JobCardSkeleton(),
        ),
      ),
    );
  }
}
