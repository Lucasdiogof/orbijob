import 'package:flutter/material.dart';

import '../../features/search/domain/entities/job_posting.dart';
import '../../l10n/app_localizations.dart';
import '../../features/translation/translation_widgets.dart';
import '../design/design.dart';
import '../format/job_format.dart';
import '../widgets/compatibility_indicator.dart';
import '../widgets/favorite_button.dart';
import 'orbi_card.dart';
import 'orbi_chips.dart';
import 'orbi_monogram.dart';

/// Job card. Reading order: title, company, place, work mode and pay, then the quiet footer (date, source).
/// Anything the source did not provide is simply not drawn; nothing is invented. One discreet badge at most (the work mode);
/// the contract type and the posting language are plain metadata.
/// Card content width below which the company monogram is not drawn, so the title keeps the room.
const double monogramMinCardWidth = 280;

class OrbiJobCard extends StatelessWidget {
  const OrbiJobCard({
    super.key,
    required this.scored,
    this.selected = false,
    this.onTap,
    this.isFavorite = false,
    this.onFavoriteChanged,
    this.menu,
    this.now,
    this.compact = false,
  });

  final ScoredJob scored;
  final bool selected;
  final VoidCallback? onTap;
  final bool isFavorite;
  final ValueChanged<bool>? onFavoriteChanged;

  /// The "more" menu next to the heart (hide, share, compare); null draws nothing.
  final Widget? menu;

  /// Clock injection for tests and previews.
  final DateTime? now;

  /// Tighter vertical rhythm (Home lists).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final j = scored.job;
    final m = scored.match;
    final place = placeLabel(j, l);
    final salary = formatSalary(j, l);
    final published = formatPublished(j.publishedAt, now ?? DateTime.now(), l);
    final mode = workModeLabel(j.workMode, l);
    final ui = Localizations.localeOf(context).languageCode;
    final lang = jobLanguage(context, j);
    final langName = (lang != null && lang.split('-').first != ui)
        ? nativeLanguageName(lang)
        : null;
    final foot = <String>[
      ?published,
      if (j.sourceName != null) l.sourceLabel(j.sourceName!),
    ];
    final facts = <String>[
      if ((j.contractType ?? '').isNotEmpty) j.contractType!,
      ?langName,
    ];

    return TranslatedTitle(
      job: j,
      builder: (context, title, translated) => OrbiCard(
        selected: selected,
        onTap: onTap,
        padding: EdgeInsets.fromLTRB(
          AppSpace.s4,
          compact ? AppSpace.s3 : AppSpace.s4,
          AppSpace.s2,
          compact ? AppSpace.s3 : AppSpace.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, box) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The tile is decorative: it yields to the title when the card itself is narrow
                  // (two-column Home at tablet widths), whatever the window width is.
                  if (box.maxWidth >= monogramMinCardWidth &&
                      j.company.isNotEmpty &&
                      OrbiMonogram.initialOf(j.company) != null &&
                      MediaQuery.textScalerOf(context).scale(16) <= 22)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpace.s3),
                      child: OrbiMonogram(name: j.company),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpace.s2),
                      child: Semantics(
                        localeForSubtree: translated
                            ? Locale(ui)
                            : (lang == null
                                  ? null
                                  : Locale(lang.split('-').first)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: t.titleMedium),
                            if (j.company.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(j.company, style: t.bodyMedium),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (onFavoriteChanged != null)
                    FavoriteButton(
                      isFavorite: isFavorite,
                      onChanged: onFavoriteChanged,
                    )
                  else if (menu == null)
                    const SizedBox(width: AppSpace.s2),
                  ?menu,
                ],
              ),
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
                            size: 16,
                            color: c.muted,
                          ),
                        ),
                        const SizedBox(width: AppSpace.s1 + 2),
                        Expanded(
                          child: Text(
                            place,
                            style: t.bodySmall!.copyWith(color: c.muted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (mode.isNotEmpty || salary != null) ...[
                    const SizedBox(height: AppSpace.s3),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpace.s3,
                      runSpacing: AppSpace.s2,
                      children: [
                        if (mode.isNotEmpty)
                          OrbiStatusBadge(
                            label: mode,
                            icon: _modeIcon(j.workMode),
                            kind: OrbiBadgeKind.info,
                          ),
                        if (salary != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  salary,
                                  style: AppTypography.figures(t.labelLarge!),
                                ),
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
                      ],
                    ),
                  ],
                  if (facts.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s2),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (translated)
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: TranslatedMark(),
                              ),
                            ),
                          TextSpan(text: facts.join(' · ')),
                        ],
                      ),
                      style: context.metadataStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (m != null) ...[
                    const SizedBox(height: AppSpace.s3),
                    CompatibilityIndicator(
                      score: m.score,
                      size: 36,
                      showLabel: true,
                    ),
                  ],
                  if (foot.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s3),
                    Text(
                      foot.join(' · '),
                      style: context.captionStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
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
