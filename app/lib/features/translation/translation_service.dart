import 'dart:async';
import 'dart:collection';

import 'translation_cache.dart';
import 'translation_engine.dart';
import 'text_protection.dart';

enum TranslationOutcome {
  /// Translated (possibly from the cache).
  ok,

  /// Translated, but some lines were kept in the original (a protected part did not survive) or the text was cut at the limit.
  partial,

  /// The text is already in the requested language.
  sameLanguage,

  /// No engine on this device can translate that pair.
  unsupported,

  /// Supported, but the language data has not been downloaded yet.
  needsDownload,

  /// The engine failed (the original stays available).
  failed,
}

class TextTranslation {
  const TextTranslation(
    this.outcome, {
    this.text,
    this.from,
    this.keptLines = 0,
    this.cut = false,
  });
  final TranslationOutcome outcome;
  final String? text;
  final String? from;

  /// How many lines were left in the original language.
  final int keptLines;

  /// The text was longer than the limit and only its beginning was translated.
  final bool cut;

  bool get hasText => text != null;
}

/// Translates listing text on demand, on the device, with a cache and a limit on parallel work.
///
/// * Nothing is translated until a screen asks for it, and never the whole catalogue.
/// * The cache key holds the target language and a hash of the original text: switching language reuses earlier work, and an
///   updated listing (new text) misses the cache.
/// * At most [maxParallel] engine calls run at once, across all callers; identical requests in flight share one run.
/// * Engine failures are remembered for [failureBackoff] so a broken engine is not hammered.
class TranslationService {
  TranslationService({
    required this.engine,
    required this.cache,
    this.maxParallel = 2,
    this.maxChars = 8000,
    this.failureBackoff = const Duration(seconds: 45),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final TranslationEngine engine;
  final TranslationCache cache;
  final int maxParallel;

  /// Beyond this many characters the text is cut at a line break and flagged as partial.
  final int maxChars;
  final Duration failureBackoff;
  final DateTime Function() _clock;

  var _running = 0;
  final _waiting = Queue<Completer<void>>();
  final _inFlight = <String, Future<TextTranslation>>{};
  final _failedAt = <String, DateTime>{};

  /// Engine calls that were made (for tests and diagnostics).
  int engineCalls = 0;

  Future<void> _acquire() async {
    if (_running < maxParallel) {
      _running++;
      return;
    }
    final c = Completer<void>();
    _waiting.add(c);
    await c.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _running--;
    }
  }

  /// FNV-1a over the UTF-16 code units: a cheap, stable fingerprint of the original text.
  static String fingerprint(String text) {
    var h = 0x811c9dc5;
    for (final u in text.codeUnits) {
      h ^= u;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  static String cacheKey(String id, String field, String to, String text) =>
      '$id|$field|$to|${fingerprint(text)}';

  Future<EngineReadiness> readiness(String from, String to) async {
    if (from == to) return EngineReadiness.ready;
    if (!engine.supportsSource(from) || !engine.supportsTarget(to)) {
      return EngineReadiness.unsupported;
    }
    return engine.readiness(from, to);
  }

  Future<bool> prepare(String from, String to) => engine.prepare(from, to);

  /// A previous result for exactly this text, if any, without starting any work.
  Future<TextTranslation?> cached(
    String id,
    String field,
    String to,
    String text,
  ) async {
    final c = await cache.get(cacheKey(id, field, to, text));
    if (c == null) return null;
    return TextTranslation(
      c.partial ? TranslationOutcome.partial : TranslationOutcome.ok,
      text: c.text,
      from: c.from,
      cut: c.partial,
    );
  }

  /// Translates [text] (identified by [id] and [field]) from [from] to [to].
  /// [keep] are strings that must stay as written (the company name). [onProgress] receives 0..1.
  Future<TextTranslation> translate({
    required String id,
    required String field,
    required String text,
    required String from,
    required String to,
    Iterable<String> keep = const [],
    void Function(double)? onProgress,
  }) {
    if (from == to) {
      return Future.value(
        const TextTranslation(TranslationOutcome.sameLanguage),
      );
    }
    final key = cacheKey(id, field, to, text);
    final running = _inFlight[key];
    if (running != null) return running;
    final f = _run(key, text, from, to, keep, onProgress).whenComplete(() {
      // a block body: returning the removed future here would make whenComplete wait for itself
      _inFlight.remove(key);
    });
    _inFlight[key] = f;
    return f;
  }

  Future<TextTranslation> _run(
    String key,
    String text,
    String from,
    String to,
    Iterable<String> keep,
    void Function(double)? onProgress,
  ) async {
    final hit = await cache.get(key);
    if (hit != null) {
      return TextTranslation(
        hit.partial ? TranslationOutcome.partial : TranslationOutcome.ok,
        text: hit.text,
        from: hit.from,
        cut: hit.partial,
      );
    }
    final failed = _failedAt[key];
    if (failed != null && _clock().difference(failed) < failureBackoff) {
      return TextTranslation(TranslationOutcome.failed, from: from);
    }
    final ready = await readiness(from, to);
    if (ready == EngineReadiness.unsupported) {
      return TextTranslation(TranslationOutcome.unsupported, from: from);
    }
    if (ready == EngineReadiness.needsDownload) {
      return TextTranslation(TranslationOutcome.needsDownload, from: from);
    }

    var source = text;
    var cut = false;
    if (source.length > maxChars) {
      final at = source.lastIndexOf('\n', maxChars);
      source = source.substring(0, at > maxChars ~/ 2 ? at : maxChars);
      cut = true;
    }
    final lines = source.split('\n');
    final results = List<String?>.filled(lines.length, null);
    var kept = 0;
    var done = 0;
    var failure = false;

    Future<void> doLine(int i) async {
      final line = lines[i];
      if (line.trim().isEmpty) {
        results[i] = line;
        return;
      }
      final b = splitBullet(line);
      try {
        Future<String?> attempt(bool acronymsAsMarkers) async {
          final p = protectLine(
            b.body,
            keep: keep,
            acronymsAsMarkers: acronymsAsMarkers,
          );
          final pieces = <String>[];
          for (final chunk in chunkLine(p.text)) {
            await _acquire();
            try {
              engineCalls++;
              pieces.add(await engine.translate(chunk, from: from, to: to));
            } finally {
              _release();
            }
          }
          return restoreLine(pieces.join(' '), p);
        }

        // level 1: every protected part is a marker. Level 2 (only when level 1 was not trusted and the line has acronyms):
        // acronyms stay in the text and must come back verbatim. Otherwise the line is kept as written.
        var restored = await attempt(true);
        if (restored == null &&
            protectLine(b.body, keep: keep).originals.isNotEmpty) {
          restored = await attempt(false);
        }
        if (restored == null) {
          kept++;
          results[i] =
              line; // a protected part did not survive: keep this line as written
        } else {
          results[i] = '${b.prefix}$restored';
        }
      } catch (_) {
        failure = true;
      }
      onProgress?.call(++done / lines.length);
    }

    // lines run concurrently; the semaphore around the engine keeps the real parallelism at maxParallel
    await Future.wait([for (var i = 0; i < lines.length; i++) doLine(i)]);
    if (failure || results.any((r) => r == null)) {
      _failedAt[key] = _clock();
      return TextTranslation(TranslationOutcome.failed, from: from);
    }
    final out = results.cast<String>().join('\n');
    final allKept = kept == lines.where((l) => l.trim().isNotEmpty).length;
    if (allKept) {
      return TextTranslation(TranslationOutcome.failed, from: from);
    }
    final partial = cut || kept > 0;
    await cache.put(
      key,
      CachedTranslation(text: out, from: from, partial: partial),
    );
    return TextTranslation(
      partial ? TranslationOutcome.partial : TranslationOutcome.ok,
      text: out,
      from: from,
      keptLines: kept,
      cut: cut,
    );
  }

  /// Forgets remembered failures so an explicit "try again" is not held back by the back-off.
  void clearFailures() => _failedAt.clear();

  Future<void> dispose() => engine.dispose();
}
