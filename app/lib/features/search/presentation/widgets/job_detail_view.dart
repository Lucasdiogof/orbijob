import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/design.dart';
import '../../../../core/format/description_text.dart';
import '../../../../core/format/geo_eligibility.dart';
import '../../../../core/format/job_format.dart';
import '../../../../core/orbi/orbi.dart';
import '../../../../core/widgets/compatibility_indicator.dart';
import '../../../../core/widgets/confidence_indicator.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../translation/translation_cubit.dart';
import '../../../translation/translation_widgets.dart';
import '../../../applications/application_kit.dart';
import '../../../browser/open_in_app.dart';
import '../../data/job_snapshot.dart' show manualSource;
import '../../domain/entities/job_posting.dart';

/// Whether the job has an original listing the person can be sent to.
bool hasOriginalListing(JobPosting j) =>
    j.source != manualSource && j.originalUrl.isNotEmpty;

/// Opens the job's own site inside the app (the one behaviour shared by the detail page, the pane and the application kit).
Future<void> openOriginalListing(BuildContext context, JobPosting j) =>
    openInApp(context, j.originalUrl, job: j);

/// Details of one job. Shown as a page on narrow screens and as the detail pane on wide ones.
///
/// It also asks for the translation of the listing into the interface language (on demand, only for this listing) and lets the
/// person switch between translation and original.
class JobDetailView extends StatefulWidget {
  const JobDetailView({
    super.key,
    required this.scored,
    this.onOpenApplication,
    this.now,
    this.showActions = true,
  });

  final ScoredJob scored;
  final VoidCallback? onOpenApplication;
  final DateTime? now;
  final bool showActions;

  @override
  State<JobDetailView> createState() => _JobDetailViewState();
}

class _JobDetailViewState extends State<JobDetailView> {
  var _showOriginal = false;

  void _load() {
    final c = maybeTranslation(context);
    if (c == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.loadDetail(widget.scored.job);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(JobDetailView old) {
    super.didUpdateWidget(old);
    if (old.scored.job != widget.scored.job) {
      _showOriginal = false;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = maybeTranslation(context);
    Widget body(DetailTranslation? d) => _JobDetailBody(
      scored: widget.scored,
      onOpenApplication: widget.onOpenApplication,
      now: widget.now,
      showActions: widget.showActions,
      detail: d,
      showOriginal: _showOriginal,
      onToggle: () => setState(() => _showOriginal = !_showOriginal),
      onDownload: () => c?.downloadAndLoad(widget.scored.job),
      onRetry: () => c?.loadDetail(widget.scored.job, retry: true),
    );
    if (c == null) return body(null);
    final key = TranslationCubit.jobKey(widget.scored.job);
    return BlocBuilder<TranslationCubit, TranslationState>(
      bloc: c,
      buildWhen: (a, b) =>
          a.details[key] != b.details[key] || a.target != b.target,
      builder: (context, s) => body(s.enabled ? s.details[key] : null),
    );
  }
}

/// Details of one job (the content). Shown as a page on narrow screens and as the detail pane on wide ones.
///
/// [showActions] puts the call to action at the end of the content (detail pane); the page passes false and keeps the
/// button fixed at the bottom instead.
class _JobDetailBody extends StatelessWidget {
  const _JobDetailBody({
    required this.scored,
    required this.onOpenApplication,
    required this.now,
    required this.showActions,
    required this.detail,
    required this.showOriginal,
    required this.onToggle,
    required this.onDownload,
    required this.onRetry,
  });

  /// The translation of this listing for the current interface language (null when translation is not provided).
  final DetailTranslation? detail;
  final bool showOriginal;
  final VoidCallback onToggle;
  final VoidCallback onDownload;
  final VoidCallback onRetry;

  final ScoredJob scored;

  /// Opens the official application. Null hides the button (no destination yet).
  final VoidCallback? onOpenApplication;
  final DateTime? now;
  final bool showActions;

  /// Who may apply, in words. An empty list is NOT read as "worldwide": the source said nothing, so the screen says that.
  /// Whenever the answer is ambiguous (unknown, regions, mixed, names it does not recognise) it asks to check the original listing.
  List<Widget> _eligibility(
    BuildContext context,
    JobPosting j,
    AppLocalizations l,
  ) {
    final c = context.colors;
    final t = context.text;
    final g = geoEligibility(j, Localizations.localeOf(context).languageCode);
    final line = switch (g.kind) {
      GeoKind.unknown => l.eligibilityUnknown,
      GeoKind.anywhere => l.eligibleAnywhere,
      _ => l.eligibleIn(g.places.join(', ')),
    };
    return [
      const SizedBox(height: AppSpace.s2),
      Text(line, style: t.bodyMedium!.copyWith(color: c.muted)),
      if (g.needsCheck) ...[
        const SizedBox(height: AppSpace.s1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: AppSize.iconSm, color: c.muted),
            const SizedBox(width: AppSpace.s1),
            Expanded(
              child: Text(
                l.eligibilityCheckOriginal,
                style: t.bodySmall!.copyWith(color: c.muted),
              ),
            ),
          ],
        ),
      ],
    ];
  }

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
    final lang = detail?.from ?? jobLanguage(context, j);
    final langName = (lang != null && lang.split('-').first != ui)
        ? nativeLanguageName(lang)
        : null;
    // translated text is only shown when BOTH title and description are translated (the cubit reports ready/partial only then),
    // so a translated title is never paired with a description in another language without saying so
    final translated =
        detail != null &&
        (detail!.status == DetailStatus.ready ||
            detail!.status == DetailStatus.partial) &&
        !showOriginal;
    final hasTranslation =
        detail != null &&
        (detail!.status == DetailStatus.ready ||
            detail!.status == DetailStatus.partial);
    final shownTitle = translated && detail!.title != null
        ? detail!.title!
        : j.title;
    final shownDescription = translated && detail!.description != null
        ? detail!.description!
        : j.description;
    final textLocale = translated
        ? Locale(ui)
        : (lang == null ? null : Locale(lang.split('-').first));
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        OrbiCard(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                localeForSubtree: textLocale,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (j.company.isNotEmpty &&
                        OrbiMonogram.initialOf(j.company) != null &&
                        MediaQuery.textScalerOf(context).scale(16) <= 22) ...[
                      OrbiMonogram(name: j.company, size: 48),
                      const SizedBox(height: AppSpace.s4),
                    ],
                    Semantics(
                      header: true,
                      child: Text(shownTitle, style: t.headlineLarge),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    if (j.company.isNotEmpty)
                      Text(
                        j.company,
                        style: t.titleSmall!.copyWith(color: c.muted),
                      ),
                  ],
                ),
              ),
              if (place != null) ...[
                const SizedBox(height: AppSpace.s3),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: AppSize.iconSm,
                      color: c.muted,
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
              ..._eligibility(context, j, l),
              if (mode.isNotEmpty ||
                  (j.contractType ?? '').isNotEmpty ||
                  langName != null) ...[
                const SizedBox(height: AppSpace.s4),
                Wrap(
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s2,
                  children: [
                    if (mode.isNotEmpty) OrbiStatusBadge(label: mode),
                    if ((j.contractType ?? '').isNotEmpty)
                      OrbiStatusBadge(label: j.contractType!),
                    if (langName != null)
                      OrbiStatusBadge(
                        label: langName,
                        icon: Icons.translate_rounded,
                      ),
                  ],
                ),
              ],
              // "not translated" is only true when no translation exists: the banner below speaks for translated listings
              if (langName != null && !hasTranslation) ...[
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
                      Text(published, style: context.metadataStyle),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (detail != null && detail!.status != DetailStatus.none) ...[
          const SizedBox(height: AppSpace.s3),
          TranslationBanner(
            detail: detail!,
            showOriginal: showOriginal,
            onToggle: onToggle,
            onDownload: onDownload,
            onRetry: onRetry,
          ),
        ],
        if ((shownDescription ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpace.s3),
          OrbiCard(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(l.jobDescriptionTitle, style: t.titleMedium),
                ),
                const SizedBox(height: AppSpace.s3),
                Semantics(
                  localeForSubtree: textLocale,
                  // Plain text only: the catalogue strips markup before storing.
                  child: Text(
                    cleanDescriptionText(shownDescription!),
                    style: t.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (m != null) ...[
          const SizedBox(height: AppSpace.s3),
          OrbiCard(
            padding: const EdgeInsets.all(AppSpace.s5),
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
        ],
        if (j.sourceName != null) ...[
          const SizedBox(height: AppSpace.s4),
          Text(l.sourceLabel(j.sourceName!), style: context.metadataStyle),
        ],
        if (showActions) ...[
          const SizedBox(height: AppSpace.s4),
          JobDetailActions(job: j, onOpenApplication: onOpenApplication),
        ],
      ],
    );
  }
}

/// The call to action of a job: the official application when the app has one, otherwise the original listing.
/// Honest wording: OrbiJob never applies for anyone, it only sends the person to the source.
class JobDetailActions extends StatelessWidget {
  const JobDetailActions({
    super.key,
    required this.job,
    this.onOpenApplication,
  });

  final JobPosting job;
  final VoidCallback? onOpenApplication;

  /// Whether there is anything to show (so the page can skip an empty bottom bar).
  static bool hasActions(JobPosting j, VoidCallback? onOpenApplication) =>
      onOpenApplication != null || hasOriginalListing(j);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasOriginalListing(job)) ...[
          OrbiSecondaryButton(
            label: l.kitButton,
            icon: Icons.assignment_ind_outlined,
            onPressed: () => showApplicationKit(context, job),
          ),
          const SizedBox(height: AppSpace.s2),
        ],
        if (onOpenApplication != null)
          OrbiPrimaryButton(
            label: l.openOfficialApplication,
            icon: Icons.open_in_new_rounded,
            onPressed: onOpenApplication,
            expand: true,
          ),
        if (hasOriginalListing(job)) ...[
          if (onOpenApplication != null) const SizedBox(height: AppSpace.s2),
          onOpenApplication == null
              ? OrbiPrimaryButton(
                  label: l.openOriginalListing,
                  icon: Icons.open_in_new_rounded,
                  onPressed: () => openOriginalListing(context, job),
                  expand: true,
                )
              : OrbiSecondaryButton(
                  label: l.openOriginalListing,
                  icon: Icons.open_in_new_rounded,
                  onPressed: () => openOriginalListing(context, job),
                ),
        ],
      ],
    );
  }
}
