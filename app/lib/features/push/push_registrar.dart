import 'dart:async';

import 'domain/push_messaging.dart';

/// Keeps `push_devices` in step with who is signed in on this device:
/// * signed in → ask permission (the system asks only once), store the token, follow its rotations;
/// * BEFORE signing out → remove the row (afterwards there is no session to authorise the delete) and forget the token, so the next account on
///   the same phone starts clean.
/// Every failure is swallowed: push is a convenience on top of the in-app notification centre and must never break sign-in or sign-out.
class PushRegistrar {
  PushRegistrar(this._messaging, this._devices);
  final PushMessaging _messaging;
  final PushDevicesRepository? _devices;

  String? _userId;
  String? _token;
  StreamSubscription<String>? _refresh;

  /// Notification ids of pushes the person tapped.
  Stream<String> get opened => _messaging.opened;

  Future<void> onSignedIn(String userId, {String? locale}) async {
    final devices = _devices;
    final platform = _messaging.platform;
    if (devices == null || platform == null || _userId == userId) return;
    _userId = userId;
    try {
      if (!await _messaging.start()) return;
      final t = await _messaging.token();
      if (t == null || _userId != userId) return;
      _token = t;
      await devices.register(token: t, platform: platform, locale: locale);
      await _refresh?.cancel();
      _refresh = _messaging.tokenRefresh.listen((n) async {
        if (_userId != userId) return;
        final old = _token;
        _token = n;
        try {
          await devices.register(token: n, platform: platform, locale: locale);
          if (old != null && old != n) await devices.remove(old);
        } catch (_) {}
      });
    } catch (_) {
      // no push this time; the bell keeps working
    }
  }

  Future<void> beforeSignOut() async {
    final t = _token;
    _userId = null;
    _token = null;
    await _refresh?.cancel();
    _refresh = null;
    if (t == null) return;
    try {
      await _devices?.remove(t);
    } catch (_) {}
    try {
      await _messaging.deleteToken();
    } catch (_) {}
  }
}
