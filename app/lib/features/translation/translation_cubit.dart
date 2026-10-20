import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../search/domain/entities/job_posting.dart';
import 'language_detector.dart';
import 'network_probe.dart';
import 'translation_engine.dart';
import 'translation_service.dart';

/// Where the translation of one listing's detail stands.
enum DetailStatus {
  /// Nothing to do: translation is off, the language could not be identified, or it already is the interface language.
  none,
  loading,
  ready,

  /// Translated, but part of the text was kept in the original (cut at the limit, or protected parts could not be trusted).
  partial,

  /// The language data must be downloaded first (the person decides).
  needsDownload,
  downloading,

  /// The language data is missing and there is no connection: it is fetched when one comes back (the original is shown meanwhile).
  offlineNoModel,

  /// The language data is missing and the device is on mobile data: the policy waits for Wi-Fi (the person can download now).
  waitingWifi,

  /// No engine on this device translates this language.
  unsupported,

  /// The language data could not be downloaded (failure or timeout): the person can try again or read the original.
  downloadFailed,
  failed,
}

class DetailTranslation extends Equatable {
  const DetailTranslation(
    this.status, {
    this.from,
    this.title,
    this.description,
    this.progress = 0,
    this.cut = false,
    this.keptLines = 0,
    this.downloadMb = 0,
  });

  final DetailStatus status;
  final String? from;
  final String? title;
  final String? description;
  final double progress;
  final bool cut;
  final int keptLines;
  final int downloadMb;

  bool get hasText => title != null || description != null;

  @override
  List<Object?> get props => [
    status,
    from,
    title,
    description,
    progress,
    cut,
    keptLines,
    downloadMb,
  ];
}

/// When missing language data (about 30 MB per language) may be downloaded without a tap.
enum DownloadPolicy {
  /// By itself on Wi-Fi or any unmetered connection; on mobile data it waits and offers a button. The default.
  wifiOnly,

  /// By itself on any connection, mobile data included.
  always,

  /// Never by itself: the detail screen asks.
  ask,
}

class TranslationState extends Equatable {
  const TranslationState({
    this.target = 'en',
    this.enabled = true,
    this.policy = DownloadPolicy.wifiOnly,
    this.titles = const {},
    this.details = const {},
    this.modelsVersion = 0,
  });

  /// The interface language: what listings are translated into.
  final String target;
  final bool enabled;
  final DownloadPolicy policy;

  /// Translated short texts (titles, contract types) by `jobKey|target|fingerprint` (`jobKey|field|target|fingerprint` for other fields).
  final Map<String, String> titles;

  /// Grows each time language data lands on the device, so cards that were waiting for it ask again.
  final int modelsVersion;

  /// Detail translations by job key, for the current [target] only.
  final Map<String, DetailTranslation> details;

  TranslationState copyWith({
    String? target,
    bool? enabled,
    DownloadPolicy? policy,
    Map<String, String>? titles,
    Map<String, DetailTranslation>? details,
    int? modelsVersion,
  }) => TranslationState(
    target: target ?? this.target,
    enabled: enabled ?? this.enabled,
    policy: policy ?? this.policy,
    titles: titles ?? this.titles,
    details: details ?? this.details,
    modelsVersion: modelsVersion ?? this.modelsVersion,
  );

  @override
  List<Object?> get props => [
    target,
    enabled,
    policy,
    titles,
    details,
    modelsVersion,
  ];
}

/// Decides what to translate, when, and keeps what the screens show. Everything is on demand and non-blocking: a card asks for its
/// title when it is built, a detail screen asks for the full text, and a language change simply asks again (cached results come
/// back instantly). The catalogue is never translated as a whole, and the original text is never replaced in the data.
class TranslationCubit extends Cubit<TranslationState> {
  TranslationCubit(
    this.service, {
    String initialTarget = 'en',
    SharedPreferences? prefs,
    this.network,
  }) : _prefs = prefs,
       super(
         TranslationState(
           target: initialTarget,
           enabled: prefs?.getBool(_enabledKey) ?? true,
           policy: _readPolicy(prefs),
         ),
       );

  static const _enabledKey = 'tr.enabled';
  static const _policyKey = 'tr.download';

  /// What the connection is right now; null = unknown, language data is then never downloaded without a tap (tests, platforms without a probe).
  final NetworkProbe? network;
  final _downloads = <String, Future<PrepareOutcome>>{};
  String? _warmedFor;
  final _prepareFailures = <String, ({int count, DateTime at})>{};

  static DownloadPolicy _readPolicy(SharedPreferences? p) {
    final v = p?.getString(_policyKey);
    return DownloadPolicy.values.firstWhere(
      (e) => e.name == v,
      orElse: () => DownloadPolicy.wifiOnly,
    );
  }

  Future<void> setPolicy(DownloadPolicy p) async {
    await _prefs?.setString(_policyKey, p.name);
    _epoch++;
    emit(state.copyWith(policy: p, details: const {}));
    _warmedFor = null;
    unawaited(warmUp());
  }

  /// One download per language pair at a time: two screens asking for the same data share it. Failures are counted for the back-off.
  Future<PrepareOutcome> _prepareOnce(String from, String to) {
    final k = '$from>$to';
    return _downloads[k] ??= service
        .prepare(from, to)
        .then((o) {
          _readyMemo.remove(k);
          if (o == PrepareOutcome.ready) {
            _prepareFailures.remove(k);
            if (!isClosed) {
              emit(state.copyWith(modelsVersion: state.modelsVersion + 1));
            }
          } else {
            _prepareFailures[k] = (
              count: (_prepareFailures[k]?.count ?? 0) + 1,
              at: DateTime.now(),
            );
          }
          return o;
        })
        .whenComplete(() {
          // a block body: returning the removed future would make whenComplete wait for itself
          _downloads.remove(k);
        });
  }

  /// Automatic downloads wait 30 s after the first failure, doubling up to 15 min; a tap on retry ignores the wait.
  bool _inBackoff(String from, String to) {
    final f = _prepareFailures['$from>$to'];
    if (f == null) return false;
    final wait = Duration(
      seconds: (30 * (1 << (f.count - 1).clamp(0, 5))).clamp(30, 900),
    );
    return DateTime.now().difference(f.at) < wait;
  }

  /// Whether the download policy lets language data be fetched now without a tap.
  Future<bool> _mayDownloadNow() async {
    if (kIsWeb || state.policy == DownloadPolicy.ask) return false;
    final net = await network?.kind();
    return net == NetworkKind.unmetered ||
        (net == NetworkKind.mobile && state.policy == DownloadPolicy.always);
  }

  /// Fetches language data for lists and prefetching, when the policy allows it now. Idempotent and quiet: one download per pair,
  /// no new attempt during the back-off, and the cards that were waiting ask again when it lands (see [TranslationState.modelsVersion]).
  Future<void> _autoPrepare(String from, String to) async {
    if (_downloads.containsKey('$from>$to') || _inBackoff(from, to)) return;
    if (!await _mayDownloadNow() || isClosed) return;
    unawaited(_prepareOnce(from, to));
  }

  /// Gets the interface language's own data ready ahead of the first listing (only when the policy allows it now), so the first
  /// card needs at most the listing's language.
  Future<void> warmUp() async {
    final to = state.target;
    if (!state.enabled || to == 'en' || _warmedFor == to) return;
    _warmedFor = to; // once per language and setting: the readiness check is a native call
    if (await service.readiness('en', to) == EngineReadiness.needsDownload) {
      await _autoPrepare('en', to);
    }
  }

  final TranslationService service;
  final SharedPreferences? _prefs;

  final _requestedTitles = <String>{};
  final _detected = <String, String?>{};
  final _readyMemo = <String, ({EngineReadiness r, DateTime at})>{};
  var _epoch = 0;

  static String jobKey(JobPosting j) => '${j.source}:${j.externalId}';

  static String titleKey(String job, String target, String title) =>
      '$job|$target|${TranslationService.fingerprint(title)}';

  /// The language of a listing, from its own text (and, only when the text is too short to tell, from the source's declaration).
  /// The country never decides.
  String? sourceLanguageOf(JobPosting j) {
    final key = '${jobKey(j)}|${j.title.length}|${j.description?.length ?? 0}';
    return _detected.putIfAbsent(key, () {
      final text =
          '${j.title}\n${(j.description ?? '').substring(0, (j.description ?? '').length.clamp(0, 1500))}';
      final d = detectLanguage(text);
      if (d != null) {
        return d.code == 'zh' && d.script == 'Hant' ? 'zh-Hant' : d.code;
      }
      final declared = j.language?.toLowerCase();
      return declared == null || declared.isEmpty ? null : declared;
    });
  }

  /// The interface language changed: later requests use it, everything shown for the old one is dropped (cached work is kept).
  void setTarget(String code) {
    if (code == state.target) return;
    _epoch++;
    emit(state.copyWith(target: code, details: const {}));
  }

  Future<void> setEnabled(bool on) async {
    await _prefs?.setBool(_enabledKey, on);
    _epoch++;
    emit(state.copyWith(enabled: on, details: const {}));
  }

  Future<void> clearSaved() async {
    await service.cache.clear();
    _requestedTitles.clear();
    emit(state.copyWith(titles: const {}, details: const {}));
  }

  Future<EngineReadiness> _ready(String from, String to) async {
    final k = '$from>$to';
    final memo = _readyMemo[k];
    final now = DateTime.now();
    if (memo != null && now.difference(memo.at) < const Duration(seconds: 20)) {
      return memo.r;
    }
    final r = await service.readiness(from, to);
    _readyMemo[k] = (r: r, at: now);
    return r;
  }

  /// The translated title if one is available for the current language, else null (callers show the original).
  String? titleFor(JobPosting j) => fieldFor(j, 'title', j.title);

  static String fieldKey(
    String job,
    String field,
    String target,
    String text,
  ) => field == 'title'
      ? titleKey(job, target, text)
      : '$job|$field|$target|${TranslationService.fingerprint(text)}';

  /// The translation of a short text of the listing (`title`, `contract`) for the current language, else null.
  String? fieldFor(JobPosting j, String field, String text) =>
      state.titles[fieldKey(jobKey(j), field, state.target, text)];

  /// Asks for the title of a card. Cheap and idempotent: it does nothing when translation is off, the listing already is in the
  /// interface language, the language cannot be identified, or the language data is not on the device (the detail screen offers
  /// the download; a list never downloads anything by itself).
  void requestTitle(JobPosting j) => requestField(j, 'title', j.title);

  void requestField(JobPosting j, String field, String text) {
    if (!state.enabled || text.isEmpty) return;
    final target = state.target;
    final key = fieldKey(jobKey(j), field, target, text);
    if (state.titles.containsKey(key) || !_requestedTitles.add(key)) return;
    final from = sourceLanguageOf(j);
    if (from == null || from.split('-').first == target) return;
    () async {
      try {
        final cached = await service.cached(jobKey(j), field, target, text);
        TextTranslation? r = cached;
        if (r == null) {
          if (await _ready(from, target) != EngineReadiness.ready) {
            // may become ready later: the download below (policy permitting) bumps modelsVersion and the card asks again
            _requestedTitles.remove(key);
            unawaited(_autoPrepare(from, target));
            return;
          }
          r = await service.translate(
            id: jobKey(j),
            field: field,
            text: text,
            from: from,
            to: target,
            keep: [j.company],
          );
        }
        if (r.hasText) {
          if (!isClosed) {
            emit(state.copyWith(titles: {...state.titles, key: r.text!}));
          }
        } else {
          _requestedTitles.remove(key);
        }
      } catch (_) {
        _requestedTitles.remove(key);
      }
    }();
  }

  /// Translates title and description of one listing for its detail screen.
  Future<void> loadDetail(
    JobPosting j, {
    bool retry = false,
    bool afterDownload = false,
  }) async {
    if (retry) {
      service.clearFailures();
      _prepareFailures.clear();
    }
    final id = jobKey(j);
    if (!state.enabled) return;
    final target = state.target;
    final from = sourceLanguageOf(j);
    if (from == null || from.split('-').first == target) {
      _setDetail(id, target, const DetailTranslation(DetailStatus.none));
      return;
    }
    final epoch = _epoch;
    final desc = j.description ?? '';

    // cached results make a language switch instant
    final cTitle = await service.cached(id, 'title', target, j.title);
    final cDesc = desc.isEmpty
        ? null
        : await service.cached(id, 'description', target, desc);
    if (cTitle != null && (desc.isEmpty || cDesc != null)) {
      _setDetail(id, target, _result(from, cTitle, cDesc), epoch: epoch);
      return;
    }

    final ready = await _ready(from, target);
    if (ready == EngineReadiness.unsupported) {
      _setDetail(
        id,
        target,
        DetailTranslation(DetailStatus.unsupported, from: from),
        epoch: epoch,
      );
      return;
    }
    if (ready == EngineReadiness.needsDownload && afterDownload) {
      // the download reported success but the data is not there
      _setDetail(
        id,
        target,
        DetailTranslation(DetailStatus.downloadFailed, from: from),
        epoch: epoch,
      );
      return;
    }
    if (ready == EngineReadiness.needsDownload) {
      final mb = service.engine.approxDownloadMb;
      final net = kIsWeb || state.policy == DownloadPolicy.ask
          ? null
          : await network?.kind();
      if (epoch != _epoch) return;
      if (net == null) {
        _setDetail(
          id,
          target,
          DetailTranslation(
            DetailStatus.needsDownload,
            from: from,
            downloadMb: mb,
          ),
          epoch: epoch,
        );
        return;
      }
      if (net == NetworkKind.none) {
        _setDetail(
          id,
          target,
          DetailTranslation(DetailStatus.offlineNoModel, from: from),
          epoch: epoch,
        );
        return;
      }
      if (net == NetworkKind.mobile &&
          state.policy == DownloadPolicy.wifiOnly) {
        _setDetail(
          id,
          target,
          DetailTranslation(
            DetailStatus.waitingWifi,
            from: from,
            downloadMb: mb,
          ),
          epoch: epoch,
        );
        return;
      }
      // allowed by the policy: fetch the data now, without a tap (but not again right after a failure: the person can retry)
      if (_inBackoff(from, target)) {
        _setDetail(
          id,
          target,
          DetailTranslation(DetailStatus.downloadFailed, from: from),
          epoch: epoch,
        );
        return;
      }
      await downloadAndLoad(j);
      return;
    }
    _setDetail(
      id,
      target,
      DetailTranslation(DetailStatus.loading, from: from),
      epoch: epoch,
    );
    final t = await service.translate(
      id: id,
      field: 'title',
      text: j.title,
      from: from,
      to: target,
      keep: [j.company],
    );
    TextTranslation? d;
    if (desc.isNotEmpty) {
      d = await service.translate(
        id: id,
        field: 'description',
        text: desc,
        from: from,
        to: target,
        keep: [j.company],
        onProgress: (p) => _setDetail(
          id,
          target,
          DetailTranslation(DetailStatus.loading, from: from, progress: p),
          epoch: epoch,
        ),
      );
    }
    _setDetail(id, target, _result(from, t, d), epoch: epoch);
  }

  DetailTranslation _result(
    String from,
    TextTranslation title,
    TextTranslation? desc,
  ) {
    final failed = !title.hasText || (desc != null && !desc.hasText);
    if (failed) {
      final worst = !title.hasText ? title : desc!;
      return switch (worst.outcome) {
        TranslationOutcome.unsupported => DetailTranslation(
          DetailStatus.unsupported,
          from: from,
        ),
        TranslationOutcome.needsDownload => DetailTranslation(
          DetailStatus.needsDownload,
          from: from,
          downloadMb: service.engine.approxDownloadMb,
        ),
        _ => DetailTranslation(DetailStatus.failed, from: from),
      };
    }
    final partial =
        title.outcome == TranslationOutcome.partial ||
        desc?.outcome == TranslationOutcome.partial;
    return DetailTranslation(
      partial ? DetailStatus.partial : DetailStatus.ready,
      from: from,
      title: title.text,
      description: desc?.text,
      cut: desc?.cut ?? false,
      keptLines: (desc?.keptLines ?? 0) + title.keptLines,
      progress: 1,
    );
  }

  /// Downloads the language data (the person said yes) and then translates.
  Future<void> downloadAndLoad(JobPosting j) async {
    final id = jobKey(j);
    final target = state.target;
    final from = sourceLanguageOf(j);
    if (from == null) return;
    _setDetail(
      id,
      target,
      DetailTranslation(DetailStatus.downloading, from: from),
    );
    final out = await _prepareOnce(from, target);
    if (out != PrepareOutcome.ready) {
      _setDetail(
        id,
        target,
        DetailTranslation(DetailStatus.downloadFailed, from: from),
      );
      return;
    }
    _readyMemo.remove('$from>$target');
    await loadDetail(j, afterDownload: true);
  }

  /// "Try again" on the detail screen: a failed download is fetched again (the person asked), anything else is simply re-run.
  Future<void> retryDetail(JobPosting j) {
    final d = state.details[jobKey(j)];
    if (d?.status == DetailStatus.downloadFailed) {
      _prepareFailures.clear();
      return downloadAndLoad(j);
    }
    return loadDetail(j, retry: true);
  }

  void _setDetail(String id, String target, DetailTranslation d, {int? epoch}) {
    if (isClosed ||
        target != state.target ||
        (epoch != null && epoch != _epoch)) {
      return;
    }
    emit(state.copyWith(details: {...state.details, id: d}));
  }

  @override
  Future<void> close() async {
    await service.dispose();
    return super.close();
  }
}
