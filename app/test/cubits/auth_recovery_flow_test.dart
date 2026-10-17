import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/auth/domain/auth_failure.dart';
import 'package:orbijob/features/auth/presentation/auth_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers/fakes.dart';

/// Regression net for the recovery bugs found in manual tests (2026-10-14): the code accepted the session and the app went to the Home
/// without asking for a new password, and a later account deletion brought the stale new-password form back.
class MemoryMarker implements RecoveryMarker {
  String? value;
  @override
  String? read() => value;
  @override
  Future<void> write(String? userId) async => value = userId;
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  for (final late in [false, true]) {
    final order = late
        ? 'SIGNED_IN after verifyOTP returns'
        : 'SIGNED_IN during verifyOTP';
    group('valid code ($order)', () {
      test(
        '1-2: the recovery session is never a sign-in; the new-password step is pending',
        () async {
          final repo = FakeAuth()..signedInAfterVerify = late;
          final marker = MemoryMarker();
          final c = AuthCubit(repo, recoveryMarker: marker);
          final seen = <AuthState>[];
          final sub = c.stream.listen(seen.add);
          await c.verifyRecoveryCode('ana@example.com', '123456');
          await tick();
          expect(c.state.recovering, isTrue);
          expect(c.state.signedIn, isFalse);
          expect(c.state.accountUser, isNull);
          // at no moment did the app consider the person signed in (that is what showed the Home)
          expect(seen.where((s) => s.signedIn), isEmpty);
          expect(marker.value, 'user-ana');
          await sub.cancel();
          await c.close();
        },
      );

      test(
        '3: saving the new password closes the temporary session and ends at the login with a confirmation',
        () async {
          final repo = FakeAuth()..signedInAfterVerify = late;
          final marker = MemoryMarker();
          final c = AuthCubit(repo, recoveryMarker: marker);
          await c.verifyRecoveryCode('ana@example.com', '123456');
          await tick();
          await c.updatePassword('a-new-long-password');
          await tick();
          expect(repo.passwordUpdates, 1);
          expect(c.state.recovering, isFalse);
          expect(c.state.user, isNull);
          expect(c.state.notice, AuthNotice.passwordChanged);
          expect(marker.value, isNull);
        },
      );
    });
  }

  test(
    'updateUser runs while the recovery session is still valid (no sign-out before it)',
    () async {
      final repo = FakeAuth();
      final c = AuthCubit(repo);
      await c.verifyRecoveryCode('ana@example.com', '123456');
      var signedInWhenUpdating = false;
      repo.onUpdatePassword = () =>
          signedInWhenUpdating = repo.currentUser != null;
      await c.updatePassword('a-new-long-password');
      expect(signedInWhenUpdating, isTrue);
    },
  );

  test(
    '4: a wrong or expired code says so, keeps nobody signed in and no recovery pending',
    () async {
      final repo = FakeAuth()
        ..error = const sb.AuthApiException(
          'Token has expired or is invalid',
          statusCode: '403',
          code: 'otp_expired',
        );
      final marker = MemoryMarker();
      final c = AuthCubit(repo, recoveryMarker: marker);
      await c.verifyRecoveryCode('ana@example.com', '000000');
      expect(c.state.failure, isNotNull);
      expect(c.state.recovering, isFalse);
      expect(c.state.user, isNull);
      expect(marker.value, isNull);
    },
  );

  test(
    '5: signing out during the recovery clears it (and its marker)',
    () async {
      final repo = FakeAuth();
      final marker = MemoryMarker();
      final c = AuthCubit(repo, recoveryMarker: marker);
      await c.verifyRecoveryCode('ana@example.com', '123456');
      await c.signOut();
      expect(c.state.recovering, isFalse);
      expect(c.state.user, isNull);
      expect(marker.value, isNull);
    },
  );

  test(
    '6-7: a deletion after an unfinished recovery never brings the recovery back, whatever arrives late',
    () async {
      final repo = FakeAuth();
      final marker = MemoryMarker();
      final c = AuthCubit(repo, recoveryMarker: marker);
      await c.verifyRecoveryCode('ana@example.com', '123456');
      await c.cancelRecovery();
      await repo.signIn(email: 'ana@example.com', password: 'pw');
      await tick();
      final states = <AuthState>[];
      final sub = c.stream.listen(states.add);
      await c.deleteAccount('pw');
      await c.finishAccountDeletion();
      repo.emit(null); // a late event of the old session
      await tick();
      expect(states.where((s) => s.recovering), isEmpty);
      expect(c.state.recovering, isFalse);
      expect(marker.value, isNull);
      await sub.cancel();
    },
  );

  test(
    '6: deleting from a session that was a recovery ends the recovery first',
    () async {
      final repo = FakeAuth();
      final c = AuthCubit(repo, recoveryMarker: MemoryMarker());
      await c.verifyRecoveryCode('ana@example.com', '123456');
      final states = <AuthState>[];
      final sub = c.stream.listen(states.add);
      await c.deleteAccount('pw');
      await c.finishAccountDeletion();
      expect(states.where((s) => s.recovering), isEmpty);
      expect(c.state.recovering, isFalse);
      await sub.cancel();
    },
  );

  test('another account signing in ends a recovery of someone else', () async {
    final repo = FakeAuth();
    final c = AuthCubit(repo, recoveryMarker: MemoryMarker());
    await c.verifyRecoveryCode('ana@example.com', '123456');
    await repo.signIn(email: 'bia@example.com', password: 'pw');
    await tick();
    expect(c.state.recovering, isFalse);
    expect(c.state.signedIn, isTrue);
  });

  test(
    '8-9: any non-empty current password may be tried; a wrong one is answered by the server',
    () async {
      final repo = FakeAuth()..accountPassword = 'abc';
      final c = AuthCubit(repo);
      await repo.signIn(email: 'ana@example.com', password: 'abc');
      await tick();
      await c.deleteAccount('xyz');
      expect(c.state.failure, AuthFailureKind.invalidCredentials);
      expect(repo.deletedWith, isNull);
      c.dismissMessage();
      await c.deleteAccount(
        'abc',
      ); // a short CURRENT password is still a password
      expect(c.state.failure, isNull);
      expect(repo.deletedWith, 'abc');
    },
  );

  test(
    '11: a restart in the middle of the recovery returns to the new-password step, not to the Home',
    () async {
      final repo = FakeAuth();
      final marker = MemoryMarker();
      final first = AuthCubit(repo, recoveryMarker: marker);
      await first.verifyRecoveryCode('ana@example.com', '123456');
      await first.close();
      // the app is closed and opened again: Supabase restores the recovery session
      final again = AuthCubit(repo, recoveryMarker: marker);
      expect(again.state.recovering, isTrue);
      expect(again.state.signedIn, isFalse);
      // a marker of another account is ignored
      marker.value = 'someone-else';
      final other = AuthCubit(repo, recoveryMarker: marker);
      expect(other.state.recovering, isFalse);
      expect(other.state.signedIn, isTrue);
    },
  );
}
