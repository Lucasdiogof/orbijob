import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/format/job_format.dart';
import '../../../../core/widgets/compatibility_indicator.dart';
import '../../../../core/widgets/confidence_indicator.dart';
import '../../../../core/widgets/favorite_button.dart';
import '../../../../core/widgets/focus_ring.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/job_posting.dart';

/// Job card. Information hierarchy: title, company, place, work mode, salary, date, compatibility,
/// confidence, favourite, source. Anything the source did not provide is simply not drawn.
class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.scored,
    this.selected = false,
    this.onTap,
    this.isFavorite = false,
    this.onFavoriteChanged,
    this.now,
  });

  final ScoredJob scored;
  final bool selected;
  final VoidCallback? onTap;
  final bool isFavorite;
  final ValueChanged<bool>? onFavoriteChanged;

  /// Clock injection for tests and previews.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final j = scored.job;
    final m = scored.match;
    final place = placeLabel(j);
    final salary = formatSalary(j, l);
    final published = formatPublished(j.publishedAt, now ?? DateTime.now(), l);
    final mode = workModeLabel(j.workMode, l);
    final ui = Localizations.localeOf(context).languageCode;
    final langName = (j.language != null && j.language != ui)
        ? nativeLanguageName(j.language)
        : null;

    return FocusRing(
      child: Material(
        color: c.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: selected ? c.cardBorderSelected : c.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s3,
              AppSpace.s2,
              AppSpace.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          right: AppSpace.s2,
                          top: AppSpace.s1,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              localeForSubtree: j.language == null
                                  ? null
                                  : Locale(j.language!),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(j.title, style: t.titleMedium),
                                  const SizedBox(height: AppSpace.s1),
                                  Text(j.company, style: t.bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (onFavoriteChanged != null)
                      FavoriteButton(
                        isFavorite: isFavorite,
                        onChanged: onFavoriteChanged,
                      )
                    else
                      const SizedBox(width: AppSpace.s2),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.s2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (place != null) ...[
                        const SizedBox(height: AppSpace.s2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.place_outlined,
                                size: AppSize.iconSm,
                                color: c.muted,
                              ),
                            ),
                            const SizedBox(width: AppSpace.s1),
                            Expanded(
                              child: Text(
                                place,
                                style: t.bodyMedium!.copyWith(color: c.muted),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (mode.isNotEmpty ||
                          (j.contractType ?? '').isNotEmpty ||
                          langName != null) ...[
                        const SizedBox(height: AppSpace.s3),
                        Wrap(
                          spacing: AppSpace.s2,
                          runSpacing: AppSpace.s2,
                          children: [
                            if (mode.isNotEmpty)
                              StatusBadge(
                                label: mode,
                                icon: _modeIcon(j.workMode),
                              ),
                            if ((j.contractType ?? '').isNotEmpty)
                              StatusBadge(label: j.contractType!),
                            if (langName != null)
                              Semantics(
                                label: l.jobLanguageSemantic(langName),
                                excludeSemantics: true,
                                child: StatusBadge(
                                  label: langName,
                                  icon: Icons.translate,
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (salary != null || published != null) ...[
                        const SizedBox(height: AppSpace.s3),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpace.s3,
                          runSpacing: AppSpace.s1,
                          children: [
                            if (salary != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(salary, style: t.titleSmall),
                                  ),
                                  if (j.salaryCurrency != null) ...[
                                    const SizedBox(width: AppSpace.s2),
                                    Text(
                                      j.salaryCurrency!,
                                      style: context.technicalStyle,
                                    ),
                                  ],
                                ],
                              ),
                            if (published != null)
                              Text(
                                published,
                                style: t.bodySmall!.copyWith(color: c.muted),
                              ),
                          ],
                        ),
                      ],
                      if (m != null) ...[
                        const SizedBox(height: AppSpace.s2),
                        Divider(color: c.divider, height: 1),
                        const SizedBox(height: AppSpace.s2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpace.s5,
                          runSpacing: AppSpace.s3,
                          children: [
                            CompatibilityIndicator(
                              score: m.score,
                              size: 40,
                              showLabel: true,
                            ),
                            ConfidenceIndicator(level: m.confidence),
                          ],
                        ),
                      ],
                      if (j.sourceName != null) ...[
                        const SizedBox(height: AppSpace.s3),
                        Text(
                          l.sourceLabel(j.sourceName!),
                          style: t.bodySmall!.copyWith(color: c.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _modeIcon(WorkMode m) => switch (m) {
    WorkMode.remote => Icons.public,
    WorkMode.hybrid => Icons.sync_alt,
    WorkMode.onsite => Icons.apartment,
    WorkMode.unspecified => Icons.work_outline,
  };
}
