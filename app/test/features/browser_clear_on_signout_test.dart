import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/di/injector.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
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
}
