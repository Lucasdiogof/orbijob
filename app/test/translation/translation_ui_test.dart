import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:orbijob/features/search/domain/search_repository.dart';
import 'package:orbijob/features/translation/translation_cache.dart';
import 'package:orbijob/features/translation/translation_service.dart';

import '../helpers/harness.dart';
import '../helpers/translation_fakes.dart';

/// Answers every search with the given listings.
class ListRepo implements SearchRepository {
  ListRepo(this.jobs);
  final List<JobPosting> jobs;
  @override
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  }) async => SearchResult(
    jobs: [for (final j in jobs) ScoredJob(j)],
    hasIntegratedSource: true,
  );
}

/// Real listings taken from the live catalogue (German, Swedish, Traditional Chinese, and English ones from "DE"/"FR").
List<JobPosting> realJobs() {
  final raw = (jsonDecode(
    File('test/fixtures/jobs/real_listings.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();
  var i = 0;
  return [
    for (final r in raw)
      JobPosting(
        source: 'test',
        externalId: 'r${i++}',
        company: (r['company'] as String).isEmpty
            ? 'Example Co'
            : r['company'] as String,
        title: r['title'] as String,
        originalUrl: 'https://example.invalid/$i',
        country: r['country'] as String?,
        description: r['description'] as String?,
        sourceName: 'Example source',
      ),
  ];
}

JobPosting job(
  String id,
  String title, {
  String? description,
  String company = 'ACME GmbH',
  String? language,
}) => JobPosting(
  source: 'test',
  externalId: id,
  company: company,
  title: title,
  originalUrl: 'https://example.invalid/$id',
  description: description,
  language: language,
  sourceName: 'Example source',
);

const germanText =
    'Wir suchen eine erfahrene Pflegefachkraft für unser Team in Hamburg, die gerne mit Menschen arbeitet.\n'
    'Ihre Aufgaben:\n'
    '- Pflege und Betreuung der Patienten\n'
    '- Dokumentation der Pflegeleistungen\n'
    'Wir bieten 45.000 € Jahresgehalt, Ref. KR-2291, weitere Infos unter https://example.de/jobs oder hr@acme.de.\n'
    'Voraussetzung: Anerkennung als Pflegefachkraft, Deutsch B2, Führerschein Klasse B.';

Future<void> _openFirstJob(WidgetTester t) async {
  await t.tap(find.text('Explore'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField).last, 'x');
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
}

void main() {
  final german = job(
    'de1',
    'Pflegefachkraft (m/w/d) für unser Team',
    description: germanText,
  );
  final english = job(
    'en1',
    'Senior Backend Engineer',
    description: 'We are looking for an experienced engineer to join our team and work on our platform with the rest of the group.',
    company: 'Globex',
  );

  testWidgets(
    'titles in lists are translated into the interface language, with a mark; company and original data stay',
    (t) async {
      final e = FakeEngine();
      await pumpApp(t, repo: ListRepo([german, english]), translationEngine: e);
      await _openFirstJob(t);
      expect(
        find.text(
          '[en] Pflegefachkraft ⟦0⟧ für unser Team'.replaceAll(
            '⟦0⟧',
            '(m/w/d)',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text('ACME GmbH'),
        findsOneWidget,
        reason: 'the company name is never translated',
      );
      expect(
        find.text('Senior Backend Engineer'),
        findsOneWidget,
        reason: 'already in English: untouched',
      );
      expect(find.byIcon(Icons.translate_rounded), findsWidgets);
      expect(
        e.seen.any((s) => s.contains('Senior Backend')),
        isFalse,
        reason: 'no engine call for text in the interface language',
      );
      expect(
        e.seen.any((s) => s.contains('(m/w/d)')),
        isFalse,
        reason: 'the gender marker is protected',
      );
    },
  );

  testWidgets(
    'the list never waits for the translation: originals first, translation when ready',
    (t) async {
      final e = FakeEngine(latency: const Duration(milliseconds: 400));
      await pumpApp(
        t,
        repo: ListRepo([german]),
        translationEngine: e,
        settle: false,
      );
      await t.tap(find.text('Explore'));
      await t.pump(const Duration(milliseconds: 100));
      await t.enterText(find.byType(TextField).last, 'x');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pump(const Duration(milliseconds: 120));
      expect(
        find.text('Pflegefachkraft (m/w/d) für unser Team'),
        findsOneWidget,
        reason: 'the original is already on screen',
      );
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(find.textContaining('[en] Pflegefachkraft'), findsOneWidget);
    },
  );

  testWidgets(
    'no download is started by a list: without language data titles stay original',
    (t) async {
      final e = FakeEngine(ready: false);
      await pumpApp(t, repo: ListRepo([german]), translationEngine: e);
      await _openFirstJob(t);
      expect(
        find.text('Pflegefachkraft (m/w/d) für unser Team'),
        findsOneWidget,
      );
      expect(e.prepared, 0);
      expect(e.seen, isEmpty);
    },
  );

  testWidgets(
    'detail: translation, automatic-translation note, protected parts exact, switch to the original and back',
    (t) async {
      final e = FakeEngine();
      await pumpApp(
        t,
        size: const Size(430, 3000),
        repo: ListRepo([german]),
        translationEngine: e,
      );
      await _openFirstJob(t);
      await t.tap(find.textContaining('[en] Pflegefachkraft'));
      await t.pumpAndSettle();
      expect(
        find.text(
          'Translated from Deutsch automatically. It may contain errors.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('[en] Ihre Aufgaben:'), findsOneWidget);
      expect(find.textContaining('45.000 €'), findsOneWidget);
      expect(find.textContaining('KR-2291'), findsOneWidget);
      expect(find.textContaining('https://example.de/jobs'), findsOneWidget);
      expect(find.textContaining('hr@acme.de'), findsOneWidget);
      expect(find.textContaining('B2'), findsOneWidget);
      // bullets keep their prefix
      expect(
        find.textContaining('- [en] Pflege und Betreuung der Patienten'),
        findsOneWidget,
      );

      await t.tap(find.text('Show original'));
      await t.pumpAndSettle();
      expect(find.text('Original text (Deutsch)'), findsOneWidget);
      expect(find.textContaining('Ihre Aufgaben:'), findsOneWidget);
      expect(find.textContaining('[en] Ihre Aufgaben:'), findsNothing);
      expect(find.text('Pflegefachkraft (m/w/d) für unser Team'), findsWidgets);

      await t.tap(find.text('Show translation'));
      await t.pumpAndSettle();
      expect(find.textContaining('[en] Ihre Aufgaben:'), findsOneWidget);
    },
  );

  testWidgets(
    'a listing in the interface language shows no translation UI and costs no engine call',
    (t) async {
      final e = FakeEngine();
      await pumpApp(
        t,
        size: const Size(430, 3000),
        repo: ListRepo([english]),
        translationEngine: e,
      );
      await _openFirstJob(t);
      await t.tap(find.text('Senior Backend Engineer'));
      await t.pumpAndSettle();
      expect(find.textContaining('automatically'), findsNothing);
      expect(find.text('Show original'), findsNothing);
      expect(e.seen, isEmpty);
    },
  );

  testWidgets(
    'language change: the displayed translation follows at once (cached work is reused)',
    (t) async {
      final e = FakeEngine();
      await pumpApp(t, repo: ListRepo([german]), translationEngine: e);
      await _openFirstJob(t);
      expect(find.textContaining('[en] Pflegefachkraft'), findsOneWidget);
      // switch the app language to Portuguese in the settings
      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      await t.tap(find.text('Settings'));
      await t.pumpAndSettle();
      await t.tap(find.text('Device language'));
      await t.pumpAndSettle();
      await t.tap(find.text('Português'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Voltar'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Voltar'));
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      expect(find.textContaining('[pt] Pflegefachkraft'), findsOneWidget);
      expect(
        find.textContaining('[en] Pflegefachkraft'),
        findsNothing,
        reason: 'no title of the old language stays on screen',
      );
    },
  );

  testWidgets(
    'detail offers the download when language data is missing, and translates after it',
    (t) async {
      final e = FakeEngine(ready: false);
      await pumpApp(
        t,
        size: const Size(430, 3000),
        repo: ListRepo([german]),
        translationEngine: e,
      );
      await _openFirstJob(t);
      await t.tap(find.text('Pflegefachkraft (m/w/d) für unser Team'));
      await t.pumpAndSettle();
      expect(find.text('Translate this listing?'), findsOneWidget);
      expect(find.textContaining('about 30 MB'), findsOneWidget);
      expect(find.textContaining('[en] Ihre Aufgaben:'), findsNothing);
      await t.tap(find.text('Download and translate'));
      await t.pumpAndSettle();
      expect(e.prepared, 1);
      expect(find.textContaining('[en] Ihre Aufgaben:'), findsOneWidget);
    },
  );

  testWidgets(
    'no engine on this device: a clear note, the original stays, nothing is faked',
    (t) async {
      await pumpApp(
        t,
        size: const Size(430, 3000),
        repo: ListRepo([german]),
      ); // desktop test host: no engine
      await _openFirstJob(t);
      await t.tap(find.text('Pflegefachkraft (m/w/d) für unser Team'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('is not available on this device'),
        findsOneWidget,
      );
      expect(find.textContaining('Ihre Aufgaben:'), findsOneWidget);
    },
  );

  testWidgets(
    'an engine failure says so, keeps the original, and "try again" works',
    (t) async {
      final e = FakeEngine()..failWith = StateError('boom');
      await pumpApp(
        t,
        size: const Size(430, 3000),
        repo: ListRepo([german]),
        translationEngine: e,
      );
      await _openFirstJob(t);
      await t.tap(find.text('Pflegefachkraft (m/w/d) für unser Team'));
      await t.pumpAndSettle();
      expect(
        find.text('Could not translate this listing. Showing the original.'),
        findsOneWidget,
      );
      expect(find.textContaining('Ihre Aufgaben:'), findsOneWidget);
      e.failWith = null;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.textContaining('[en] Ihre Aufgaben:'), findsOneWidget);
    },
  );

  testWidgets('a very long description is flagged as partly translated', (
    t,
  ) async {
    final e = FakeEngine();
    final long = List.generate(
      400,
      (i) =>
          'Wir suchen eine erfahrene Fachkraft für unser Team Nummer $i in der Stadt.',
    ).join('\n');
    await pumpApp(
      t,
      size: const Size(430, 3000),
      repo: ListRepo([
        job('long', 'Fachkraft für unser Team', description: long),
      ]),
      translationEngine: e,
    );
    await _openFirstJob(t);
    await t.tap(find.textContaining('Fachkraft für unser Team').first);
    await t.pumpAndSettle();
    expect(
      find.text(
        'Only the first part was translated; the rest is in the original.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'turning translation off in the settings shows originals and makes no engine calls',
    (t) async {
      final e = FakeEngine();
      await pumpApp(t, repo: ListRepo([german]), translationEngine: e);
      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      await t.tap(find.text('Settings'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Translate listings into my language'));
      await t.pumpAndSettle();
      await t.tap(find.text('Translate listings into my language'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      e.seen.clear(); // the Home list was translated before the switch was turned off
      await _openFirstJob(t);
      expect(
        find.text('Pflegefachkraft (m/w/d) für unser Team'),
        findsOneWidget,
      );
      expect(e.seen, isEmpty);
    },
  );

  group('real listings from the live catalogue', () {
    testWidgets(
      'German, Swedish and Traditional Chinese titles are recognised and translated; English ones from DE/FR/JP are left alone',
      (t) async {
        final e = FakeEngine();
        final jobs = realJobs();
        await pumpApp(
          t,
          size: const Size(430, 6000),
          repo: ListRepo(jobs),
          translationEngine: e,
        );
        await _openFirstJob(t);
        final fromEnglish = jobs
            .where(
              (j) =>
                  j.country != null &&
                  ['DE', 'FR', 'JP', 'ES', 'MX'].contains(j.country) &&
                  j.description!.contains(' the '),
            )
            .toList();
        for (final j in fromEnglish) {
          expect(
            e.seen.any((s) => s.contains(j.title)),
            isFalse,
            reason: '${j.title} (${j.country}) is English: not translated',
          );
        }
        // every non-English real title reached the engine, with the company and refs intact
        expect(
          e.seen.any((s) => s.contains('Industriarbetare')),
          isTrue,
          reason: 'Swedish',
        );
        expect(
          e.seen.any((s) => s.contains('Fachinformatiker')),
          isTrue,
          reason: 'German (country empty in the catalogue)',
        );
        expect(
          e.seen.any((s) => s.contains('鬍子爺爺')),
          isTrue,
          reason: 'Traditional Chinese',
        );
        // nothing in the original data was changed
        expect(jobs.first.title, contains('Industriarbetare'));
      },
    );
  });

  test('a service with the real engine contract: one translation per text and target, whatever the number of screens asking', () async {
    final e = FakeEngine(latency: const Duration(milliseconds: 5));
    final s = TranslationService(engine: e, cache: MemoryTranslationCache());
    final r = await Future.wait([
      for (var i = 0; i < 10; i++)
        s.translate(
          id: 'a',
          field: 'title',
          text: 'Elektroniker',
          from: 'de',
          to: 'pt',
        ),
    ]);
    expect(r.every((x) => x.text == '[pt] Elektroniker'), isTrue);
    expect(e.seen, hasLength(1));
  });
}
