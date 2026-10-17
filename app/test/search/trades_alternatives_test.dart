import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/search_alternatives.dart';

/// OrbiJob 14.0: trades and services found in the public catalogue with no (or the wrong) equivalents: heavy goods drivers, mechanics, gardeners,
/// plumbers, cashiers, midwives, early-years educators, cleaning and accent-less typing. Each case comes from a measured query over the live catalogue.
bool has(String term, String part) =>
    titleAlternatives(term).any((a) => a.length == 1 && a.first == part);

void main() {
  group('heavy goods drivers', () {
    test('truck driver <-> Lkw-Fahrer <-> camionero <-> lastbilschaufför, in both directions', () {
      expect(has('truck driver', 'lkw-fahrer'), true);
      expect(has('lkw-fahrer', 'truck driver'), true);
      expect(has('camionero', 'truck driver'), true);
      expect(has('camionneur', 'camionero'), true);
      expect(has('lastbilschaufför', 'lkw-fahrer'), true);
    });
    test('the whole name is the profession: "truck" never becomes a required part next to every driver word', () {
      for (final t in ['truck driver', 'lkw-fahrer', 'lastbilschaufför']) {
        for (final a in titleAlternatives(t)) {
          expect(a.length, 1, reason: '$t -> $a');
        }
        // not "any driver"
        expect(has(t, 'driver'), isFalse, reason: t);
        expect(has(t, 'motorista'), isFalse, reason: t);
        expect(has(t, 'chauffeur'), isFalse, reason: t);
      }
    });
    test('the general driver names keep their own group', () {
      expect(has('driver', 'motorista'), true);
      expect(has('motorista', 'fahrer'), true);
      expect(has('driver', 'camionero'), isFalse);
    });
  });

  group('trades and services', () {
    test('mechanic: the stem opens the group but is never offered, because it sits inside "mechanical engineer"', () {
      expect(has('mecánico', 'mechanic'), isFalse);
      expect(has('mecánico', 'mechanik'), true);
      expect(has('mechanic', 'mecánico'), true);
      expect(
        has('mechanic', 'mechanik'),
        isTrue,
      ); // "mechanik" also covers the German Mechaniker
    });
    test('gardener, plumber, cashier, midwife', () {
      expect(has('jardinero', 'gardener'), true);
      expect(has('gardener', 'gärtner'), true);
      expect(has('klempner', 'plumber'), true);
      expect(has('plumber', 'fontaner'), true);
      expect(has('caissier', 'cashier'), true);
      expect(has('cashier', 'kassierer'), true);
      expect(has('matrona', 'midwife'), true);
      expect(has('midwife', 'hebamme'), true);
    });
    test('early years: "kindergarten teacher" is its own profession, not teacher + kindergarten', () {
      expect(has('kindergarten teacher', 'erzieher'), true);
      expect(has('erzieher', 'educador infantil'), true);
      for (final a in titleAlternatives('kindergarten teacher')) {
        expect(a.length, 1, reason: '$a');
      }
      // the general teacher group is untouched
      expect(has('teacher', 'lehrer'), true);
      expect(has('teacher', 'erzieher'), isFalse);
    });
    test('cleaning staff in French and German', () {
      expect(has('femme de ménage', 'cleaner'), true);
      expect(has('cleaner', 'putzfrau'), true);
    });
  });

  group('typing without accents', () {
    test('"medico" is "médico"; the alternatives keep their accents because titles do', () {
      expect(has('medico', 'médico'), true);
      expect(has('medico', 'physician'), true);
      expect(has('médico', 'physician'), true);
    });
    test('the words the person adds stay required even when the profession is typed without accents', () {
      final alts = titleAlternatives('desenvolvedor flutter');
      expect(alts.every((a) => a.contains('flutter')), true);
      final plain = titleAlternatives('fisioterapia pelvica');
      expect(plain.isNotEmpty, true);
    });
  });
}
