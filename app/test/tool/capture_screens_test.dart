// Generates the OrbiJob 2.0 screenshot gallery in docs/design/orbijob-v2/ from the real app (real fonts, in-memory data).
// It only runs when CAPTURE=1:   CAPTURE=1 flutter test test/tool/capture_screens_test.dart
// Without it every test here is skipped, so the normal suite never writes files.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/app.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/profile/domain/professional_profile.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const _user = AuthUser(id: 'user-a', email: 'maria@example.com');
final _capture = Platform.environment['CAPTURE'] == '1';
final _out = Directory('../docs/design/orbijob-v2');

/// Writes the PNG instead of comparing it (this is a generator, not a regression test).
class _WritingComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async => true;

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    final f = File('${_out.path}/${golden.pathSegments.last}');
    await f.create(recursive: true);
    await f.writeAsBytes(imageBytes);
  }
}

Future<void> _loadIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final f = File(
    '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await loader.load();
}

Future<void> _shot(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  await expectLater(find.byType(OrbiJobApp), matchesGoldenFile('$name.png'));
}

typedef _Setup = Future<void> Function(WidgetTester t);

Future<void> _tapText(WidgetTester t, String label) async {
  await t.tap(find.text(label).first);
  await t.pumpAndSettle();
}

Future<void> _search(WidgetTester t, String term) async {
  await t.enterText(find.byType(TextField).last, term);
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadBrandFonts();
    await _loadIcons();
    goldenFileComparator = _WritingComparator();
    autoUpdateGoldenFiles = true;
  });

  const phone = Size(390, 844);
  const tablet = Size(820, 1180);
  const desktop = Size(1280, 800);

  Future<Fakes> signedInFakes(FakeAuth auth, {bool full = true}) async {
    final fakes = Fakes(auth: auth);
    if (full) {
      final p = await fakes.profiles.save(
        const ProfessionalProfile(
          name: 'Maria Souza',
          countryOfResidence: 'BR',
          skills: ['Pelvic physiotherapy', 'Flutter', 'Patient care'],
          personal: {
            'headline': 'Physiotherapist',
            'summary': 'Women’s health and pelvic floor rehabilitation.',
            'city': 'São Paulo',
          },
        ),
      );
      final r = await fakes.resumes.upload(p.id!, tinyPdf());
      await fakes.profiles.save(p.copyWith(primaryResumeId: r.id));
      await fakes.resumes.upload(p.id!, tinyPdf(3));
    }
    return fakes;
  }

  void gallery(String theme, Brightness b) {
    Future<void> scene(
      String name,
      _Setup body, {
      Size size = phone,
      bool signedIn = false,
      Locale? locale,
      bool fullProfile = true,
    }) async {
      testWidgets('$name ($theme)', (t) async {
        final auth = FakeAuth();
        if (signedIn) auth.currentUser = _user;
        final fakes = await signedInFakes(auth, full: fullProfile);
        await pumpApp(
          t,
          size: size,
          platformBrightness: b,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: fakes,
          locale: locale ?? const Locale('en'),
        );
        await body(t);
      }, skip: !_capture);
    }

    scene('01-home-$theme', (t) => _shot(t, '01-home-$theme'));
    scene('02-explore-$theme', (t) async {
      await _tapText(t, 'Explore');
      await _search(t, 'Pedreiro');
      await _shot(t, '02-explore-$theme');
    });
    scene('03-filters-$theme', (t) async {
      await _tapText(t, 'Explore');
      await _search(t, 'Pedreiro');
      await t.tap(find.byTooltip('Filters'));
      await _shot(t, '03-filters-$theme');
    });
    scene('04-job-detail-$theme', (t) async {
      await _tapText(t, 'Explore');
      await _search(t, 'Pedreiro');
      await t.tap(find.text('Construtora Exemplo'));
      await _shot(t, '04-job-detail-$theme');
    });
    scene('05-favorites-gate-$theme', (t) async {
      await _tapText(t, 'Favorites');
      await _shot(t, '05-favorites-gate-$theme');
    });
    scene('06-applications-gate-$theme', (t) async {
      await _tapText(t, 'Applications');
      await _shot(t, '06-applications-gate-$theme');
    });
    scene('07-favorites-empty-$theme', (t) async {
      await _tapText(t, 'Favorites');
      await _shot(t, '07-favorites-empty-$theme');
    }, signedIn: true);
    scene('08-applications-empty-$theme', (t) async {
      await _tapText(t, 'Applications');
      await _shot(t, '08-applications-empty-$theme');
    }, signedIn: true);
    scene('09-profile-guest-$theme', (t) async {
      await t.tap(find.byTooltip('Profile'));
      await _shot(t, '09-profile-guest-$theme');
    });
    scene('10-login-$theme', (t) async {
      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      await t.tap(find.text('Sign in').first);
      await _shot(t, '10-login-$theme');
    });
    scene('11-signup-$theme', (t) async {
      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      await t.tap(find.text('Create account').first);
      await _shot(t, '11-signup-$theme');
    });
    scene('12-profile-hub-$theme', (t) async {
      await t.tap(find.byTooltip('Profile'));
      await _shot(t, '12-profile-hub-$theme');
    }, signedIn: true);
    scene('13-professional-profile-$theme', (t) async {
      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      await _tapText(t, 'Professional profile');
      await _shot(t, '13-professional-profile-$theme');
    }, signedIn: true);
    scene('14-resumes-$theme', (t) async {
      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      await _tapText(t, 'Résumés');
      await _shot(t, '14-resumes-$theme');
    }, signedIn: true);
    scene('15-settings-$theme', (t) async {
      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      await _tapText(t, 'Settings');
      await _shot(t, '15-settings-$theme');
    }, signedIn: true);
    scene('16-language-$theme', (t) async {
      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      await _tapText(t, 'Settings');
      await _tapText(t, 'Device language');
      await _shot(t, '16-language-$theme');
    }, signedIn: true);
    scene('17-privacy-$theme', (t) async {
      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      await _tapText(t, 'Privacy');
      await _shot(t, '17-privacy-$theme');
    });
    scene(
      '20-tablet-home-$theme',
      (t) => _shot(t, '20-tablet-home-$theme'),
      size: tablet,
    );
    scene('21-desktop-explore-$theme', (t) async {
      await _tapText(t, 'Explore');
      await _search(t, 'Pedreiro');
      await t.tap(find.text('Construtora Exemplo'));
      await _shot(t, '21-desktop-explore-$theme');
    }, size: desktop);
  }

  gallery('light', Brightness.light);
  gallery('dark', Brightness.dark);

  // The same screens in the other two languages (light only).
  for (final (code, explore, profile, settings, device) in [
    ('pt', 'Explorar', 'Perfil', 'Configurações', 'Idioma do aparelho'),
    ('es', 'Explorar', 'Perfil', 'Configuración', 'Idioma del dispositivo'),
  ]) {
    testWidgets('home, explore and language ($code)', (t) async {
      final auth = FakeAuth()..currentUser = _user;
      final fakes = await signedInFakes(auth);
      await pumpApp(
        t,
        size: phone,
        repo: PreviewSearchRepository(),
        auth: auth,
        fakes: fakes,
        locale: Locale(code),
      );
      await _shot(t, '30-home-$code');
      await _tapText(t, explore);
      await _search(t, 'Pedreiro');
      await _shot(t, '31-explore-$code');
      await t.tap(find.byTooltip(profile));
      await t.pumpAndSettle();
      await _shot(t, '32-profile-hub-$code');
      await _tapText(t, settings);
      await _tapText(t, device);
      await _shot(t, '33-language-$code');
    }, skip: !_capture);
  }
}
