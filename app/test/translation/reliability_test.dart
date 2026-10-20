import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/format/contract_labels.dart';
import 'package:orbijob/core/format/job_format.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/translation/network_probe.dart';
import 'package:orbijob/features/translation/translation_cache.dart';
import 'package:orbijob/features/translation/translation_cubit.dart';
import 'package:orbijob/features/translation/translation_engine.dart';
import 'package:orbijob/features/translation/translation_service.dart';

import '../helpers/harness.dart';
import '../helpers/translation_fakes.dart';
import 'auto_download_test.dart' show FakeNetwork;
import 'translation_ui_test.dart' show ListRepo;

const _texts = {
  'de': 'Wir suchen eine Pflegefachkraft für unser Krankenhaus in Köln. Sie arbeiten im Team und betreuen Patienten auf der Station. Wir bieten einen sicheren Arbeitsplatz und Weiterbildung.',
  'fr': 'Nous recherchons un infirmier diplômé pour notre hôpital à Lyon. Vous travaillerez en équipe et vous vous occuperez des patients dans le service. Nous offrons un emploi stable et des formations.',
  'sv': 'Vi söker en sjuksköterska till vårt sjukhus i Göteborg. Du arbetar i team och tar hand om patienter på avdelningen. Vi erbjuder en trygg anställning och kompetensutveckling.',
  'es': 'Buscamos un enfermero titulado para nuestro hospital en Madrid. Trabajarás en equipo y atenderás a los pacientes en la planta. Ofrecemos un empleo estable y formación continua.',
  'pt': 'Procuramos um enfermeiro para o nosso hospital em São Paulo. Você trabalhará em equipe e cuidará dos pacientes na unidade. Oferecemos emprego estável e formação contínua.',
};

JobPosting _job(String id, String lang, {String? contract}) => JobPosting(
  source: 't',
  externalId: id,
  company: 'Klinik GmbH',
  title: 'Enfermeiro $id ($lang)',
  originalUrl: 'https://example.invalid/$id',
  description: _texts[lang],
  contractType: contract,
);

/// An engine whose download never answers (a Wi-Fi without internet) and which can be told to answer later.
class _HangingEngine extends FakeEngine {
  _HangingEngine() : super(ready: false);
  final _gate = Completer<bool>();
  @override
  Future<bool> prepare(String from, String to) {
    prepared++;
    return _gate.future;
  }

  void finish() {
    ready = true;
    _gate.complete(true);
  }
}

/// A download that reports failure.
class _FailingEngine extends FakeEngine {
  _FailingEngine() : super(ready: false);
  @override
  Future<bool> prepare(String from, String to) async {
    prepared++;
    return false;
  }
}

/// A translation that never returns.
class _StuckEngine extends FakeEngine {
  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) => Completer<String>().future;
}

TranslationCubit _cubit(
  TranslationEngine e, {
  NetworkProbe? net,
  TranslationCache? cache,
  String target = 'pt',
}) => TranslationCubit(
  TranslationService(
    engine: e,
    cache: cache ?? MemoryTranslationCache(),
    downloadTimeout: const Duration(milliseconds: 60),
    translateTimeout: const Duration(milliseconds: 60),
  ),
  initialTarget: target,
  network: net,
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 120));

void main() {
  group('listings in other languages become Portuguese', () {
    for (final lang in ['de', 'fr', 'sv', 'es']) {
      test('$lang -> pt: title and description are translated', () async {
        final e = FakeEngine(sources: const {'de', 'fr', 'sv', 'es', 'en'});
        final c = _cubit(e);
        final j = _job('1', lang);
        expect(c.sourceLanguageOf(j), lang);
        await c.loadDetail(j);
        final d = c.state.details['t:1']!;
        expect(d.status, DetailStatus.ready);
        expect(d.title, startsWith('[pt] '));
        expect(d.description, startsWith('[pt] '));
        await c.close();
      });
    }

    test(
      'pt -> pt: nothing is translated, the engine is never called',
      () async {
        final e = FakeEngine();
        final c = _cubit(e);
        await c.loadDetail(_job('1', 'pt'));
        expect(c.state.details['t:1']!.status, DetailStatus.none);
        expect(e.seen, isEmpty);
        await c.close();
      },
    );
  });

  group('the download can no longer last forever', () {
    test('an answer that never comes ends as a failure, then works when the data lands', () async {
      final e = _HangingEngine();
      final c = _cubit(e, net: FakeNetwork(NetworkKind.unmetered));
      final started = DateTime.now();
      await c.loadDetail(_job('1', 'de'));
      expect(
        DateTime.now().difference(started),
        lessThan(const Duration(seconds: 2)),
      );
      expect(c.state.details['t:1']!.status, DetailStatus.downloadFailed);
      e.finish();
      await _settle();
      await c.retryDetail(_job('1', 'de'));
      expect(c.state.details['t:1']!.status, DetailStatus.ready);
      await c.close();
    });

    test('after a failure the automatic download waits (back-off); a tap on retry does not', () async {
      final e = _FailingEngine();
      final c = _cubit(e, net: FakeNetwork(NetworkKind.unmetered));
      await c.loadDetail(_job('1', 'de'));
      expect(e.prepared, 1);
      expect(c.state.details['t:1']!.status, DetailStatus.downloadFailed);
      await c.loadDetail(_job('2', 'de')); // another listing opened right after
      expect(e.prepared, 1, reason: 'no hammering of a failing download');
      expect(c.state.details['t:2']!.status, DetailStatus.downloadFailed);
      await c.retryDetail(_job('2', 'de'));
      expect(e.prepared, 2, reason: 'the person asked');
      await c.close();
    });

    test('a translation that never returns ends as a failure with the original available', () async {
      final c = _cubit(_StuckEngine());
      await c.loadDetail(_job('1', 'de'));
      expect(c.state.details['t:1']!.status, DetailStatus.failed);
      await c.close();
    });
  });

  group('Explorar (cards)', () {
    test('Wi-Fi: forty cards that need the same data start one download and are translated when it lands', () async {
      final e = FakeEngine(ready: false);
      final c = _cubit(e, net: FakeNetwork(NetworkKind.unmetered));
      final jobs = [for (var i = 0; i < 40; i++) _job('$i', 'de')];
      for (final j in jobs) {
        c.requestTitle(j);
      }
      await _settle();
      expect(e.prepared, 1);
      for (final j in jobs) {
        c.requestTitle(
          j,
        ); // a card builds again after the data landed (modelsVersion changed)
      }
      await _settle();
      expect(c.titleFor(jobs.first), startsWith('[pt] '));
      expect(c.titleFor(jobs.last), startsWith('[pt] '));
      expect(
        e.maxConcurrent,
        lessThanOrEqualTo(2),
        reason: 'the queue is limited',
      );
      await c.close();
    });

    test('mobile data on the Wi-Fi policy, or an unknown network: a list downloads nothing', () async {
      final e = FakeEngine(ready: false);
      final c = _cubit(e, net: FakeNetwork(NetworkKind.mobile));
      c.requestTitle(_job('1', 'de'));
      await _settle();
      final c2 = _cubit(e);
      c2.requestTitle(_job('2', 'de'));
      await _settle();
      expect(e.prepared, 0);
      expect(c.titleFor(_job('1', 'de')), isNull);
      await c.close();
      await c2.close();
    });

    test('warm-up fetches only the interface language, once', () async {
      final e = FakeEngine(ready: false);
      final c = _cubit(e, net: FakeNetwork(NetworkKind.unmetered));
      await c.warmUp();
      await c.warmUp();
      await _settle();
      expect(e.prepared, 1);
      await c.close();
    });

    test('translations persist: a new session offline, without the data, still shows them', () async {
      final cache = MemoryTranslationCache();
      final j = _job('1', 'de');
      final first = _cubit(FakeEngine(), cache: cache);
      first.requestTitle(j);
      await _settle();
      expect(first.titleFor(j), isNotNull);
      await first.close();

      final offline = FakeEngine(ready: false);
      final second = _cubit(
        offline,
        cache: cache,
        net: FakeNetwork(NetworkKind.none),
      );
      second.requestTitle(j);
      await _settle();
      expect(second.titleFor(j), first.titleFor(j));
      await second.loadDetail(j);
      expect(offline.seen, isEmpty);
      await second.close();
    });

    test(
      'changing the interface language asks again, cached work returns at once',
      () async {
        final e = FakeEngine();
        final c = _cubit(e);
        final j = _job('1', 'de');
        c.requestTitle(j);
        await _settle();
        final pt = c.titleFor(j);
        c.setTarget('es');
        expect(c.titleFor(j), isNull);
        c.requestTitle(j);
        await _settle();
        expect(c.titleFor(j), startsWith('[es] '));
        c.setTarget('pt');
        expect(c.titleFor(j), pt);
        await c.close();
      },
    );
  });

  group('structured terms', () {
    test('the German contract line of the report becomes Portuguese by a table, not by free translation', () {
      expect(
        localizedContract('Unbefristeter arbeitsvertrag, berufserfahren', 'pt'),
        'Prazo indeterminado, Com experiência',
      );
      expect(localizedContract('Vollzeit', 'pt'), 'Tempo integral');
      expect(
        localizedContract('Teilzeit, befristet', 'en'),
        'Part-time, Fixed term',
      );
      expect(
        localizedContract('CDI - temps plein', 'es'),
        'Indefinido, Jornada completa',
      );
    });

    test('unknown terms are not guessed', () {
      expect(localizedContract('Sonderform XY', 'pt'), isNull);
      expect(localizedContract('Vollzeit', 'de'), isNull);
    });

    test('languages are named in the interface language', () {
      expect(languageName('de', 'pt'), 'Alemão');
      expect(languageName('de', 'en'), 'German');
      expect(languageName('de', 'es'), 'Alemán');
      expect(languageName('zh-Hant', 'pt'), 'Chinês');
    });
  });

  group('screens in Portuguese', () {
    final german = JobPosting(
      source: 'test',
      externalId: 'de1',
      company: 'MegaDev GmbH',
      title: 'People Operations Specialist TZ (m/w/d)',
      originalUrl: 'https://example.invalid/de1',
      description: _texts['de'],
      contractType: 'Unbefristeter arbeitsvertrag, berufserfahren',
      sourceName: 'Example source',
    );

    Future<void> openList(WidgetTester t, FakeEngine e) async {
      await pumpApp(
        t,
        size: const Size(430, 3000),
        locale: const Locale('pt'),
        repo: ListRepo([german]),
        translationEngine: e,
      );
      await t.tap(find.text('Explorar'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'x');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
    }

    testWidgets(
      'the card speaks Portuguese: contract by table, language by name',
      (t) async {
        await openList(t, FakeEngine(ready: false));
        expect(
          find.textContaining('Prazo indeterminado, Com experiência'),
          findsOneWidget,
        );
        expect(find.textContaining('Alemão'), findsOneWidget);
        expect(find.textContaining('Unbefristeter'), findsNothing);
        expect(find.textContaining('Deutsch'), findsNothing);
      },
    );

    testWidgets(
      'without the language data the detail explains instead of showing German, and the original is one tap away',
      (t) async {
        await openList(t, FakeEngine(ready: false));
        await t.tap(find.text('People Operations Specialist TZ (m/w/d)'));
        await t.pumpAndSettle();
        expect(
          find.textContaining('Wir suchen eine Pflegefachkraft'),
          findsNothing,
        );
        expect(find.textContaining('está em alemão'), findsOneWidget);
        await t.tap(find.text('Ver texto original'));
        await t.pumpAndSettle();
        expect(
          find.textContaining('Wir suchen eine Pflegefachkraft'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a reduced-motion, large-text detail does not overflow', (
      t,
    ) async {
      t.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await openList(t, FakeEngine(ready: false));
      await t.tap(find.textContaining('People Operations').first);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });
}
