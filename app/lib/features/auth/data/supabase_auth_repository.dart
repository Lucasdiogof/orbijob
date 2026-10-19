import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

/// Maps any error thrown by the Supabase client to a backend-independent [AuthFailure]. Pure and tested.
AuthFailure mapAuthError(Object error) {
  if (error is AuthFailure) return error;
  if (error is sb.AuthRetryableFetchException) {
    // The client wraps every 5xx answer in this type too: the server was reached, so it is not "no connection".
    final status = int.tryParse(error.statusCode ?? '');
    return AuthFailure(
      status != null && status >= 500
          ? AuthFailureKind.unavailable
          : AuthFailureKind.network,
    );
  }
  if (error is sb.AuthWeakPasswordException) {
    return const AuthFailure(AuthFailureKind.weakPassword);
  }
  if (error is sb.AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return const AuthFailure(AuthFailureKind.invalidCredentials);
      case 'email_not_confirmed':
        return const AuthFailure(AuthFailureKind.emailNotConfirmed);
      case 'user_already_exists':
      case 'email_exists':
        return const AuthFailure(AuthFailureKind.emailAlreadyRegistered);
      case 'email_address_invalid':
      case 'validation_failed':
        return const AuthFailure(AuthFailureKind.invalidEmail);
      case 'weak_password':
        return const AuthFailure(AuthFailureKind.weakPassword);
      case 'same_password':
        return const AuthFailure(AuthFailureKind.samePassword);
      // An expired or already used e-mail link (confirmation or recovery), or a link opened on another device.
      case 'otp_expired':
      case 'flow_state_not_found':
      case 'flow_state_expired':
      case 'bad_code_verifier':
      case 'bad_oauth_callback':
        return const AuthFailure(AuthFailureKind.linkInvalid);
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
      case 'over_sms_send_rate_limit':
        return const AuthFailure(AuthFailureKind.rateLimited);
    }
    final status = int.tryParse(error.statusCode ?? '');
    if (status == 429) return const AuthFailure(AuthFailureKind.rateLimited);
    if (status != null && status >= 500) {
      return const AuthFailure(AuthFailureKind.unavailable);
    }
    if (status == 400 || status == 401) {
      // Older servers omit `code`; the generic bad-login case is still the most likely meaning.
      if (error.message.toLowerCase().contains('invalid login')) {
        return const AuthFailure(AuthFailureKind.invalidCredentials);
      }
    }
  }
  if (error is TimeoutException || error is http.ClientException) {
    return const AuthFailure(AuthFailureKind.network);
  }
  return const AuthFailure(AuthFailureKind.unknown);
}

class SupabaseAuthRepository implements AuthRepository {
  /// [redirectTo] is where the e-mail links (confirmation, recovery) send the user back; it must also be listed in
  /// the project's Auth "Redirect URLs". Null uses the project's Site URL.
  SupabaseAuthRepository(this._client, {this.redirectTo});
  final sb.SupabaseClient _client;
  final String? redirectTo;

  static AuthUser? _user(sb.User? u) =>
      u == null ? null : AuthUser(id: u.id, email: u.email);

  @override
  bool get isAvailable => true;
  @override
  AuthUser? get currentUser => _user(_client.auth.currentUser);
  @override
  Stream<AuthUser?> get userChanges =>
      _client.auth.onAuthStateChange.map((s) => _user(s.session?.user));
  @override
  Stream<void> get recoveryLinks => _client.auth.onAuthStateChange
      .where((s) => s.event == sb.AuthChangeEvent.passwordRecovery)
      .map((_) {});

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) => _guard(() async {
    final r = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: redirectTo,
    );
    return r.session == null
        ? SignUpOutcome.confirmationRequired
        : SignUpOutcome.signedIn;
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _client.auth.resetPasswordForEmail(email.trim()));

  @override
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) => _guard(() async {
    try {
      await _client.auth.verifyOTP(
        type: sb.OtpType.recovery,
        email: email.trim(),
        token: code.trim(),
      );
    } catch (e) {
      final f = mapAuthError(e);
      // Any "expired / invalid token" answer to a typed code means the code, not a link.
      throw f.kind == AuthFailureKind.linkInvalid
          ? const AuthFailure(AuthFailureKind.codeInvalid)
          : f;
    }
  });

  @override
  Future<void> updatePassword(String newPassword) => _guard(
    () => _client.auth.updateUser(sb.UserAttributes(password: newPassword)),
  );

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  @override
  Future<void> deleteAccount(String password) => _guard(() async {
    try {
      await _client.functions.invoke(
        'account-delete',
        body: {'password': password, 'confirm': true},
      );
    } on sb.FunctionException catch (e) {
      throw mapDeleteAccountStatus(e.status, e.details);
    }
  });
}

/// What a failed `account-delete` call means to the person. Pure and tested.
AuthFailure mapDeleteAccountStatus(int status, Object? details) {
  final code = details is Map ? details['error'] : null;
  if (status == 401 && code == 'reauth_failed') {
    return const AuthFailure(AuthFailureKind.invalidCredentials);
  }
  if (status == 429) return const AuthFailure(AuthFailureKind.rateLimited);
  if (status >= 500) return const AuthFailure(AuthFailureKind.unavailable);
  return const AuthFailure(AuthFailureKind.unknown);
}
