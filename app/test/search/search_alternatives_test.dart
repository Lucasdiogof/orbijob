import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/search_alternatives.dart';

/// Regression cases of OrbiJob 5.0: a profession is searched under its other names, in the languages of the catalogue, without turning a
/// qualified profession into the whole field. Examples, not an exhaustive list.
bool has(String term, String part) =>
    titleAlternatives(term).any((a) => a.length == 1 && a.first == part);
bool hasAll(String term, List<String> parts) =>
    titleAlternatives(term)
        .any((a) => a.length == parts.length && parts.every(a.contains));

void main() {
  group('multilingual professions', () {
    test('pelvic physiotherapy keeps BOTH parts in every language', () {
      for (final t in [
        'fisioterapia pélvica',
        'pelvic health physiotherapist',
        'beckenbodenphysiotherapie',
      ]) {
        final alts = titleAlternatives(t);
        expect(alts, isNotEmpty, reason: t);
        // never "any physiotherapist": every alternative has two parts
        expect(alts.every((a) => a.length >= 2), isTrue, reason: t);
      }
      expect(hasAll('fisioterapia pélvica', ['physiotherap', 'pelvic']), true);
      expect(
        hasAll('fisioterapia pélvica', ['fysioterapeut', 'bäckenbotten']),
        true,
      );
      expect(
        hasAll('beckenbodenphysiotherapie', ['fisioterap', 'pélvic']),
        true,
      );
    });

    test('flutter developer keeps the qualifier', () {
      expect(hasAll('desenvolvedor flutter', ['flutter', 'developer']), true);
      expect(hasAll('desenvolvedor flutter', ['flutter', 'entwickler']), true);
      expect(hasAll('flutter-entwickler', ['flutter', 'developer']), true);
      expect(has('desenvolvedor flutter', 'developer'), isFalse);
      expect(titleAlternatives('flutter'), isEmpty);
    });

    test('nurse, civil engineer, electrician and welder across languages', () {
      expect(has('enfermeiro', 'nurse'), true);
      expect(has('nurse', 'sjuksköterska'), true);
      expect(has('pflegefachkraft', 'nurse'), true);
      expect(hasAll('engenheiro civil', ['civil', 'engineer']), true);
      expect(has('engenheiro civil', 'bauingenieur'), true);
      expect(has('bauingenieur', 'engenheiro civil'), false);
      expect(hasAll('bauingenieur', ['engenheiro', 'civil']), true);
      expect(has('eletricista', 'elektriker'), true);
      expect(has('electrician', 'eletricista'), true);
      expect(has('soldador', 'welder'), true);
      expect(has('welder', 'schweißer'), true);
      expect(has('schweißer', 'soldador'), true);
    });

    test('a qualified profession never becomes the whole field', () {
      // "engenheiro civil" must not find every engineer, a Bauingenieur must not find every Ingenieur
      for (final t in ['engenheiro civil', 'civil engineer', 'bauingenieur']) {
        expect(has(t, 'engineer'), isFalse, reason: t);
        expect(has(t, 'ingenieur'), isFalse, reason: t);
        expect(has(t, 'engenheir'), isFalse, reason: t);
      }
    });

    test('false friends never stand alone as another profession', () {
      for (final t in ['chef', 'cozinheiro', 'chefkoch']) {
        expect(has(t, 'chef'), isFalse, reason: t);
      }
    });

    test('unknown or unrelated terms add nothing', () {
      for (final t in ['acme', 'goiânia', 'ab', '', '   ', 'zzzzqqq']) {
        expect(titleAlternatives(t), isEmpty, reason: t);
      }
    });

    test('everything is safe in a PostgREST filter and a LIKE pattern', () {
      final unsafe = RegExp(r'[(),*"\%_:;]');
      for (final t in [
        'enfermeiro',
        'electrician',
        'fisioterapia pélvica',
        'engenheiro civil',
        'soldador',
        'professor',
        'motorista',
        'contador',
        'advogado',
        'psicólogo',
      ]) {
        final alts = titleAlternatives(t);
        expect(alts.length, lessThanOrEqualTo(40), reason: t);
        for (final a in alts) {
          expect(a.length, inInclusiveRange(1, 6), reason: t);
          for (final p in a) {
            expect(p, isNot(matches(unsafe)), reason: '$t: $p');
            expect(p, p.toLowerCase());
          }
        }
      }
    });

    test('titleHasAlternative needs every part', () {
      final alts = titleAlternatives('engenheiro civil');
      expect(titleHasAlternative('Bauingenieur (m/w/d)', alts), isTrue);
      expect(titleHasAlternative('Senior Civil Engineer', alts), isTrue);
      expect(titleHasAlternative('Mechanical Engineer', alts), isFalse);
      expect(titleHasAlternative('Civil Servant', alts), isFalse);
    });

    test('ESCO lookup matches the other grammatical gender', () {
      expect(escoOccupationsOf('engenheira civil'), isNotEmpty);
      expect(escoOccupationsOf('engenheiro civil'), isNotEmpty);
      expect(escoOccupationsOf('civil engineer'), isNotEmpty);
    });
  });
}
