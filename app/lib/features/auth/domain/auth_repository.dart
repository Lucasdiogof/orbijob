import 'auth_user.dart';

/// Result of a sign-up: with e-mail confirmation on (recommended) there is no session yet.
enum SignUpOutcome { signedIn, confirmationRequired }

abstract class AuthRepository {
  /// False when the build has no Supabase configuration: accounts are off and every action fails with
  /// [AuthFailureKind.unavailable].
  bool get isAvailable;
  AuthUser? get currentUser;
  Stream<AuthUser?> get userChanges;

  /// Emits when the user opened a password-recovery link: the session it creates may only be used to choose a
  /// new password ([updatePassword]).
  Stream<void> get recoveryLinks;
  Future<void> signIn({required String email, required String password});
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String newPassword);
  Future<void> signOut();

  /// Permanently deletes the signed-in account and everything private that belongs to it. The password is asked again (the server
  /// checks it) so a stolen unlocked phone cannot erase an account. The session on this device is NOT ended here (the caller
  /// confirms to the person first, then calls [signOut]); a wrong password fails with [AuthFailureKind.invalidCredentials] and nothing is deleted.
  Future<void> deleteAccount(String password);
}
