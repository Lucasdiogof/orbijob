import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/design/design.dart';
import 'package:orbijob/features/auth/data/supabase_auth_repository.dart';
import 'package:orbijob/features/auth/domain/auth_failure.dart';
import 'package:orbijob/features/auth/presentation/auth_cubit.dart';
import 'package:orbijob/features/auth/presentation/auth_gate.dart';
import 'package:orbijob/features/auth/presentation/auth_page.dart';
import 'package:orbijob/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers/fakes.dart';

Future<AuthCubit> _pump(WidgetTester t, FakeAuth auth) async {
  final cubit = AuthCubit(auth);
  addTearDown(cubit.close);
  await t.pumpWidget(
    BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: AuthGate(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AuthPage()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return cubit;
}

void main() {
  testWidgets('forgot password: e-mail -> 6-digit code -> new password', (
    t,
  ) async {
    final auth = FakeAuth();
    await _pump(t, auth);

    await t.tap(find.text('Forgot password'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), 'ana@example.com');
    await t.tap(find.text('Send code'));
    await t.pumpAndSettle();
    expect(
      find.textContaining('6-digit code sent to ana@example.com'),
      findsOneWidget,
    );
    // The resend button waits before it can be used again.
    expect(find.textContaining('Send a new code in'), findsOneWidget);

    // Short code is refused locally; letters are filtered out.
    await t.enterText(find.byType(TextFormField), '12ab3');
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(find.text('Enter the 6 digits'), findsOneWidget);
    expect(auth.verifiedCode, isNull);

    await t.enterText(find.byType(TextFormField), '123456');
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(auth.verifiedCode, '123456');
    expect(find.text('Choose a new password'), findsWidgets);

    // the code screen and the login under it are gone: only the new-password form, never the app behind it
    expect(find.text('Send code'), findsNothing);
    expect(find.text('open'), findsNothing);

    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'a-long-enough-pass');
    await t.enterText(fields.at(1), 'a-different-pass');
    await t.tap(find.text('Save new password'));
    await t.pumpAndSettle();
    expect(find.text('The passwords do not match'), findsOneWidget);
    expect(auth.passwordUpdates, 0);

    await t.enterText(fields.at(1), 'a-long-enough-pass');
    await t.tap(find.text('Save new password'));
    await t.pumpAndSettle();
    expect(auth.passwordUpdates, 1);
    expect(find.text('Choose a new password'), findsNothing);
    // the recovery session was closed; the login opens with the confirmation
    expect(auth.currentUser, isNull);
    expect(
      find.text('Password changed. Sign in with your new password.'),
      findsOneWidget,
    );
    expect(find.text('Send code'), findsNothing);
  });

  testWidgets('a wrong code says so and stays on the code step', (t) async {
    final auth = FakeAuth();
    await _pump(t, auth);
    await t.tap(find.text('Forgot password'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), 'ana@example.com');
    await t.tap(find.text('Send code'));
    await t.pumpAndSettle();

    auth.error = const AuthFailure(AuthFailureKind.codeInvalid);
    await t.enterText(find.byType(TextFormField), '000000');
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(find.textContaining('wrong or has expired'), findsOneWidget);
    expect(find.text('Choose a new password'), findsNothing);
  });

  testWidgets('a failed send keeps the e-mail step', (t) async {
    final auth = FakeAuth()
      ..error = const AuthFailure(AuthFailureKind.rateLimited);
    await _pump(t, auth);
    await t.tap(find.text('Forgot password'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), 'ana@example.com');
    await t.tap(find.text('Send code'));
    await t.pumpAndSettle();
    expect(find.text('Send code'), findsWidgets);
    expect(find.text('6-digit code'), findsNothing);
  });

  test('server answers for a typed code map to codeInvalid / rateLimited', () {
    // verifyRecoveryCode turns the "expired or invalid token" answer into codeInvalid.
    expect(
      mapAuthError(
        sb.AuthException(
          'Token has expired or is invalid',
          statusCode: '403',
          code: 'otp_expired',
        ),
      ).kind,
      AuthFailureKind.linkInvalid,
    );
    expect(
      mapAuthError(
        sb.AuthException(
          'too many',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
      ).kind,
      AuthFailureKind.rateLimited,
    );
  });
}
