import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/design/design.dart';
import 'package:orbijob/core/orbi/orbi.dart';
import 'package:orbijob/features/auth/domain/legal_consent.dart';
import 'package:orbijob/features/auth/presentation/auth_cubit.dart';
import 'package:orbijob/features/auth/presentation/auth_page.dart';
import 'package:orbijob/features/privacy/presentation/your_data_section.dart';
import 'package:orbijob/l10n/app_localizations.dart';

import '../helpers/fakes.dart';

Future<void> _pump(WidgetTester t, FakeAuth auth, Locale locale) async {
  t.view.physicalSize = const Size(800, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final cubit = AuthCubit(auth);
  addTearDown(cubit.close);
  await t.pumpWidget(
    BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const AuthPage(startAsSignUp: true),
      ),
    ),
  );
}

Finder submit(AppLocalizations l) =>
    find.widgetWithText(OrbiPrimaryButton, l.authSignUpAction);

void main() {
  test('versions match the published dates and the links the legal pages', () {
    expect(termsVersion, '2026-10-14');
    expect(privacyVersion, '2026-10-20');
    expect(orbiTermsUrl, 'https://lucksrei.com/projects/orbijob/terms/');
    expect(orbiPrivacyUrl, 'https://lucksrei.com/projects/orbijob/privacy/');
    final d = legalConsentData(DateTime.utc(2026, 10, 21, 3, 4, 5));
    expect(d, {
      'terms_version': '2026-10-14',
      'privacy_version': '2026-10-20',
      'accepted_at': '2026-10-21T03:04:05.000Z',
    });
  });

  for (final loc in ['en', 'pt', 'es']) {
    testWidgets('sign-up is blocked until the consent box is ticked ($loc)', (
      t,
    ) async {
      final auth = FakeAuth();
      await _pump(t, auth, Locale(loc));
      final l = await AppLocalizations.delegate.load(Locale(loc));
      final form = find.byType(TextFormField);
      await t.enterText(form.at(0), 'ana@example.com');
      await t.enterText(form.at(1), 'password123');
      expect(find.text(l.authConsentLabel), findsOneWidget);
      expect(find.text(l.authConsentTermsLink), findsOneWidget);
      expect(find.text(l.authConsentPrivacyLink), findsOneWidget);

      await t.ensureVisible(submit(l));
      await t.tap(submit(l), warnIfMissed: false);
      await t.pump();
      expect(auth.lastSignUpData, isNull);

      await t.tap(find.byKey(const ValueKey('auth-consent')));
      await t.pump();
      await t.ensureVisible(submit(l));
      await t.tap(submit(l));
      await t.pumpAndSettle();
      expect(auth.lastSignUpData?['terms_version'], termsVersion);
      expect(auth.lastSignUpData?['privacy_version'], privacyVersion);
      expect(auth.lastSignUpData?['accepted_at'], isA<String>());
      // the confirmation-by-e-mail notice still appears (flow unchanged)
      expect(find.text(l.authConfirmationSent), findsOneWidget);
    });
  }

  testWidgets('the legal links are tappable and never throw', (t) async {
    await _pump(t, FakeAuth(), const Locale('en'));
    await t.ensureVisible(find.byKey(const ValueKey('auth-terms-link')));
    await t.tap(find.byKey(const ValueKey('auth-terms-link')));
    await t.tap(find.byKey(const ValueKey('auth-privacy-link')));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
