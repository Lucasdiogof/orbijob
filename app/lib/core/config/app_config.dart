import 'dart:convert';

/// Build-time configuration, injected with `--dart-define` (see `.env.example` and docs/SUPABASE_SETUP.md).
/// Only PUBLIC values belong here: the project URL and the publishable (formerly "anon") key. A secret or
/// service_role key must never reach the app, so such keys are rejected at start-up.
class AppConfig {
  const AppConfig({this.supabaseUrl = '', this.supabasePublishableKey = ''});

  factory AppConfig.fromEnvironment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  final String supabaseUrl;
  final String supabasePublishableKey;

  /// True when both values are present; the app then talks to Supabase, otherwise it runs without accounts.
  bool get hasSupabase =>
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;

  /// Returns a human-readable problem, or null when the configuration is safe to use.
  String? validate() {
    // Unconfigured is valid: accounts are simply off.
    if (!hasSupabase) {
      return null;
    }
    final uri = Uri.tryParse(supabaseUrl.trim());
    final local =
        uri != null && (uri.host == 'localhost' || uri.host == '127.0.0.1');
    if (uri == null || !uri.hasAuthority || (uri.scheme != 'https' && !local)) {
      return 'SUPABASE_URL must be an https URL';
    }
    if (isSecretKey(supabasePublishableKey)) {
      return 'SUPABASE_PUBLISHABLE_KEY looks like a secret/service_role key; '
          'only the publishable key may be used in the app';
    }
    return null;
  }

  /// True for keys that grant privileged access: `sb_secret_…` or a legacy JWT whose role is service_role.
  static bool isSecretKey(String key) {
    final k = key.trim();
    if (k.startsWith('sb_secret_')) return true;
    final parts = k.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['role'] == 'service_role';
    } catch (_) {
      return false;
    }
  }
}
