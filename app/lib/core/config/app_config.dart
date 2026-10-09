import 'dart:convert';

/// Build-time configuration, injected with `--dart-define` (see `.env.example` and docs/SUPABASE_SETUP.md).
/// Only PUBLIC values belong here: the project URL and the publishable (formerly "anon") key. A secret or
/// service_role key must never reach the app, so such keys are rejected at start-up.
class AppConfig {
  const AppConfig({
    this.supabaseUrl = '',
    this.supabasePublishableKey = '',
    this.authRedirectUrl = '',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    authRedirectUrl: String.fromEnvironment('AUTH_REDIRECT_URL'),
  );

  final String supabaseUrl;
  final String supabasePublishableKey;

  /// Where e-mail links (confirmation, password recovery) return to: the web origin, or the app's custom scheme
  /// (`com.lucksrei.orbijob://auth-callback`). Optional here, but it must be listed in the Supabase project's
  /// Auth > URL Configuration > Redirect URLs, or the links fall back to the Site URL.
  final String authRedirectUrl;

  /// The redirect to use, or null when none is configured.
  String? get redirectTo {
    final v = authRedirectUrl.trim();
    return v.isEmpty ? null : v;
  }

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
    final redirect = authRedirectUrl.trim();
    if (redirect.isNotEmpty) {
      final r = Uri.tryParse(redirect);
      final localRedirect =
          r != null && (r.host == 'localhost' || r.host == '127.0.0.1');
      final okScheme =
          r != null &&
          r.scheme.isNotEmpty &&
          r.scheme != 'javascript' &&
          r.scheme != 'data' &&
          r.scheme != 'file' &&
          (r.scheme != 'http' || localRedirect);
      if (!okScheme) {
        return 'AUTH_REDIRECT_URL must be an https URL (or a custom app scheme)';
      }
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
