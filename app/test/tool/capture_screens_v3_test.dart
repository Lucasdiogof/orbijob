// Generates the OrbiJob 3.0 screenshot gallery in docs/design/orbijob-v3/ from the real app (real fonts, in-memory data).
// It only runs when CAPTURE=1:   CAPTURE=1 flutter test test/tool/capture_screens_v3_test.dart
// Without it every test here is skipped, so the normal suite never writes files.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/app.dart';
import 'package:orbijob/features/applications/domain/application_record.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/compare/compare_cubit.dart';
import 'package:orbijob/features/notifications/domain/notifications_repository.dart';
import 'package:orbijob/features/preferences/domain/user_preferences.dart';
import 'package:orbijob/features/profile/domain/professional_profile.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/job_area.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:orbijob/features/searches/domain/saved_search.dart';
import 'package:orbijob/features/searches/domain/search_spec.dart';
import 'package:orbijob/l10n/app_localizations.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const _user = AuthUser(id: 'user-a', email: 'maria@example.com');
final _capture = Platform.environment['CAPTURE'] == '1';
final _out = Directory('../docs/design/orbijob-v3');

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

Future<void> _tapText(WidgetTester t, String label) async {
  await t.tap(find.text(label).first);
  await t.pumpAndSettle();
}

/// Everything a signed-in person with a little history has, so every 3.0 screen shows real content.
Future<Fakes> _seed(FakeAuth auth, Locale locale) async {
  final fakes = Fakes(auth: auth);
  await fakes.profiles.save(
    const ProfessionalProfile(
      name: 'Maria Souza',
      countryOfResidence: 'BR',
      skills: ['Pelvic physiotherapy', 'Flutter', 'Patient care'],
      languages: [
        ProfileLanguage(code: 'pt', level: 'native'),
        ProfileLanguage(code: 'en', level: 'fluent'),
      ],
      personal: {
        'headline': 'Physiotherapist',
        'summary': 'Women’s health and pelvic floor rehabilitation.',
        'city': 'São Paulo',
      },
      preferences: {'workMode': 'hybrid'},
    ),
  );
  fakes.preferences.stored = const UserPreferences(
    countriesOfInterest: ['DE', 'PT'],
  );
  fakes.savedSearches.rows.addAll([
    SavedSearch(
      id: 's1',
      name: 'Pelvic physio in Germany',
      alertsEnabled: true,
      frequency: AlertFrequency.daily,
      query: const SearchSpec(
        term: 'physiotherapist',
        filters: JobFilters(
          countryCode: 'DE',
          area: JobArea.health,
          workModes: {WorkMode.hybrid, WorkMode.remote},
        ),
      ).toQuery(),
    ),
    SavedSearch(
      id: 's2',
      name: 'Remote Flutter',
      alertsEnabled: true,
      frequency: AlertFrequency.instant,
      query: const SearchSpec(
        term: 'flutter',
        filters: JobFilters(workModes: {WorkMode.remote}),
      ).toQuery(),
    ),
    SavedSearch(
      id: 's3',
      name: 'Nursing in Portugal',
      query: const SearchSpec(
        term: 'nurse',
        filters: JobFilters(countryCode: 'PT'),
      ).toQuery(),
    ),
  ]);
  final now = DateTime.now().toUtc();
  fakes.notifications.rows.addAll([
    AppNotification(
      id: 'r1',
      title: 'Pelvic Health Physiotherapist',
      company: 'Example Health Clinic',
      kind: NotificationKind.interview,
      applicationId: 'a1',
      createdAt: now.subtract(const Duration(minutes: 40)),
    ),
    AppNotification(
      id: 'n1',
      title: 'Beckenboden-Physiotherapeut:in (m/w/d)',
      company: 'Beispiel Klinik GmbH',
      country: 'DE',
      searchIds: const ['s1'],
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: 'n2',
      title: 'Senior Flutter Developer',
      company: 'Example Tech Ltd',
      searchIds: const ['s2'],
      createdAt: now.subtract(const Duration(hours: 9)),
    ),
    AppNotification(
      id: 'n3',
      title: 'Physiotherapist — women’s health',
      company: 'Klinikum Nord',
      country: 'DE',
      searchIds: const ['s1'],
      createdAt: now.subtract(const Duration(days: 2)),
      readAt: now.subtract(const Duration(days: 1)),
    ),
  ]);
  fakes.applications.rows.addAll([
    ApplicationRecord(
      id: 'a1',
      stage: ApplicationStage.interview,
      appliedAt: now.subtract(const Duration(days: 9)),
      interviewAt: DateTime.now().add(const Duration(days: 2, hours: 3)),
      note: 'Ask about the on-call rota.',
      job: const JobPosting(
        source: 'manual',
        externalId: 'a1',
        company: 'Klinikum Nord',
        title: 'Physiotherapist — women’s health',
        originalUrl: 'https://example.com/a1',
      ),
    ),
    ApplicationRecord(
      id: 'a2',
      stage: ApplicationStage.applied,
      appliedAt: now.subtract(const Duration(days: 12)),
      followUpAt: DateTime.now().subtract(const Duration(days: 1)),
      job: const JobPosting(
        source: 'manual',
        externalId: 'a2',
        company: 'Hospital Santa Luzia',
        title: 'Pelvic floor physiotherapist',
        originalUrl: '',
      ),
    ),
    ApplicationRecord(
      id: 'a3',
      stage: ApplicationStage.interested,
      job: const JobPosting(
        source: 'manual',
        externalId: 'a3',
        company: 'Clínica Aurora',
        title: 'Physiotherapist',
        originalUrl: '',
      ),
    ),
    ApplicationRecord(
      id: 'a4',
      stage: ApplicationStage.offer,
      appliedAt: now.subtract(const Duration(days: 30)),
      job: const JobPosting(
        source: 'manual',
        externalId: 'a4',
        company: 'Reha Zentrum',
        title: 'Physiotherapeutin',
        originalUrl: '',
      ),
    ),
    ApplicationRecord(
      id: 'a5',
      stage: ApplicationStage.rejected,
      appliedAt: now.subtract(const Duration(days: 40)),
      job: const JobPosting(
        source: 'manual',
        externalId: 'a5',
        company: 'Med Group',
        title: 'Clinic coordinator',
        originalUrl: '',
      ),
    ),
  ]);
  await fakes.hidden.hide(
    const JobPosting(
      source: 'jobicy',
      externalId: 'h1',
      company: 'Example Staffing',
      title: 'Customer support agent (night shift)',
      originalUrl: 'https://example.com/h1',
    ),
  );
  return fakes;
}

void main() {
  setUpAll(() async {
    if (!_capture) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadBrandFonts();
    await _loadIcons();
    goldenFileComparator = _WritingComparator();
    autoUpdateGoldenFiles = true;
  });

  const phone = Size(390, 844);
  const desktop = Size(1280, 800);

  void gallery(String theme, Brightness b, Locale locale, String suffix) {
    Future<void> scene(
      String name,
      Future<void> Function(WidgetTester t) body, {
      Size size = phone,
    }) async {
      testWidgets('$name ($suffix)', (t) async {
        final auth = FakeAuth()..currentUser = _user;
        final fakes = await _seed(auth, locale);
        await pumpApp(
          t,
          size: size,
          platformBrightness: b,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: fakes,
          locale: locale,
        );
        await body(t);
      }, skip: !_capture);
    }

    final home = 'home-$suffix';
    scene('01-$home', (t) => _shot(t, '01-$home'));
    scene('02-recommendations-$suffix', (t) async {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -420));
      await _shot(t, '02-recommendations-$suffix');
    });
    scene('03-why-$suffix', (t) async {
      final why = find.byIcon(Icons.help_outline_rounded);
      await t.ensureVisible(why.first);
      await t.pumpAndSettle();
      await t.tap(why.first);
      await _shot(t, '03-why-$suffix');
    });
    scene('04-save-search-$suffix', (t) async {
      await _tapText(t, _label(t, 'navExplore'));
      await t.enterText(find.byType(TextField).last, 'physiotherapist');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.bookmark_add_outlined).first);
      await t.pumpAndSettle();
      await t.tap(find.byType(Switch).first);
      await _shot(t, '04-save-search-$suffix');
    });
    scene('12-no-results-suggestions-$suffix', (t) async {
      await _tapText(t, _label(t, 'navExplore'));
      await t.enterText(
        find.byType(TextField).last,
        'fisioterapia pélvica xyz',
      );
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      await _shot(t, '12-no-results-suggestions-$suffix');
    });
    scene('05-saved-searches-$suffix', (t) async {
      await t.tap(find.text(_label(t, 'homeSavedAll')).first);
      await _shot(t, '05-saved-searches-$suffix');
    });
    scene('06-notifications-$suffix', (t) async {
      await t.tap(find.byIcon(Icons.notifications_rounded));
      await _shot(t, '06-notifications-$suffix');
    });
    scene('07-job-menu-$suffix', (t) async {
      await t.tap(find.text(_label(t, 'navExplore')).first);
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.more_vert_rounded).first);
      await _shot(t, '07-job-menu-$suffix');
    });
    scene('08-applications-$suffix', (t) async {
      await t.tap(find.text(_label(t, 'navApplications')).first);
      await _shot(t, '08-applications-$suffix');
    });
    scene('09-application-detail-$suffix', (t) async {
      await t.tap(find.text(_label(t, 'navApplications')).first);
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Physiotherapist —').first);
      await _shot(t, '09-application-detail-$suffix');
    });
  }

  // The compare screen is built from jobs the preview catalogue has; picked through the real cubit, then opened from the bar.
  void compareScenes(String theme, Brightness b) {
    for (final (name, size) in [('phone', phone), ('desktop', desktop)]) {
      testWidgets('11-compare-$name-$theme', (t) async {
        final auth = FakeAuth()..currentUser = _user;
        final fakes = await _seed(auth, const Locale('en'));
        await pumpApp(
          t,
          size: size,
          platformBrightness: b,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: fakes,
          locale: const Locale('en'),
        );
        await t.tap(find.text('Explore').first);
        await t.pumpAndSettle();
        final cubit = t
            .element(find.byType(Scaffold).first)
            .read<CompareCubit>();
        final r = PreviewSearchRepository();
        final jobs = (await r.search('')).jobs.map((s) => s.job).take(3);
        for (final j in jobs) {
          cubit.toggle(j);
        }
        await t.pumpAndSettle();
        await t.tap(find.text('Compare').last);
        await _shot(t, '11-compare-$name-$theme');
      }, skip: !_capture);
    }
  }

  gallery('light', Brightness.light, const Locale('en'), 'en-light');
  gallery('dark', Brightness.dark, const Locale('en'), 'en-dark');
  gallery('light', Brightness.light, const Locale('pt'), 'pt-light');
  gallery('light', Brightness.light, const Locale('es'), 'es-light');
  compareScenes('light', Brightness.light);
  compareScenes('dark', Brightness.dark);
}

/// A label of the app in the language of the running test (by ARB key name).
String _label(WidgetTester t, String key) {
  final l = AppLocalizations.of(t.element(find.byType(Scaffold).first));
  return switch (key) {
    'navExplore' => l.navExplore,
    'navApplications' => l.navApplications,
    'homeSavedAll' => l.homeSavedAll,
    _ => key,
  };
}
