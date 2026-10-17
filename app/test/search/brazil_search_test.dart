import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/search_alternatives.dart';

/// OrbiJob 14.1 (Brazil round): Flutter/Dart/mobile and pelvic physiotherapy queries written the way Brazilian users type them, checked against the
/// alternatives the catalogue query and the alert matcher use. Precision first: a Flutter query is never "every developer", a pelvic query never
/// "every physiotherapist".
bool has(String term, String part) =>
    titleAlternatives(term).any((a) => a.length == 1 && a.first == part);

List<List<String>> alts(String t) => titleAlternatives(t);

void main() {
  group('Flutter, Dart and mobile', () {
    test(
      '"desenvolvedor flutter" keeps flutter in every alternative and never offers a bare developer word',
      () {
        final a = alts('desenvolvedor flutter');
        expect(a.isNotEmpty, true);
        expect(a.every((x) => x.contains('flutter')), true);
        expect(has('desenvolvedor flutter', 'developer'), isFalse);
        expect(has('desenvolvedor flutter', 'desarrollador'), isFalse);
      },
    );
    test(
      'the typed words also match as a conjunction: "Desenvolvedor(a) Flutter" is not the adjacent phrase',
      () {
        final a = alts('desenvolvedor flutter');
        expect(titleHasAlternative('Desenvolvedor(a) Flutter Sênior', a), true);
        expect(
          titleHasAlternative(
            'Flutter Senior Developer',
            alts('flutter developer'),
          ),
          true,
        );
        expect(titleHasAlternative('Desenvolvedor Java', a), false);
        expect(titleHasAlternative('Flutter Designer', a), false);
      },
    );
    test('programador is a developer, with dart as the required qualifier', () {
      final a = alts('programador dart');
      expect(a.isNotEmpty, true);
      expect(a.every((x) => x.contains('dart')), true);
      expect(titleHasAlternative('Dart Developer', a), true);
      expect(titleHasAlternative('Java Developer', a), false);
      expect(has('programador', 'developer'), true);
      expect(has('developer', 'programador'), true);
    });
    test(
      'desenvolvedor de aplicativos is an app developer, not any developer',
      () {
        expect(has('desenvolvedor de aplicativos', 'app developer'), true);
        expect(has('desenvolvedor de aplicativos', 'apputvecklare'), true);
        expect(has('desenvolvedor de aplicativos', 'developer'), isFalse);
        expect(has('desenvolvedor de aplicativos', 'desarrollador'), isFalse);
      },
    );
    test(
      'mobile stays a required qualifier of the developer and engineer groups',
      () {
        for (final t in ['desenvolvedor mobile', 'engenheiro mobile']) {
          expect(alts(t).every((x) => x.contains('mobile')), true, reason: t);
        }
      },
    );
  });

  group('pelvic physiotherapy', () {
    test(
      'every alternative of a pelvic query is pelvic AND physiotherapy: never all physiotherapists',
      () {
        for (final t in [
          'fisioterapeuta pélvica',
          'fisioterapia pelvica',
          'pelvic floor physiotherapist',
        ]) {
          final a = alts(t);
          expect(a.isNotEmpty, true, reason: t);
          expect(a.every((x) => x.length >= 2), true, reason: t);
          expect(
            a.any((x) => x.length == 1 && x.first.contains('fisioterap')),
            false,
            reason: t,
          );
          expect(
            titleHasAlternative('Pelvic Health Physiotherapist', a),
            true,
            reason: t,
          );
          expect(
            titleHasAlternative('Beckenboden Physiotherapeutin', a),
            true,
            reason: t,
          );
          expect(titleHasAlternative('Physiotherapist', a), false, reason: t);
          expect(
            titleHasAlternative('Fisioterapeuta Ortopédico', a),
            false,
            reason: t,
          );
        }
      },
    );
    test(
      'the pelvic floor names stand alone: the person did not ask for a profession plus a required "assoalho", "floor" or "reabilitação"',
      () {
        for (final t in ['assoalho pélvico', 'pelvic floor']) {
          final a = alts(t);
          expect(a.isNotEmpty, true, reason: t);
          expect(a.every((x) => x.length == 1), true, reason: '$t -> $a');
        }
        expect(has('assoalho pélvico', 'beckenboden'), true);
      },
    );
    test(
      'women\'s health and obstetric physiotherapy keep their qualifier next to a physiotherapy name; no gynaecologist or obstetric nurse',
      () {
        for (final t in [
          'fisioterapia da mulher',
          'fisioterapeuta obstétrica',
        ]) {
          final a = alts(t);
          expect(a.every((x) => x.length >= 2), true, reason: t);
          expect(titleHasAlternative('Ginecologista', a), false, reason: t);
          expect(
            titleHasAlternative('Enfermeira Obstetra', a),
            false,
            reason: t,
          );
        }
      },
    );
    test('the cap keeps the query small', () {
      expect(alts('fisioterapeuta pélvica').length <= 40, true);
    });
  });
}
