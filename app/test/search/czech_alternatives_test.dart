import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/search_alternatives.dart';

/// OrbiJob 12.0: Czech job titles (Úřad práce ČR) are found from Portuguese, English, Spanish, German, Swedish and French searches, through
/// the ESCO Czech labels and the hand-made groups; and the other way round. Every case was checked against real Czech titles in production
/// (scripts/search-benchmark.cs.after.csv).
bool reaches(String term, String fragment) =>
    titleAlternatives(term).any((a) => a.any((p) => p.contains(fragment)));

void main() {
  test('the same profession in seven languages reaches the Czech name', () {
    const cases = {
      'kuchař': ['cozinheiro', 'cook', 'cocinero', 'koch', 'cuisinier'],
      'číšník': [
        'garçom',
        'waiter',
        'camarero',
        'kellner',
        'servitör',
        'serveur',
      ],
      'řidič': ['motorista', 'driver', 'fahrer', 'chaufför', 'chauffeur'],
      'skladník': [
        'trabalhador de armazém',
        'warehouse worker',
        'lagerarbeiter',
        'lagerarbetare',
        'magasinier',
      ],
      'stavební dělník': [
        'trabalhador de construção',
        'construction worker',
        'bauarbeiter',
        'byggnadsarbetare',
      ],
      'elektrikář': [
        'eletricista',
        'electrician',
        'electricista',
        'elektriker',
        'électricien',
      ],
      'svářeč': ['soldador', 'welder', 'schweißer', 'svetsare', 'soudeur'],
      'zdravotní sestr': [
        'enfermeiro',
        'nurse',
        'enfermero',
        'krankenpfleger',
        'sjuksköterska',
        'infirmier',
      ],
      'fyzioterapeut': [
        'fisioterapeuta',
        'physiotherapist',
        'fysioterapeut',
        'kinésithérapeute',
      ],
      'učitel': ['professor', 'teacher', 'lehrer', 'lärare', 'enseignant'],
    };
    cases.forEach((czech, others) {
      for (final q in others) {
        expect(reaches(q, czech), isTrue, reason: '$q -> $czech');
      }
    });
  });

  test('and from Czech to the other languages', () {
    expect(reaches('kuchař', 'cook'), isTrue);
    expect(reaches('řidič', 'driver'), isTrue);
    expect(reaches('svářeč', 'welder'), isTrue);
    expect(reaches('číšník', 'kellner'), isTrue);
  });

  test('Czech words typed without their marks still find the occupation', () {
    expect(escoOccupationsOf('kuchar'), isNotEmpty);
    expect(escoOccupationsOf('kuchar'), escoOccupationsOf('kuchař'));
  });

  test(
    'no incompatible profession: the qualifier and the field stay apart',
    () {
      // a cook is not a waiter, a driver is not a warehouse worker, a nurse is not a physiotherapist
      expect(reaches('cozinheiro', 'číšník'), isFalse);
      expect(reaches('motorista', 'skladník'), isFalse);
      expect(reaches('enfermeiro', 'fyzioterapeut'), isFalse);
      expect(reaches('professor', 'kuchař'), isFalse);
      // never the bare "sestra" (also "sister"), never "lager" alone (also beer, camp, bearing)
      for (final q in ['nurse', 'enfermeiro', 'warehouse worker']) {
        expect(
          titleAlternatives(q).any(
            (a) => a.length == 1 && (a.first == 'sestra' || a.first == 'lager'),
          ),
          isFalse,
          reason: q,
        );
      }
      // "trabalhador de armazém" is one name: its words are not extra required parts
      expect(
        titleAlternatives('trabalhador de armazém')
            .any((a) => a.contains('trabalhador')),
        isFalse,
      );
      // a qualified search keeps its qualifier in Czech too
      expect(
        titleAlternatives('desenvolvedor flutter')
            .every((a) => a.contains('flutter')),
        isTrue,
      );
    },
  );
}
