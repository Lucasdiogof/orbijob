import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A repository whose last `list()` answer may have come from the device copy instead of the server (no connection): when that copy was saved, or null
/// when the list is fresh.
abstract interface class ListedFromMirror {
  DateTime? get listedFromMirrorAt;
}

/// The last list of a signed-in user's own data (favourites, applications), kept on the device to read it without a connection (ORBI-001).
///
/// * one copy per list and per user id: another account on the same device never reads it;
/// * only reading is offered offline: nothing here queues a change, so a save or a stage change made without a connection fails as it always did
///   (and says so) instead of promising a sync that does not exist;
/// * [clearAll] removes every copy (sign-out, account deletion);
/// * storage that is full, missing or damaged is ignored: the list simply is not kept.
class ListMirror {
  ListMirror(this._prefs, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final SharedPreferences _prefs;
  final DateTime Function() _now;
  static const prefix = 'mirror.v1.';

  String _key(String list, String userId) => '$prefix$list.$userId';

  Future<void> write(String list, String userId, List<Object?> items) async {
    try {
      await _prefs.setString(
        _key(list, userId),
        jsonEncode({'at': _now().toUtc().toIso8601String(), 'items': items}),
      );
    } catch (_) {}
  }

  ({DateTime at, List<Object?> items})? read(String list, String userId) {
    try {
      final raw = _prefs.getString(_key(list, userId));
      if (raw == null) return null;
      final data = jsonDecode(raw);
      if (data is! Map || data['items'] is! List) return null;
      final at = DateTime.tryParse('${data['at']}');
      if (at == null) return null;
      return (at: at.toUtc(), items: (data['items'] as List).cast<Object?>());
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    try {
      for (final k
          in _prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
        await _prefs.remove(k);
      }
    } catch (_) {}
  }
}
