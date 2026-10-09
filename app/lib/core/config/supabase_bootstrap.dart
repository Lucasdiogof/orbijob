import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'secure_session_storage.dart';

/// Initialises Supabase with the PUBLIC key only, or returns null when accounts are not configured.
/// Throws [StateError] for an unsafe configuration (e.g. a secret key), so a mistake fails loudly at start-up.
Future<SupabaseClient?> initSupabase(AppConfig config) async {
  final problem = config.validate();
  if (problem != null) throw StateError(problem);
  if (!config.hasSupabase) return null;
  await Supabase.initialize(
    url: config.supabaseUrl.trim(),
    publishableKey: config.supabasePublishableKey.trim(),
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      localStorage: kIsWeb ? null : SecureSessionStorage(),
      pkceAsyncStorage: kIsWeb ? null : SecurePkceStorage(),
    ),
  );
  return Supabase.instance.client;
}
