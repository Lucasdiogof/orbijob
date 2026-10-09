import 'package:flutter/material.dart';

import '../../features/search/domain/entities/job_posting.dart';
import '../../l10n/app_localizations.dart';
import '../design/design.dart';

/// Confidence of the compatibility analysis: three segments + text. Independent from the score.
class ConfidenceIndicator extends StatelessWidget {
  const ConfidenceIndicator({super.key, required this.level});

  final ConfidenceLevel level;

  static String labelOf(AppLocalizations l, ConfidenceLevel level) =>
      switch (level) {
        ConfidenceLevel.high => l.confidenceHigh,
        ConfidenceLevel.medium => l.confidenceMedium,
        ConfidenceLevel.low => l.confidenceLow,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final filled = switch (level) {
      ConfidenceLevel.high => 3,
      ConfidenceLevel.medium => 2,
      ConfidenceLevel.low => 1,
    };
    final label = labelOf(l, level);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: l.confidenceSemantic(label),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpace.s2,
        runSpacing: AppSpace.s1,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 14,
                  height: 6,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: i < filled ? c.primary : c.bg,
                    border: Border.all(
                      color: i < filled ? c.primary : c.outline,
                    ),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
            ],
          ),
          Text(label, style: context.text.bodySmall!.copyWith(color: c.muted)),
        ],
      ),
    );
  }
}
