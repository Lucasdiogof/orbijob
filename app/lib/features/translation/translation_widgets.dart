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
class TranslatedTitle extends StatelessWidget {
  const TranslatedTitle({super.key, required this.job, required this.builder});

  final JobPosting job;
  final Widget Function(BuildContext context, String title, bool translated)
  builder;

  @override
  Widget build(BuildContext context) => TranslatedField(
    job: job,
    field: 'title',
    text: job.title,
    builder: builder,
  );
}

/// The same for any short text of a listing (`title`, `contract`): [builder] gets [text] translated when a translation exists,
/// and the cubit is asked for it (or not, when [request] is false because a fixed table already covers the text).
class TranslatedField extends StatefulWidget {
  const TranslatedField({
    super.key,
    required this.job,
    required this.field,
    required this.text,
    required this.builder,
    this.request = true,
  });

  final JobPosting job;
  final String field;
  final String text;
  final bool request;
  final Widget Function(BuildContext context, String text, bool translated)
  builder;

  @override
  State<TranslatedField> createState() => _TranslatedFieldState();
}

class _TranslatedFieldState extends State<TranslatedField> {
  void _request() {
    final c = maybeTranslation(context);
    if (c == null || !widget.request) return;
    // after the frame: requesting may emit, and a build must not cause state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.requestField(widget.job, widget.field, widget.text);
    });
  }

  @override
  void didUpdateWidget(TranslatedField old) {
    super.didUpdateWidget(old);
    if (old.job != widget.job || old.text != widget.text) _request();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _request();
  }

  @override
  Widget build(BuildContext context) {
    final c = maybeTranslation(context);
    if (c == null) return widget.builder(context, widget.text, false);
    String? at(TranslationState s) =>
        s.titles[TranslationCubit.fieldKey(
          TranslationCubit.jobKey(widget.job),
          widget.field,
          s.target,
          widget.text,
        )];
    return BlocBuilder<TranslationCubit, TranslationState>(
      bloc: c,
      buildWhen: (a, b) =>
          a.target != b.target ||
          a.enabled != b.enabled ||
          a.modelsVersion != b.modelsVersion || // language data just landed: a card that was waiting asks again
          at(a) != at(b),
      builder: (context, s) {
        if (s.enabled) _request(); // a language change asks again; cached results return at once
        final t = s.enabled ? at(s) : null;
        return widget.builder(context, t ?? widget.text, t != null);
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
    final ui = Localizations.localeOf(context).languageCode;
    final name = languageName(detail.from, ui) ?? '?';
    final lang = ui == 'en' ? name : name.toLowerCase(); // inside a sentence
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
      case DetailStatus.downloadFailed:
        return note(
          Icons.cloud_off_outlined,
          l.translationDownloadFailed,
          action: OrbiTextButton(label: l.retry, onPressed: onRetry),
        );
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
