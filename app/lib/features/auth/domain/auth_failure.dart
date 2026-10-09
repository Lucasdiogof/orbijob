/// Reasons a sign-in/sign-up can fail, independent of the backend. The UI maps each to a localised message;
/// raw server messages are never shown (they can leak internals and are not translated).
enum AuthFailureKind {
  invalidCredentials,
  emailNotConfirmed,
  emailAlreadyRegistered,
  invalidEmail,
  weakPassword,
  rateLimited,
  network,
  unavailable,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.kind);
  final AuthFailureKind kind;
  @override
  String toString() => 'AuthFailure($kind)';
}
