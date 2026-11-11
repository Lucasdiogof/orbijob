import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/legal_consent.dart';

/// Calls the server function `record_terms_acceptance` (server clock, versions checked against a list on the server). Tolerant on purpose:
/// where the function is not deployed yet the answer is [ConsentRecordResult.unavailable] and the sign-up is unaffected; the cause is
/// printed in debug builds only.
class SupabaseConsentRecorder implements ConsentRecorder {
  SupabaseConsentRecorder(this._client);
  final SupabaseClient _client;

  @override
  Future<ConsentRecordResult> record(
    String termsVersion,
    String privacyVersion,
  ) async {
    try {
      await _client.rpc<Object?>(
        'record_terms_acceptance',
        params: {
          'p_terms_version': termsVersion,
          'p_privacy_version': privacyVersion,
        },
      );
      return ConsentRecordResult.recorded;
    } on PostgrestException catch (e) {
      final missing =
          e.code == 'PGRST202' ||
          e.code == '42883' ||
          e.code == '404' ||
          e.message.contains('Could not find the function');
      if (kDebugMode) {
        debugPrint('record_terms_acceptance: ${e.code} ${e.message}');
      }
      return missing
          ? ConsentRecordResult.unavailable
          : ConsentRecordResult.failed;
    } catch (e) {
      if (kDebugMode) debugPrint('record_terms_acceptance: $e');
      return ConsentRecordResult.failed;
    }
  }
}

/// [ConsentStore] on the device's preferences.
class PrefsConsentStore implements ConsentStore {
  PrefsConsentStore(this._prefs);
  final SharedPreferences _prefs;
  static const key = 'auth.consent_pending';

  @override
  String? read() => _prefs.getString(key);

  @override
  Future<void> write(String? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }
}
