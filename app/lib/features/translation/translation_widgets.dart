import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design/design.dart';
import '../../core/format/job_format.dart';
import '../../core/orbi/orbi.dart';
import '../../l10n/app_localizations.dart';
import '../search/domain/entities/job_posting.dart';
import 'translation_cubit.dart';

/// The translation cubit if the app provides one (previews and some tests do not): callers then show the original text.
TranslationCubit? maybeTranslation(BuildContext context) {
  try {
    return context.read<TranslationCubit>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// The language a listing is written in: identified from its own text, falling back to what the source declared.
String? jobLanguage(BuildContext context, JobPosting j) =>
    maybeTranslation(context)?.sourceLanguageOf(j) ?? j.language?.toLowerCase();

/// Native name of a language code, with Traditional / Simplified Chinese told apart.
String? languageLabel(String? code) => nativeLanguageName(code);

/// Gives [builder] the title to show for [job] (translated when available) and whether it is translated, and asks the cubit for
/// the translation when this is built. Never blocks: until a translation exists the original is shown.
class TranslatedTitle extends StatefulWidget {
  const TranslatedTitle({super.key, required this.job, required this.builder});

  final JobPosting job;
  final Widget Function(BuildContext context, String title, bool translated)
  builder;

  @override
  State<TranslatedTitle> createState() => _TranslatedTitleState();
}

class _TranslatedTitleState extends State<TranslatedTitle> {
  void _request() {
    final c = maybeTranslation(context);
    if (c == null) return;
    // after the frame: requesting may emit, and a build must not cause state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.requestTitle(widget.job);
    });
  }

  @override
  void didUpdateWidget(TranslatedTitle old) {
    super.didUpdateWidget(old);
    if (old.job != widget.job) _request();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _request();
  }

  @override
  Widget build(BuildContext context) {
    final c = maybeTranslation(context);
    if (c == null) return widget.builder(context, widget.job.title, false);
    return BlocBuilder<TranslationCubit, TranslationState>(
      bloc: c,
      buildWhen: (a, b) =>
          a.target != b.target ||
          a.enabled != b.enabled ||
          a.titles[TranslationCubit.titleKey(
                TranslationCubit.jobKey(widget.job),
                a.target,
                widget.job.title,
              )] !=
              b.titles[TranslationCubit.titleKey(
                TranslationCubit.jobKey(widget.job),
                b.target,
                widget.job.title,
              )],
      builder: (context, s) {
        if (s.enabled)
          _request(); // a language change asks again; cached results return at once
        final t = s.enabled ? c.titleFor(widget.job) : null;
        return widget.builder(context, t ?? widget.job.title, t != null);
      },
    );
  }
}

/// The small "translated" mark shown next to a translated title in lists.
class TranslatedMark extends StatelessWidget {
  const TranslatedMark({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Tooltip(
      message: l.translationAuto,
      child: Icon(
        Icons.translate_rounded,
        size: 14,
        color: context.colors.muted,
        semanticLabel: l.translationAuto,
      ),
    );
  }
}

/// What the detail screen says about the translation of a listing: progress, the download offer, honest failures, and the
/// "automatic translation" note with the switch between translation and original.
class TranslationBanner extends StatelessWidget {
  const TranslationBanner({
    super.key,
    required this.detail,
    required this.showOriginal,
    required this.onToggle,
    required this.onDownload,
    required this.onRetry,
  });

  final DetailTranslation detail;
  final bool showOriginal;
  final VoidCallback onToggle;
  final VoidCallback onDownload;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final lang = languageLabel(detail.from) ?? '?';
    Widget note(IconData icon, String text, {Widget? action}) => OrbiCard(
      color: c.container,
      padding: const EdgeInsets.all(AppSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: AppSize.iconSm, color: c.muted),
          ),
          const SizedBox(width: AppSpace.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: context.metadataStyle),
                if (action != null) ...[
                  const SizedBox(height: AppSpace.s1),
                  action,
                ],
              ],
            ),
          ),
        ],
      ),
    );

    switch (detail.status) {
      case DetailStatus.none:
        return const SizedBox.shrink();
      case DetailStatus.loading || DetailStatus.downloading:
        return OrbiCard(
          color: c.container,
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Semantics(
            liveRegion: true,
            child: Row(
              children: [
                const OrbiLoadingIndicator(size: 20),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Text(
                    detail.status == DetailStatus.downloading
                        ? l.translationDownloading
                        : l.translationLoading,
                    style: context.metadataStyle,
                  ),
                ),
              ],
            ),
          ),
        );
      case DetailStatus.needsDownload:
        return OrbiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.translationNeedsTitle, style: context.text.titleSmall),
              const SizedBox(height: AppSpace.s1),
              Text(
                kIsWeb || detail.downloadMb == 0
                    ? l.translationNeedsBodyWeb
                    : l.translationNeedsBody(detail.downloadMb),
                style: context.text.bodySmall!.copyWith(color: c.muted),
              ),
              const SizedBox(height: AppSpace.s3),
              OrbiSecondaryButton(
                label: l.translationDownload,
                icon: Icons.translate_rounded,
                onPressed: onDownload,
              ),
            ],
          ),
        );
      case DetailStatus.offlineNoModel:
        return note(Icons.cloud_off_outlined, l.translationOfflineNoModel);
      case DetailStatus.waitingWifi:
        return note(
          Icons.wifi_rounded,
          l.translationWaitingWifi(detail.downloadMb),
          action: OrbiTextButton(
            label: l.translationDownloadNow,
            onPressed: onDownload,
          ),
        );
      case DetailStatus.unsupported:
        return note(Icons.translate_rounded, l.translationUnsupported(lang));
      case DetailStatus.failed:
        return note(
          Icons.error_outline_rounded,
          l.translationFailed,
          action: OrbiTextButton(label: l.retry, onPressed: onRetry),
        );
      case DetailStatus.ready || DetailStatus.partial:
        return OrbiCard(
          color: c.container,
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s3,
            AppSpace.s3,
            AppSpace.s2,
            AppSpace.s3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.translate_rounded,
                    size: AppSize.iconSm,
                    color: c.muted,
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Text(
                      showOriginal
                          ? l.translationOriginalLabel(lang)
                          : l.translationNote(lang),
                      style: context.metadataStyle,
                    ),
                  ),
                  OrbiTextButton(
                    label: showOriginal
                        ? l.translationShowTranslation
                        : l.translationShowOriginal,
                    onPressed: onToggle,
                  ),
                ],
              ),
              if (!showOriginal && detail.cut)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.s2),
                  child: Text(
                    l.translationPartialCut,
                    style: context.metadataStyle,
                  ),
                ),
              if (!showOriginal && detail.keptLines > 0)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.s2, top: 2),
                  child: Text(
                    l.translationPartialLines,
                    style: context.metadataStyle,
                  ),
                ),
            ],
          ),
        );
    }
  }
}
