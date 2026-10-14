import 'package:shared_preferences/shared_preferences.dart';

import '../presentation/auth_cubit.dart';

/// [RecoveryMarker] on the device's preferences: only the id of the account whose recovery session waits for a new password (no e-mail,
/// no code, no token).
class PrefsRecoveryMarker implements RecoveryMarker {
  PrefsRecoveryMarker(this._prefs);
  final SharedPreferences _prefs;
  static const key = 'auth.recovery_pending_user';

  @override
  String? read() => _prefs.getString(key);

  @override
  Future<void> write(String? userId) async {
    if (userId == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, userId);
    }
  }
}
