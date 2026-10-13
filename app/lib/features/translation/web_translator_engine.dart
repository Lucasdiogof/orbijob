import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'translation_engine.dart';

/// Web: the browser's own on-device Translator API (Chrome and Edge on desktop, version 138 and later). The text is translated by a
/// model inside the browser; nothing is sent to a server. Browsers without the API (Firefox, Safari, mobile browsers) report
/// "unsupported" and the original text stays. The page never loads a third-party translation script.
///
/// What was and was not verified: written against the published API (`Translator.availability()`, `Translator.create()`,
/// `translator.translate()`), with feature detection and timeouts so a missing or stalled API cannot hang the page. It was not
/// exercised against a real model download in the build environment (the embedded browser there exposes the API but never answers).
class WebTranslatorEngine implements TranslationEngine {
  WebTranslatorEngine();

  static const _timeout = Duration(seconds: 4);
  final _translators = <String, JSObject>{};

  JSObject? get _ctor {
    if (!globalContext.has('Translator')) return null;
    final c = globalContext['Translator'];
    return c.isA<JSObject>() ? c as JSObject : null;
  }

  @override
  String get name => 'chrome-translator';

  /// The size of the browser's language packs varies; the browser shows its own download progress.
  @override
  int get approxDownloadMb => 0;

  @override
  bool supportsSource(String code) => _ctor != null && code.length >= 2;
  @override
  bool supportsTarget(String code) => _ctor != null && code.length >= 2;

  JSObject _options(String from, String to) =>
      {'sourceLanguage': from, 'targetLanguage': to}.jsify()! as JSObject;

  @override
  Future<EngineReadiness> readiness(String from, String to) async {
    final c = _ctor;
    if (c == null) return EngineReadiness.unsupported;
    try {
      final p =
          c.callMethod('availability'.toJS, _options(from, to)) as JSPromise;
      final r = await p.toDart.timeout(_timeout);
      return switch ((r as JSString).toDart) {
        'available' => EngineReadiness.ready,
        'downloadable' || 'downloading' => EngineReadiness.needsDownload,
        _ => EngineReadiness.unsupported,
      };
    } catch (_) {
      return EngineReadiness.unsupported;
    }
  }

  Future<JSObject> _translator(String from, String to) async {
    final key = '$from>$to';
    final have = _translators[key];
    if (have != null) return have;
    final c = _ctor!;
    final p = c.callMethod('create'.toJS, _options(from, to)) as JSPromise;
    final t = await p.toDart;
    return _translators[key] = t as JSObject;
  }

  @override
  Future<bool> prepare(String from, String to) async {
    if (_ctor == null) return false;
    try {
      // `create` starts the download (it needs the click that led here, so it is called straight from the button's handler)
      await _translator(from, to);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    final t = await _translator(from, to);
    final p = t.callMethod('translate'.toJS, text.toJS) as JSPromise;
    return ((await p.toDart) as JSString).toDart;
  }

  @override
  Future<void> dispose() async {
    for (final t in _translators.values) {
      try {
        t.callMethod('destroy'.toJS);
      } catch (_) {}
    }
    _translators.clear();
  }
}
