import 'package:shared_preferences/shared_preferences.dart';

import 'browser_engine.dart';

/// Makes the clean-up of the in-app browser's stored data trustworthy: a persistent "dirty" flag is raised BEFORE the clean-up starts and
/// lowered only when every step passed. If the clean-up fails, times out or the app is killed in the middle, the flag stays up and the
/// browser is not opened ([ensureClean]) until a new clean-up succeeds, so the next person on the device never browses with the previous
/// person's cookies, cache or local storage.
class BrowserDataGuard {
  BrowserDataGuard(this._engine, this._prefs);
  final BrowserEngine _engine;
  final SharedPreferences? _prefs;
  static const dirtyKey = 'browser.data_dirty';
  bool _memory = false;

  bool get dirty => _prefs?.getBool(dirtyKey) ?? _memory;

  Future<void> _set(bool v) async {
    _memory = v;
    await _prefs?.setBool(dirtyKey, v);
  }

  /// Runs the clean-up; true when every step passed (the flag is then lowered).
  Future<bool> clear() async {
    await _set(true);
    var ok = false;
    try {
      ok = await _engine.clearData();
    } catch (_) {}
    if (ok) await _set(false);
    return ok;
  }

  /// True when the browser may be opened: nothing pending, or the pending clean-up has just succeeded.
  Future<bool> ensureClean() async => !dirty || await clear();
}
