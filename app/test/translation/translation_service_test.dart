import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/translation/text_protection.dart';
import 'package:orbijob/features/translation/translation_cache.dart';
import 'package:orbijob/features/translation/translation_engine.dart';
import 'package:orbijob/features/translation/translation_service.dart';

import '../helpers/translation_fakes.dart';

TranslationService svc(
  FakeEngine e, {
  TranslationCache? cache,
  int maxChars = 8000,
  DateTime Function()? clock,
}) => TranslationService(
  engine: e,
  cache: cache ?? MemoryTranslationCache(),
  maxChars: maxChars,
  clock: clock,
);

Future<TextTranslation> tr(
  TranslationService s,
  String text, {
  String id = 'j1',
  String field = 'title',
  String from = 'de',
  String to = 'pt',
  Iterable<String> keep = const [],
}) => s.translate(
  id: id,
  field: field,
  text: text,
  from: from,
  to: to,
  keep: keep,
);

void main() {
  group('protected parts', () {
    test('addresses, e-mails, salaries, refs, gender markers, levels and acronyms are swapped for markers and restored exactly', () {
      const line =
          'Gehalt 45.000 € bis 55.000 € brutto, Ref. ABC-123, Details: https://example.de/jobs?id=7 oder kontakt@example.de, (m/w/d), CREFITO, Niveau B2.';
      final p = protectLine(line);
      expect(p.text, isNot(contains('example')));
      expect(p.text, isNot(contains('45.000')));
      expect(p.text, isNot(contains('CREFITO')));
      expect(p.text, isNot(contains('(m/w/d)')));
      expect(p.text, isNot(contains('B2')));
      expect(restoreLine(p.text, p), line, reason: 'round trip is exact');
    });

    test('the company name and extra literals are kept', () {
      final p = protectLine(
        'Bei Siemens Energy AG bauen wir Zukunft',
        keep: ['Siemens Energy AG'],
      );
      expect(p.text, startsWith('Bei ⟦'));
      expect(restoreLine(p.text, p), 'Bei Siemens Energy AG bauen wir Zukunft');
    });

    test('an all-capitals heading is translated as text, not protected as an acronym', () {
      final p = protectLine('WIR BIETEN DIR');
      expect(p.hasProtected, isFalse);
    });

    test(
      'a missing, duplicated or invented marker makes the line untrusted',
      () {
        final p = protectLine('Kontakt: a@b.de und c@d.de');
        expect(
          restoreLine('Contact: ⟦0⟧', p),
          isNull,
          reason: 'one marker lost',
        );
        expect(
          restoreLine('Contact: ⟦0⟧ ⟦0⟧ ⟦1⟧', p),
          isNull,
          reason: 'one duplicated',
        );
        expect(
          restoreLine('Contact: ⟦0⟧ ⟦1⟧ ⟦7⟧', p),
          isNull,
          reason: 'one invented',
        );
        expect(
          restoreLine('Contact: ⟦ 1 ⟧ and ⟦0⟧', p),
          'Contact: c@d.de and a@b.de',
          reason: 'spacing and order may change',
        );
      },
    );

    test('bullets keep their prefix; long lines are cut at sentence ends', () {
      expect(splitBullet('• Teamarbeit').prefix, '• ');
      expect(splitBullet('2) Erfahrung').prefix, '2) ');
      expect(splitBullet('Ohne Aufzählung').prefix, '');
      final long = List.filled(
        30,
        'Das ist ein Satz mit etwas Inhalt.',
      ).join(' ');
      final chunks = chunkLine(long, max: 200);
      expect(chunks.length, greaterThan(3));
      expect(chunks.every((c) => c.length <= 240), isTrue);
      expect(chunks.join(' '), long);
    });
  });

  group('the service', () {
    test('translates line by line, keeps structure, bullets and blank lines, and never changes protected parts', () async {
      final e = FakeEngine();
      final s = svc(e);
      final r = await tr(
        s,
        'Über uns\n\n- Gehalt 45.000 € (m/w/d)\n• Kontakt: hr@firma.de',
        field: 'description',
      );
      expect(r.outcome, TranslationOutcome.ok);
      expect(
        r.text,
        '[pt] Über uns\n\n- [pt] Gehalt 45.000 € (m/w/d)\n• [pt] Kontakt: hr@firma.de',
      );
      expect(
        e.seen.any((t) => t.contains('45.000') || t.contains('@')),
        isFalse,
        reason: 'the engine never saw protected parts',
      );
    });

    test(
      'the original is untouched: only the returned text is translated',
      () async {
        final s = svc(FakeEngine());
        const original = 'Elektroniker (m/w/d)';
        final r = await tr(s, original);
        expect(r.text, isNot(original));
        expect(original, 'Elektroniker (m/w/d)');
      },
    );

    test('same language, unsupported pair and missing model are reported, never faked', () async {
      final e = FakeEngine();
      final s = svc(e);
      expect(
        (await tr(s, 'Hallo', from: 'de', to: 'de')).outcome,
        TranslationOutcome.sameLanguage,
      );
      expect(
        (await tr(s, 'Hallo', from: 'xx', to: 'pt')).outcome,
        TranslationOutcome.unsupported,
      );
      e.ready = false;
      final r = await tr(s, 'Hallo');
      expect(r.outcome, TranslationOutcome.needsDownload);
      expect(r.text, isNull);
      expect(e.seen, isEmpty, reason: 'no engine call without the data');
      expect(await s.prepare('de', 'pt'), isTrue);
      expect((await tr(s, 'Hallo')).outcome, TranslationOutcome.ok);
    });

    test('cache: same text + target never reaches the engine twice; another target or changed text does', () async {
      final e = FakeEngine();
      final s = svc(e);
      await tr(s, 'Elektroniker');
      expect(e.seen, hasLength(1));
      await tr(s, 'Elektroniker');
      expect(e.seen, hasLength(1), reason: 'served from the cache');
      await tr(s, 'Elektroniker', to: 'es');
      expect(
        e.seen,
        hasLength(2),
        reason: 'a new target language is a new translation',
      );
      await tr(s, 'Elektroniker (Teilzeit)');
      expect(
        e.seen,
        hasLength(3),
        reason: 'an updated listing misses the cache (the hash of the original changed)',
      );
      // switching back to a language already done is instant
      await tr(s, 'Elektroniker', to: 'pt');
      expect(e.seen, hasLength(3));
      expect(
        (await s.cached('j1', 'title', 'es', 'Elektroniker'))!.text,
        '[es] Elektroniker',
      );
      expect(await s.cached('j1', 'title', 'en', 'Elektroniker'), isNull);
    });

    test('identical requests in flight share one run', () async {
      final e = FakeEngine(latency: const Duration(milliseconds: 20));
      final s = svc(e);
      final a = tr(s, 'Elektroniker');
      final b = tr(s, 'Elektroniker');
      final r = await Future.wait([a, b]);
      expect(r.map((x) => x.text).toSet(), hasLength(1));
      expect(e.seen, hasLength(1));
    });

    test('concurrency is bounded across callers', () async {
      final e = FakeEngine(latency: const Duration(milliseconds: 15));
      final s = svc(e);
      await Future.wait([
        for (var i = 0; i < 12; i++) tr(s, 'Titel Nummer $i', id: 'job$i'),
      ]);
      expect(e.maxConcurrent, lessThanOrEqualTo(2));
      expect(e.seen, hasLength(12));
    });

    test('a very long text is cut at a line break and flagged as partial, not silently truncated', () async {
      final s = svc(FakeEngine(), maxChars: 200);
      final text = List.generate(40, (i) => 'Zeile $i mit Inhalt.').join('\n');
      final r = await tr(s, text, field: 'description');
      expect(r.outcome, TranslationOutcome.partial);
      expect(r.cut, isTrue);
      expect(r.text!.split('\n').length, lessThan(40));
      expect(
        r.text!.split('\n').every((l) => l.startsWith('[pt] Zeile')),
        isTrue,
      );
      // the partial result is cached as partial
      expect((await s.cached('j1', 'description', 'pt', text))!.cut, isTrue);
    });

    test(
      'engine failure is reported, backed off, and recovers later',
      () async {
        final e = FakeEngine()..failWith = StateError('boom');
        var now = DateTime(2026, 10, 13, 12);
        final s = svc(e, clock: () => now);
        expect((await tr(s, 'Hallo')).outcome, TranslationOutcome.failed);
        final calls = e.seen.length;
        expect((await tr(s, 'Hallo')).outcome, TranslationOutcome.failed);
        expect(
          e.seen.length,
          calls,
          reason: 'inside the back-off window the engine is left alone',
        );
        e.failWith = null;
        now = now.add(const Duration(minutes: 2));
        expect((await tr(s, 'Hallo')).outcome, TranslationOutcome.ok);
      },
    );

    test('a line whose protected part did not survive keeps its original; the result says partial', () async {
      final e = FakeEngine()..markers = 'drop';
      final s = svc(e);
      final r = await tr(
        s,
        'Zeile ohne Schutz\nKontakt hr@firma.de',
        field: 'description',
      );
      expect(r.outcome, TranslationOutcome.partial);
      expect(r.keptLines, 1);
      expect(r.text, '[pt] Zeile ohne Schutz\nKontakt hr@firma.de');
    });

    test('level 2: an engine that drops markers still translates a line whose only protected parts are acronyms, if they come back verbatim', () async {
      final e = FakeEngine()..markers = 'drop';
      final s = svc(e);
      final r = await tr(s, 'beard papa LALA PORT Verkäufer');
      expect(r.outcome, TranslationOutcome.ok);
      expect(r.text, '[pt] beard papa LALA PORT Verkäufer');
      expect(
        e.seen.length,
        2,
        reason:
            'one attempt with markers, one with acronyms verified afterwards',
      );
    });

    test('level 2 puts back the capitals an engine changed ("Lala Port" -> "LALA PORT")', () async {
      final e = FakeEngine()..markers = 'titlecase';
      final s = svc(e);
      final r = await tr(s, 'Verkäufer bei LALA PORT');
      expect(r.outcome, TranslationOutcome.ok);
      expect(r.text, '[pt] Verkäufer bei LALA PORT');
    });

    test('level 2 never trusts a translation that altered an acronym (CREFITO must not become "creço")', () async {
      final e = FakeEngine()..markers = 'mangle';
      final s = svc(e);
      final r = await tr(s, 'Registro CREFITO obrigatório');
      expect(
        r.outcome,
        TranslationOutcome.failed,
        reason: 'the only line was kept in the original',
      );
    });

    test('if every line lost its markers the result is a failure, not a translation', () async {
      final e = FakeEngine()..markers = 'duplicate';
      final s = svc(e);
      final r = await tr(s, 'Mail: a@b.de');
      expect(r.outcome, TranslationOutcome.failed);
    });

    test('progress is reported', () async {
      final s = svc(FakeEngine());
      final seen = <double>[];
      await s.translate(
        id: 'j',
        field: 'description',
        text: 'a b\nc d\ne f\ng h',
        from: 'de',
        to: 'pt',
        onProgress: seen.add,
      );
      expect(seen.last, 1.0);
      expect(seen.length, 4);
    });
  });

  group('cache implementation', () {
    test('the fingerprint changes with any change of the text', () {
      expect(
        TranslationService.fingerprint('a'),
        isNot(TranslationService.fingerprint('b')),
      );
      expect(
        TranslationService.fingerprint('same'),
        TranslationService.fingerprint('same'),
      );
      expect(
        TranslationService.cacheKey('j1', 'title', 'pt', 'x'),
        isNot(TranslationService.cacheKey('j1', 'title', 'en', 'x')),
      );
    });
  });

  test('NoTranslationEngine says unsupported for everything', () async {
    const e = NoTranslationEngine();
    final s = TranslationService(engine: e, cache: MemoryTranslationCache());
    final r = await s.translate(
      id: 'j',
      field: 'title',
      text: 'Hallo',
      from: 'de',
      to: 'pt',
    );
    expect(r.outcome, TranslationOutcome.unsupported);
  });
}
