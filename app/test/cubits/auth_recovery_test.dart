import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/auth/domain/auth_failure.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/auth/presentation/auth_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers/fakes.dart';

const a = AuthUser(id: 'a', email: 'a@example.com');

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'a recovery link restores a session that is flagged as recovering',
    () async {
      final repo = FakeAuth();
      final c = AuthCubit(repo);
      repo.recoveryLink(a);
      await tick();
      expect(c.state.signedIn, isTrue);
      expect(c.state.recovering, isTrue);
      await c.close();
    },
  );

  test('choosing a new password ends recovery and says so', () async {
    final repo = FakeAuth();
    final c = AuthCubit(repo);
    repo.recoveryLink(a);
    await tick();
    await c.updatePassword('a-long-enough-pass');
    expect(repo.passwordUpdates, 1);
    expect(c.state.recovering, isFalse);
    expect(c.state.notice, AuthNotice.passwordChanged);
    expect(c.state.signedIn, isTrue);
    await c.close();
  });

  test(
    'a rejected new password keeps the screen open with a typed reason',
    () async {
      final repo = FakeAuth();
      final c = AuthCubit(repo);
      repo.recoveryLink(a);
      await tick();
      repo.error = const sb.AuthApiException(
        'x',
        statusCode: '422',
        code: 'same_password',
      );
      await c.updatePassword('same-as-before');
      expect(c.state.recovering, isTrue);
      expect(c.state.failure, AuthFailureKind.samePassword);
      await c.close();
    },
  );

  test('cancelling recovery signs the temporary session out', () async {
    final repo = FakeAuth();
    final c = AuthCubit(repo);
    repo.recoveryLink(a);
    await tick();
    await c.cancelRecovery();
    expect(c.state.recovering, isFalse);
    expect(c.state.signedIn, isFalse);
    expect(c.state.notice, isNot(AuthNotice.sessionExpired));
    await c.close();
  });

  test(
    'losing the session unasked is reported; signing out on purpose is not',
    () async {
      final repo = FakeAuth()..currentUser = a;
      final c = AuthCubit(repo);
      repo.emit(null);
      await tick();
      expect(c.state.notice, AuthNotice.sessionExpired);
      repo.emit(a);
      await tick();
      await c.signOut();
      expect(c.state.notice, AuthNotice.none);
      await c.close();
    },
  );

  test(
    'an invalid or expired e-mail link surfaces as a typed failure',
    () async {
      final repo = FakeAuth();
      final c = AuthCubit(repo);
      repo.emitError(
        const sb.AuthApiException('x', statusCode: '403', code: 'otp_expired'),
      );
      await tick();
      expect(c.state.failure, AuthFailureKind.linkInvalid);
      await c.close();
    },
  );

  test(
    'switching directly from account A to B does not flag an expired session',
    () async {
      final repo = FakeAuth()..currentUser = a;
      final c = AuthCubit(repo);
      repo.emit(const AuthUser(id: 'b', email: 'b@example.com'));
      await tick();
      expect(c.state.user!.id, 'b');
      expect(c.state.notice, AuthNotice.none);
      await c.close();
    },
  );

  test('a stale link error is cleared once a session exists', () async {
    final repo = FakeAuth();
    final c = AuthCubit(repo);
    repo.emitError(
      const sb.AuthApiException(
        'x',
        statusCode: '400',
        code: 'flow_state_not_found',
      ),
    );
    await tick();
    expect(c.state.failure, AuthFailureKind.linkInvalid);
    repo.emit(a);
    await tick();
    expect(c.state.failure, isNull);
    await c.close();
  });
}
