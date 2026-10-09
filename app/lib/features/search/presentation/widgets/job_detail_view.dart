import 'package:flutter/material.dart';

import '../../../../core/design/design.dart';
import '../../../../core/format/job_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/compatibility_indicator.dart';
import '../../../../core/widgets/confidence_indicator.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/job_posting.dart';

/// Details of one job. Shown as a page on narrow screens and as the detail pane on wide ones.
class JobDetailView extends StatelessWidget {
  const JobDetailView({
    super.key,
    required this.scored,
    this.onOpenApplication,
    this.now,
  });

  final ScoredJob scored;

  /// Opens the official application. Null hides the button (no destination yet).
  final VoidCallback? onOpenApplication;
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
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        Semantics(
          localeForSubtree: j.language == null ? null : Locale(j.language!),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(j.title, style: t.headlineMedium),
              ),
              const SizedBox(height: AppSpace.s2),
              Text(j.company, style: t.titleSmall),
            ],
          ),
        ),
        if (place != null) ...[
          const SizedBox(height: AppSpace.s2),
          Row(
            children: [
              Icon(Icons.place_outlined, size: AppSize.iconSm, color: c.muted),
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
              if (mode.isNotEmpty) StatusBadge(label: mode),
              if ((j.contractType ?? '').isNotEmpty)
                StatusBadge(label: j.contractType!),
              if (langName != null)
                StatusBadge(label: langName, icon: Icons.translate),
            ],
          ),
        ],
        if (langName != null) ...[
          const SizedBox(height: AppSpace.s2),
          Text(
            l.originalLanguageNote(langName),
            style: t.bodySmall!.copyWith(color: c.muted),
          ),
        ],
        if (salary != null || published != null) ...[
          const SizedBox(height: AppSpace.s4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpace.s3,
            runSpacing: AppSpace.s1,
            children: [
              if (salary != null) Text(salary, style: t.titleMedium),
              if (j.salaryCurrency != null && salary != null)
                Text(j.salaryCurrency!, style: context.technicalStyle),
              if (published != null)
                Text(published, style: t.bodySmall!.copyWith(color: c.muted)),
            ],
          ),
        ],
        if (m != null) ...[
          const SizedBox(height: AppSpace.s5),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.cardBg,
              border: Border.all(color: c.cardBorder),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpace.s5,
                    runSpacing: AppSpace.s3,
                    children: [
                      CompatibilityIndicator(
                        score: m.score,
                        size: 64,
                        showLabel: true,
                      ),
                      ConfidenceIndicator(level: m.confidence),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s3),
                  Text(
                    l.scoreExplainer,
                    style: t.bodySmall!.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (j.sourceName != null) ...[
          const SizedBox(height: AppSpace.s5),
          Text(
            l.sourceLabel(j.sourceName!),
            style: t.bodySmall!.copyWith(color: c.muted),
          ),
        ],
        if (onOpenApplication != null) ...[
          const SizedBox(height: AppSpace.s5),
          AppButton(
            label: l.openOfficialApplication,
            icon: Icons.open_in_new,
            onPressed: onOpenApplication,
            expand: true,
          ),
        ],
      ],
    );
  }
}
