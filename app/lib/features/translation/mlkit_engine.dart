import 'dart:async';

import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'translation_engine.dart';

/// Android and iOS: Google's on-device ML Kit translation. Free, offline once a language is downloaded (about 30 MB each),
/// 59 languages, no account, no quota; the text never leaves the device. Languages are translated through English when neither
/// side is English (ML Kit does this itself), so quality for non-English pairs is lower than for pairs with English.
///
/// ML Kit lists one "Chinese" (it does not separate Traditional and Simplified) and its Chinese quality is noticeably weaker
/// than for European languages; the screens say that the translation is automatic and the original is one tap away.
class MlKitTranslationEngine implements TranslationEngine {
  MlKitTranslationEngine({this.idle = const Duration(seconds: 20)});

  /// Translators keep their language data in memory: they are closed after this much inactivity.
  final Duration idle;

  final _manager = OnDeviceTranslatorModelManager();
  final _translators = <String, OnDeviceTranslator>{};
  Timer? _idleTimer;

  static final _languages = {
    for (final l in TranslateLanguage.values) l.bcpCode: l,
  };

  /// `zh-Hant` and `zh-Hans` are the same ML Kit language, `zh`.
  static String _primary(String code) => code.split('-').first.toLowerCase();

  @override
  String get name => 'mlkit';

  @override
  int get approxDownloadMb => 30;

  @override
  bool supportsSource(String code) => _languages.containsKey(_primary(code));
  @override
  bool supportsTarget(String code) => _languages.containsKey(_primary(code));

  Future<bool> _has(String code) async {
    final c = _primary(code);
    // English is part of the engine; every other language is a downloadable model
    if (c == 'en') return true;
    return _manager.isModelDownloaded(c);
  }

  @override
  Future<EngineReadiness> readiness(String from, String to) async {
    if (!supportsSource(from) || !supportsTarget(to)) {
      return EngineReadiness.unsupported;
    }
    return await _has(from) && await _has(to)
        ? EngineReadiness.ready
        : EngineReadiness.needsDownload;
  }

  @override
  Future<bool> prepare(String from, String to) async {
    try {
      for (final c in [_primary(from), _primary(to)]) {
        if (c == 'en' || await _manager.isModelDownloaded(c)) continue;
        // the person agreed to the download in the screen that asked; mobile data is allowed
        final ok = await _manager.downloadModel(c, isWifiRequired: false);
        if (!ok) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  OnDeviceTranslator _translatorFor(String from, String to) {
    final f = _primary(from);
    final t = _primary(to);
    return _translators.putIfAbsent(
      '$f>$t',
      () => OnDeviceTranslator(
        sourceLanguage: _languages[f]!,
        targetLanguage: _languages[t]!,
      ),
    );
  }

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    final tr = _translatorFor(from, to);
    _idleTimer?.cancel();
    try {
      return await tr.translateText(text);
    } finally {
      _idleTimer = Timer(idle, () {
        unawaited(dispose());
      });
    }
  }

  @override
  Future<void> dispose() async {
    _idleTimer?.cancel();
    final all = _translators.values.toList();
    _translators.clear();
    for (final t in all) {
      try {
        await t.close();
      } catch (_) {}
    }
  }
}
