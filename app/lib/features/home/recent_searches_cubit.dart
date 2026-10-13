import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The words the person searched for, newest first. Kept ON THIS DEVICE only (never sent to the server), separately for each account and for "not
/// signed in", so switching accounts never shows one person's searches to another. The person can turn the memory off, which also forgets what
/// was kept, and clear it at any time.
///
/// Searches are recorded when a search is submitted, not while typing; the write to storage is also coalesced ([debounce]) so a burst of searches is
/// one write. Without storage (tests, a browser that refuses it) it works in memory.
class RecentSearchesCubit extends Cubit<List<String>> {
  RecentSearchesCubit({SharedPreferences? prefs, this.debounce = Duration.zero})
    : _prefs = prefs,
      super(const []) {
    enabled.value = prefs?.getBool(_enabledKey) ?? true;
  }

  static const maxItems = 10;
  static const maxLength = 100;
  static const _enabledKey = 'orbijob.recent_searches.enabled';
  static String _key(String scope) => 'orbijob.recent_searches.$scope';

  final SharedPreferences? _prefs;

  /// Zero writes at once (tests); the app passes a short delay.
  final Duration debounce;

  /// Whether searches are remembered at all. Observed by the settings screen.
  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  String _scope = 'anonymous';
  Timer? _timer;

  /// Switches to the list of [userId] (null = nobody signed in): what was pending is saved first, then the stored list of the new scope is shown.
  void useScope(String? userId) {
    flush();
    _scope = userId ?? 'anonymous';
    emit(enabled.value ? _read() : const []);
  }

  List<String> _read() {
    final stored = _prefs?.getStringList(_key(_scope)) ?? const <String>[];
    return [
      for (final s in stored)
        if (s.trim().isNotEmpty) s,
    ].take(maxItems).toList();
  }

  void record(String query) {
    if (!enabled.value) return;
    var q = query.trim();
    if (q.isEmpty) return;
    if (q.length > maxLength) q = q.substring(0, maxLength).trim();
    final next = [q, ...state.where((e) => e.toLowerCase() != q.toLowerCase())];
    emit(next.take(maxItems).toList());
    _schedule();
  }

  /// Forgets the list on this device (the memory itself stays on or off as it was).
  void clear() {
    _timer?.cancel();
    _timer = null;
    emit(const []);
    _prefs?.remove(_key(_scope));
  }

  Future<void> setEnabled(bool on) async {
    enabled.value = on;
    await _prefs?.setBool(_enabledKey, on);
    if (!on) clear();
  }

  void _schedule() {
    if (_prefs == null) return;
    if (debounce == Duration.zero) return _write();
    _timer?.cancel();
    _timer = Timer(debounce, _write);
  }

  void _write() {
    _timer = null;
    _prefs?.setStringList(_key(_scope), state);
  }

  /// Writes a pending change now (before a scope change, when the app closes).
  void flush() {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _write();
    }
  }

  @override
  Future<void> close() {
    flush();
    enabled.dispose();
    return super.close();
  }
}
