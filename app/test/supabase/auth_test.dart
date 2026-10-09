import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/auth/data/supabase_auth_repository.dart';
import 'package:orbijob/features/auth/data/unconfigured_auth_repository.dart';
import 'package:orbijob/features/auth/domain/auth_failure.dart';
import 'package:orbijob/features/auth/domain/auth_repository.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/auth/presentation/auth_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'fake_backend.dart';

class _FakeAuth implements AuthRepository {
  final _c = StreamController<AuthUser?>.broadcast();
  Object? error;
  SignUpOutcome outcome = SignUpOutcome.confirmationRequired;
  @override
  bool get isAvailable => true;
  @override
  AuthUser? currentUser;
  @override
  Stream<AuthUser?> get userChanges => _c.stream;
  @override
  Future<void> signIn({required String email, required String password}) async {
    if (error != null) throw error!;
    currentUser = AuthUser(id: 'u', email: email);
    _c.add(currentUser);
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    if (error != null) throw error!;
    return outcome;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (error != null) throw error!;
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    _c.add(null);
  }
}

void main() {
  group('mapAuthError', () {
    AuthFailureKind k(Object e) => mapAuthError(e).kind;
    test('by error code', () {
      expect(
        k(
          const sb.AuthApiException(
            'x',
            statusCode: '400',
            code: 'invalid_credentials',
          ),
        ),
        AuthFailureKind.invalidCredentials,
      );
      expect(
        k(
          const sb.AuthApiException(
            'x',
            statusCode: '400',
            code: 'email_not_confirmed',
          ),
        ),
        AuthFailureKind.emailNotConfirmed,
      );
      expect(
        k(
          const sb.AuthApiException(
            'x',
            statusCode: '422',
            code: 'user_already_exists',
          ),
        ),
        AuthFailureKind.emailAlreadyRegistered,
      );
      expect(
        k(
          const sb.AuthApiException(
            'x',
            statusCode: '422',
            code: 'email_address_invalid',
          ),
        ),
        AuthFailureKind.invalidEmail,
      );
      expect(
        k(
          const sb.AuthApiException(
            'x',
            statusCode: '422',
            code: 'weak_password',
          ),
        ),
        AuthFailureKind.weakPassword,
      );
      expect(
        k(
          const sb.AuthApiException(
            'x',
            statusCode: '429',
            code: 'over_email_send_rate_limit',
          ),
        ),
        AuthFailureKind.rateLimited,
      );
    });
    test('by status, transport and unknown errors', () {
      expect(
        k(const sb.AuthApiException('x', statusCode: '429')),
        AuthFailureKind.rateLimited,
      );
      expect(
        k(const sb.AuthApiException('x', statusCode: '503')),
        AuthFailureKind.unavailable,
      );
      expect(
        k(
          const sb.AuthApiException(
            'Invalid login credentials',
            statusCode: '400',
          ),
        ),
        AuthFailureKind.invalidCredentials,
      );
      expect(
        k(sb.AuthRetryableFetchException(message: 'offline')),
        AuthFailureKind.network,
      );
      expect(k(TimeoutException('t')), AuthFailureKind.network);
      expect(k(StateError('boom')), AuthFailureKind.unknown);
    });
    test('never leaks the server message', () {
      expect(
        mapAuthError(
          const sb.AuthApiException(
            'SECRET internal detail',
            statusCode: '400',
          ),
        ).toString(),
        isNot(contains('SECRET')),
      );
    });
  });

  group('SupabaseAuthRepository over a fake HTTP backend', () {
    test(
      'sign-in posts to the password grant with the publishable key only',
      () async {
        final b = FakeBackend(
          signedIn: false,
          respond: (m, u, body) => (
            200,
            {
              'access_token': 'a.b.c',
              'refresh_token': 'r',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': testUserA,
                'aud': 'authenticated',
                'email': 'a@example.com',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z',
              },
            },
          ),
        );
        final repo = SupabaseAuthRepository(b.client);
        await repo.signIn(email: '  A@Example.com ', password: 'password123');
        final r = b.requests.firstWhere(
          (x) => x.path.endsWith('/auth/v1/token'),
        );
        expect(r.query['grant_type'], 'password');
        expect((r.json as Map)['email'], 'A@Example.com');
        expect(r.request.headers['apikey'], testPublishableKey);
        expect(
          b.requests.every(
            (x) =>
                !(x.request.headers['Authorization'] ?? '').contains('service'),
          ),
          isTrue,
        );
        expect(repo.currentUser?.id, testUserA);
      },
    );

    test('bad credentials become a typed failure', () async {
      final b = FakeBackend(
        signedIn: false,
        respond: (m, u, body) => (
          400,
          {
            'code': 'invalid_credentials',
            'message': 'Invalid login credentials',
          },
        ),
      );
      await expectLater(
        SupabaseAuthRepository(b.client).signIn(email: 'a@b.co', password: 'x'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.kind,
            'kind',
            AuthFailureKind.invalidCredentials,
          ),
        ),
      );
    });

    test(
      'sign-up without a session means e-mail confirmation is required',
      () async {
        final b = FakeBackend(
          signedIn: false,
          respond: (m, u, body) => (
            200,
            {
              'id': testUserA,
              'aud': 'authenticated',
              'email': 'a@b.co',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            },
          ),
        );
        expect(
          await SupabaseAuthRepository(b.client)
              .signUp(email: 'a@b.co', password: 'password123'),
          SignUpOutcome.confirmationRequired,
        );
      },
    );
  });

  group('AuthCubit', () {
    test(
      'unconfigured: not available, actions fail with unavailable',
      () async {
        final c = AuthCubit(UnconfiguredAuthRepository());
        expect(c.state.available, isFalse);
        await c.signIn('a@b.co', 'password123');
        expect(c.state.failure, AuthFailureKind.unavailable);
        expect(c.state.busy, isFalse);
        await c.close();
      },
    );

    test('sign-in updates the user, failure is cleared on retry, sign-out clears the user', () async {
      final repo = _FakeAuth()
        ..error = const AuthFailure(AuthFailureKind.invalidCredentials);
      final c = AuthCubit(repo);
      await c.signIn('a@b.co', 'bad');
      expect(c.state.failure, AuthFailureKind.invalidCredentials);
      expect(c.state.signedIn, isFalse);
      repo.error = null;
      await c.signIn('a@b.co', 'password123');
      await Future<void>.delayed(Duration.zero);
      expect(c.state.failure, isNull);
      expect(c.state.user?.email, 'a@b.co');
      await c.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.signedIn, isFalse);
      await c.close();
    });

    test(
      'a restored session is reflected at start; sign-up reports confirmation',
      () async {
        final repo = _FakeAuth()
          ..currentUser = const AuthUser(id: 'u', email: 'x@y.z');
        final c = AuthCubit(repo);
        expect(c.state.signedIn, isTrue);
        await c.signUp('n@y.z', 'password123');
        expect(c.state.notice, AuthNotice.confirmationSent);
        await c.close();
      },
    );

    test('raw exceptions never reach the state', () async {
      final repo = _FakeAuth()..error = StateError('SECRET');
      final c = AuthCubit(repo);
      await c.signIn('a@b.co', 'password123');
      expect(c.state.failure, AuthFailureKind.unknown);
      await c.close();
    });
  });
}
