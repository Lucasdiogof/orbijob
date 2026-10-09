import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

/// Used when the build has no Supabase configuration (default, tests, previews).
class UnconfiguredAuthRepository implements AuthRepository {
  @override
  bool get isAvailable => false;
  @override
  AuthUser? get currentUser => null;
  @override
  Stream<AuthUser?> get userChanges => const Stream.empty();

  Never _off() => throw const AuthFailure(AuthFailureKind.unavailable);
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async => _off();
  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async => _off();
  @override
  Future<void> sendPasswordReset(String email) async => _off();
  @override
  Future<void> signOut() async {}
}
