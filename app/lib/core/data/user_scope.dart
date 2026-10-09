import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown by data sources when an operation needs a signed-in user.
class NotSignedInException implements Exception {
  const NotSignedInException();
  @override
  String toString() => 'NotSignedInException';
}

/// The current user's id, or [NotSignedInException]. Every row the app writes carries this id; Row Level
/// Security on the server is what actually enforces ownership, this only avoids pointless requests.
String requireUserId(SupabaseClient client) {
  final id = client.auth.currentUser?.id;
  if (id == null) throw const NotSignedInException();
  return id;
}
