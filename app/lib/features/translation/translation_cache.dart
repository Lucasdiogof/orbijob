import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One stored translation of one text.
class CachedTranslation {
  const CachedTranslation({
    required this.text,
    required this.from,
    this.partial = false,
  });
  final String text;
  final String from;

  /// Only the first part of a very long text was translated.
  final bool partial;

  Map<String, Object?> toJson() => {'t': text, 'f': from, 'p': partial};
  static CachedTranslation? fromJson(Object? j) {
    if (j is! Map) return null;
    final t = j['t'];
    final f = j['f'];
    if (t is! String || f is! String) return null;
    return CachedTranslation(text: t, from: f, partial: j['p'] == true);
  }
}

/// Where finished translations are kept so the same text is never translated twice.
///
/// Keys are built by the service from the job, the field, the target language and a hash of the ORIGINAL text, so an updated
/// listing (different text) simply misses the cache and an old translation is never shown for new text.
abstract class TranslationCache {
  Future<CachedTranslation?> get(String key);
  Future<void> put(String key, CachedTranslation value);
  Future<void> clear();
}

class MemoryTranslationCache implements TranslationCache {
  final map = <String, CachedTranslation>{};
  @override
  Future<CachedTranslation?> get(String key) async => map[key];
  @override
  Future<void> put(String key, CachedTranslation value) async =>
      map[key] = value;
  @override
  Future<void> clear() async => map.clear();
}

/// Persistent cache in the platform's key-value store (shared preferences on Android/iOS, local storage on the web).
/// It is bounded: at most [maxEntries] entries and about [maxBytes] of text, evicting the least recently written first, so it
/// never grows without limit. Only translations are stored (the originals stay in the catalogue).
class PrefsTranslationCache implements TranslationCache {
  PrefsTranslationCache({
    this.maxEntries = 400,
    this.maxBytes = 2 * 1024 * 1024,
  });

  final int maxEntries;
  final int maxBytes;
  static const _indexKey = 'tr.index';
  static const _prefix = 'tr.v1.';

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null; // storage unavailable (private mode, tests without a store): the cache simply does not persist
    }
  }

  @override
  Future<CachedTranslation?> get(String key) async {
    final p = await _prefs();
    final raw = p?.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return CachedTranslation.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> put(String key, CachedTranslation value) async {
    final p = await _prefs();
    if (p == null) return;
    final index = [...?p.getStringList(_indexKey)]..remove(key);
    index.add(key);
    await p.setString('$_prefix$key', jsonEncode(value.toJson()));
    var bytes = 0;
    for (final k in index) {
      bytes += (p.getString('$_prefix$k') ?? '').length;
    }
    while (index.length > maxEntries ||
        (bytes > maxBytes && index.length > 1)) {
      final old = index.removeAt(0);
      bytes -= (p.getString('$_prefix$old') ?? '').length;
      await p.remove('$_prefix$old');
    }
    await p.setStringList(_indexKey, index);
  }

  @override
  Future<void> clear() async {
    final p = await _prefs();
    if (p == null) return;
    for (final k in [...?p.getStringList(_indexKey)]) {
      await p.remove('$_prefix$k');
    }
    await p.remove(_indexKey);
  }
}
