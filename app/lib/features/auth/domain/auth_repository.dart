import 'auth_user.dart';

/// Result of a sign-up: with e-mail confirmation on (recommended) there is no session yet.
enum SignUpOutcome { signedIn, confirmationRequired }

abstract class AuthRepository {
  /// False when the build has no Supabase configuration: accounts are off and every action fails with
  /// [AuthFailureKind.unavailable].
  bool get isAvailable;
  AuthUser? get currentUser;
  Stream<AuthUser?> get userChanges;
  Future<void> signIn({required String email, required String password});
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}
