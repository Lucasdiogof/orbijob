import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/di/injector.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/browser/browser_data_guard.dart';
import 'package:orbijob/features/browser/browser_engine.dart';
import 'package:orbijob/features/auth/presentation/auth_cubit.dart';

import '../helpers/browser_fakes.dart';
import '../helpers/fakes.dart';

void main() {
  test('sign-out and account deletion clear the in-app browser data', () async {
    await sl.reset();
    final engine = FakeBrowserEngine();
    final repo = FakeAuth()
      ..currentUser = const AuthUser(id: 'u', email: 'a@b.co');
    configureDependencies(
      authRepository: repo,
      browserEngine: engine,
      notificationsRefresh: null,
      connectionRetry: null,
    );
    final cubit = sl<AuthCubit>();
    await cubit.signOut();
    expect(engine.clears, 1);
    await cubit.deleteAccount('secret');
    expect(engine.clears, 2);
    await cubit.close();
    await sl.reset();
  });

  group('session changes without a sign-out', () {
    late FakeBrowserEngine engine;
    late FakeAuth repo;
    setUp(() async {
      await sl.reset();
      engine = FakeBrowserEngine();
      repo = FakeAuth()..currentUser = const AuthUser(id: 'a', email: 'a@b.co');
      configureDependencies(
        authRepository: repo,
        browserEngine: engine,
        notificationsRefresh: null,
        connectionRetry: null,
      );
    });
    tearDown(() => sl.reset());

    test('another account signing in on the same device clears the first account browser data', () async {
      final cubit = sl<AuthCubit>();
      repo.emit(const AuthUser(id: 'b', email: 'b@b.co'));
      await Future<void>.delayed(Duration.zero);
      expect(engine.clears, 1);
      // the same account refreshing its session is not a switch
      repo.emit(const AuthUser(id: 'b', email: 'b@b.co'));
      await Future<void>.delayed(Duration.zero);
      expect(engine.clears, 1);
      await cubit.close();
    });

    test('an expired session clears it too', () async {
      final cubit = sl<AuthCubit>();
      repo.emit(null);
      await Future<void>.delayed(Duration.zero);
      expect(engine.clears, 1);
      await cubit.close();
    });

    test('a browser that cannot clear never blocks the sign-out', () async {
      engine.failClear = true;
      final cubit = sl<AuthCubit>();
      await cubit.signOut();
      expect(cubit.state.failure, isNull);
      expect(repo.currentUser, isNull);
      await cubit.close();
    });
  });

  group('user A then user B on the same device', () {
    late FakeBrowserEngine engine;
    late FakeAuth repo;
    setUp(() async {
      await sl.reset();
      engine = FakeBrowserEngine();
      repo = FakeAuth()..currentUser = const AuthUser(id: 'a', email: 'a@b.co');
      configureDependencies(
        authRepository: repo,
        browserEngine: engine,
        notificationsRefresh: null,
        connectionRetry: null,
      );
    });
    tearDown(() => sl.reset());

    test('B never meets the sessions A left in the browser', () async {
      final cubit = sl<AuthCubit>();
      final guard = sl<BrowserDataGuard>();
      engine.cookies.add('portal-session-of-A');
      repo.emit(
        const AuthUser(id: 'b', email: 'b@b.co'),
      ); // no sign-out in between
      await Future<void>.delayed(Duration.zero);
      expect(engine.cookies, isEmpty);
      expect(guard.dirty, isFalse);
      expect(await guard.ensureClean(), isTrue);
      expect(engine.clears, 1); // nothing pending: no second run
      await cubit.close();
    });

    test('a partial failure leaves the dirty flag up and the browser closed until a clean-up passes', () async {
      final cubit = sl<AuthCubit>();
      final guard = sl<BrowserDataGuard>();
      engine
        ..cookies.add('portal-session-of-A')
        ..clearResult = false; // some step failed
      repo.emit(const AuthUser(id: 'b', email: 'b@b.co'));
      await Future<void>.delayed(Duration.zero);
      expect(guard.dirty, isTrue);
      expect(engine.cookies, isNotEmpty);
      expect(
        await guard.ensureClean(),
        isFalse,
      ); // forced again, failed again: the page must not open inside
      expect(guard.dirty, isTrue);
      engine.clearResult = true; // the platform recovers
      expect(await guard.ensureClean(), isTrue);
      expect(guard.dirty, isFalse);
      expect(engine.cookies, isEmpty);
      await cubit.close();
    });

    test(
      'an engine that throws leaves the flag up until a later clean-up passes',
      () async {
        final guard = sl<BrowserDataGuard>();
        engine.failClear = true;
        expect(await guard.clear(), isFalse);
        expect(guard.dirty, isTrue);
        engine.failClear = false;
        expect(await guard.ensureClean(), isTrue);
        expect(guard.dirty, isFalse);
      },
    );
  });

  test(
    'runCleanupSteps: a failing or hanging step does not stop the others',
    () async {
      final log = <String>[];
      final failed = await runCleanupSteps([
        () async => log.add('cookies'),
        () async => throw StateError('cache'),
        () => Completer<void>().future, // never completes
        () async => log.add('storage'),
      ], timeout: const Duration(milliseconds: 20));
      expect(log, ['cookies', 'storage']);
      expect(failed, 2);
    },
  );
}
