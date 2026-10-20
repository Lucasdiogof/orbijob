/// Versions of the published legal texts the person accepts when creating an account. They are the "last updated" dates printed
/// on https://lucksrei.com/projects/orbijob/terms/ and /privacy/: change them together with those pages.
const termsVersion = '2026-10-14';
const privacyVersion = '2026-10-20';

/// What the sign-up stores in the account's `user_metadata` (Supabase Auth): which texts were accepted, and when.
Map<String, Object> legalConsentData(DateTime now) => {
  'terms_version': termsVersion,
  'privacy_version': privacyVersion,
  'accepted_at': now.toUtc().toIso8601String(),
};

/// Result of asking the server to record the acceptance (the trusted record, `record_terms_acceptance`).
enum ConsentRecordResult {
  recorded,

  /// The server does not have the function yet (rollout order): the sign-up goes on, `user_metadata` stays as the secondary note.
  unavailable,

  /// Network or server trouble: worth trying again at the next session.
  failed,
}

abstract class ConsentRecorder {
  Future<ConsentRecordResult> record(
    String termsVersion,
    String privacyVersion,
  );
}

/// The acceptance made at sign-up that waits for a session (with e-mail confirmation the session only exists after the confirmation).
/// Kept with the e-mail so another person signing in on the device never receives it.
abstract class ConsentStore {
  String? read();
  Future<void> write(String? value);
}

String encodePendingConsent(String email, String terms, String privacy) =>
    '${email.trim().toLowerCase()}|$terms|$privacy';

({String email, String terms, String privacy})? decodePendingConsent(
  String? raw,
) {
  final p = raw?.split('|');
  if (p == null || p.length != 3 || p.any((e) => e.isEmpty)) return null;
  return (email: p[0], terms: p[1], privacy: p[2]);
}
