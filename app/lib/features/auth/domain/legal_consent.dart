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
