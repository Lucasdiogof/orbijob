// Every important screen, in the three languages, on a narrow phone and with doubled text: nothing may overflow or throw, and
// the main action must stay reachable. (Content correctness is covered elsewhere; this is the layout/i18n safety net.)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/profile/domain/pdf_picker.dart';
import 'package:orbijob/features/profile/domain/professional_profile.dart';
import 'package:orbijob/l10n/app_localizations.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.com');

typedef _Go = Future<void> Function(WidgetTester t, AppLocalizations l);

AppLocalizations _l(WidgetTester t) =>
    AppLocalizations.of(t.element(find.byType(Scaffold).first));

Future<void> _tap(WidgetTester t, String text) async {
  final target = find.text(text);
  // long lists build lazily: scroll the screen's main list until the item exists
  for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
    final lists = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axis == Axis.vertical,
    );
    await t.drag(lists.last, const Offset(0, -300));
    await t.pumpAndSettle();
  }
  await t.ensureVisible(target.first);
  await t.pumpAndSettle();
  await t.tap(target.first);
  await t.pumpAndSettle();
}

Future<void> _profile(WidgetTester t, AppLocalizations l) async {
  await t.tap(find.byTooltip(l.profile));
  await t.pumpAndSettle();
}

Future<void> _job(WidgetTester t, AppLocalizations l) async {
  await _tap(t, l.navExplore);
  await t.enterText(find.byType(TextField).last, 'Pedreiro');
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
  await _tap(t, 'Construtora Exemplo');
}

final _scenes = <String, _Go>{
  'home': (t, l) async {},
  'explore': (t, l) async {
    await _tap(t, l.navExplore);
    await t.enterText(find.byType(TextField).last, 'Pedreiro');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
  },
  'filters': (t, l) async {
    await _tap(t, l.navExplore);
    await t.tap(find.byTooltip(l.filtersButton));
    await t.pumpAndSettle();
  },
  'job detail': _job,
  'application kit': (t, l) async {
    await _job(t, l);
    await _tap(t, l.kitButton);
  },
  'favorites': (t, l) async => _tap(t, l.navFavorites),
  'applications': (t, l) async => _tap(t, l.navApplications),
  'new application': (t, l) async {
    await _tap(t, l.navApplications);
    await _tap(t, l.applicationsAdd);
  },
  'profile hub': _profile,
  'professional profile': (t, l) async {
    await _profile(t, l);
    await _tap(t, l.profileSectionProfessional);
  },
  'profile form': (t, l) async {
    await _profile(t, l);
    await _tap(t, l.profileSectionProfessional);
    await _tap(t, l.profileEditAction);
  },
  'experience form': (t, l) async {
    await _profile(t, l);
    await _tap(t, l.profileSectionProfessional);
    await _tap(t, l.experienceAdd);
  },
  'resumes': (t, l) async {
    await _profile(t, l);
    await _tap(t, l.resumesSection);
  },
  'resume review': (t, l) async {
    await _profile(t, l);
    await _tap(t, l.resumesSection);
    await t.ensureVisible(find.byTooltip(l.resumeMoreActions).first);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip(l.resumeMoreActions).first);
    await t.pumpAndSettle();
    await t.tap(find.text(l.resumeSuggestAction));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    await t.pumpAndSettle();
  },
  'settings': (t, l) async {
    await _profile(t, l);
    await _tap(t, l.settingsTitle);
  },
  'language list': (t, l) async {
    await _profile(t, l);
    await _tap(t, l.settingsTitle);
    await _tap(t, l.languageSystem);
  },
  'privacy': (t, l) async {
    await _profile(t, l);
    await _tap(t, l.privacyTitle);
  },
  'sign in': (t, l) async {
    await t.tap(find.byTooltip(l.profile));
    await t.pumpAndSettle();
    await _tap(t, l.accountSignIn);
  },
};

void main() {
  for (final locale in const ['en', 'pt', 'es']) {
    for (final scale in const [1.0, 2.0]) {
      for (final e in _scenes.entries) {
        final guest = e.key == 'sign in' || e.key == 'favorites';
        testWidgets(
          '$locale · text x$scale · ${e.key}: no overflow, nothing throws',
          (t) async {
            final auth = FakeAuth();
            if (!guest) auth.currentUser = _user;
            final fakes = Fakes(auth: auth);
            if (!guest) {
              final p = await fakes.profiles.save(
                const ProfessionalProfile(
                  name: 'Maria Souza Fernández de la Torre',
                  countryOfResidence: 'BR',
                  skills: ['Fisioterapia pélvica', 'Biofeedback', 'Flutter'],
                  personal: {
                    'headline':
                        'Fisioterapeuta especialista em saúde da mulher',
                    'email': 'maria.souza@example.com',
                    'phone': '+55 11 91234-5678',
                    'city': 'São Paulo',
                  },
                ),
              );
              final r = await fakes.resumes.upload(p.id!, tinyPdf());
              fakes.resumes.contents[r.id] = File(
                'test/fixtures/resumes/cv_pt.pdf',
              ).readAsBytesSync();
            }
            await pumpApp(
              t,
              size: const Size(320, 640),
              textScale: scale,
              repo: PreviewSearchRepository(),
              auth: auth,
              fakes: fakes,
              locale: Locale(locale),
              pdfPicker: FakePdfPicker(
                PickedPdf(name: 'cv.pdf', bytes: tinyPdf()),
              ),
            );
            await e.value(t, _l(t));
            expect(t.takeException(), isNull);
            // the app really is in the requested language
            expect(_l(t).localeName, locale);
          },
        );
      }
    }
  }
}
