// Accessibility guidelines (contrast, tap-target size, labelled targets) on the screens added in OrbiJob 2.0, light and dark.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/orbi/orbi.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/profile/domain/professional_profile.dart';
import 'package:orbijob/l10n/app_localizations.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.com');

AppLocalizations _l(WidgetTester t) =>
    AppLocalizations.of(t.element(find.byType(Scaffold).first));

Future<void> _tap(WidgetTester t, String text) async {
  await t.tap(find.text(text).first);
  await t.pumpAndSettle();
}

Future<void> _check(WidgetTester t) async {
  await expectLater(t, meetsGuideline(textContrastGuideline));
  await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(t, meetsGuideline(androidTapTargetGuideline));
}

final _scenes = <String, Future<void> Function(WidgetTester, AppLocalizations)>{
  'profile hub': (t, l) async {
    await t.tap(find.byTooltip(l.profile));
    await t.pumpAndSettle();
  },
  'professional profile': (t, l) async {
    await t.tap(find.byTooltip(l.profile));
    await t.pumpAndSettle();
    await _tap(t, l.profileSectionProfessional);
  },
  'profile form': (t, l) async {
    await t.tap(find.byTooltip(l.profile));
    await t.pumpAndSettle();
    await _tap(t, l.profileSectionProfessional);
    await _tap(t, l.profileEditAction);
  },
  'resumes': (t, l) async {
    await t.tap(find.byTooltip(l.profile));
    await t.pumpAndSettle();
    await _tap(t, l.resumesSection);
  },
  'resume review': (t, l) async {
    await t.tap(find.byTooltip(l.profile));
    await t.pumpAndSettle();
    await _tap(t, l.resumesSection);
    await t.tap(find.byTooltip(l.resumeMoreActions).first);
    await t.pumpAndSettle();
    await t.tap(find.text(l.resumeSuggestAction));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    await t.pumpAndSettle();
  },
  'settings': (t, l) async {
    await t.tap(find.byTooltip(l.profile));
    await t.pumpAndSettle();
    await _tap(t, l.settingsTitle);
  },
  'privacy': (t, l) async {
    await t.tap(find.byTooltip(l.profile));
    await t.pumpAndSettle();
    await _tap(t, l.privacyTitle);
  },
  'filters sheet': (t, l) async {
    await _tap(t, l.navExplore);
    await t.tap(find.byTooltip(l.filtersButton));
    await t.pumpAndSettle();
  },
  'job detail': (t, l) async {
    await _tap(t, l.navExplore);
    await t.enterText(find.byType(TextField).last, 'Pedreiro');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    await _tap(t, 'Construtora Exemplo');
  },
  'application kit': (t, l) async {
    await _tap(t, l.navExplore);
    await t.enterText(find.byType(TextField).last, 'Pedreiro');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    await _tap(t, 'Construtora Exemplo');
    await _tap(t, l.kitButton);
  },
  'sign in': (t, l) async {
    await t.tap(find.byTooltip(l.profile));
    await t.pumpAndSettle();
    await t.tap(find.text(l.accountSignIn).last);
    await t.pumpAndSettle();
  },
  'sign in · recovery': (t, l) async {
    await t.tap(find.byTooltip(l.profile));
    await t.pumpAndSettle();
    await t.tap(find.text(l.accountSignIn).last);
    await t.pumpAndSettle();
    await t.tap(find.text(l.authForgotPassword));
    await t.pumpAndSettle();
  },
  'sign in · recovery code': (t, l) async {
    await t.tap(find.byTooltip(l.profile));
    await t.pumpAndSettle();
    await t.tap(find.text(l.accountSignIn).last);
    await t.pumpAndSettle();
    await t.tap(find.text(l.authForgotPassword));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, 'maria@example.com');
    await t.tap(find.text(l.authRecoverySendCode));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
  },
  'delete account': (t, l) async {
    await t.tap(find.byTooltip(l.profile));
    await t.pumpAndSettle();
    await _tap(t, l.privacyTitle);
    final del = find.widgetWithText(OrbiSecondaryButton, l.pdDeleteTitle);
    await t.scrollUntilVisible(
      del,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await t.tap(del);
    await t.pumpAndSettle();
  },
  'new application': (t, l) async {
    await _tap(t, l.navApplications);
    await _tap(t, l.applicationsAdd);
  },
};

void main() {
  for (final b in Brightness.values) {
    for (final e in _scenes.entries) {
      testWidgets('${e.key} (${b.name}): contrast, labels, tap targets', (
        t,
      ) async {
        final h = t.ensureSemantics();
        final auth = FakeAuth();
        if (!e.key.startsWith('sign in')) auth.currentUser = _user;
        final fakes = Fakes(auth: auth);
        if (!e.key.startsWith('sign in')) {
          final p = await fakes.profiles.save(
            const ProfessionalProfile(
              name: 'Maria Souza',
              countryOfResidence: 'BR',
              skills: ['Biofeedback', 'Flutter'],
              personal: {
                'headline': 'Physiotherapist',
                'email': 'maria@example.com',
              },
            ),
          );
          final r = await fakes.resumes.upload(p.id!, tinyPdf());
          fakes.resumes.contents[r.id] = File('test/fixtures/resumes/cv_en.pdf')
              .readAsBytesSync();
        }
        await pumpApp(
          t,
          size: const Size(390, 1600),
          platformBrightness: b,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: fakes,
        );
        await e.value(t, _l(t));
        await _check(t);
        h.dispose();
      });
    }
  }
}
