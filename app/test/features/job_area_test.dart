import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/job_area.dart';

void main() {
  group('JobArea keywords', () {
    test('every area has keywords, and each is a safe PostgREST filter value (no comma, paren, quote, wildcard or dot-separator)', () {
      for (final a in JobArea.values) {
        expect(a.keywords, isNotEmpty, reason: a.name);
        for (final k in a.keywords) {
          expect(k, k.toLowerCase(), reason: '$k must be lower case');
          expect(k, isNot(matches(RegExp(r'[,()"*%\\]'))), reason: '$k would alter the or=() structure');
          expect(k.trim(), k, reason: '$k has edge spaces');
          expect(k.length, greaterThanOrEqualTo(3), reason: '$k is too short and would match inside unrelated words');
        }
        expect(a.keywords.toSet().length, a.keywords.length, reason: '${a.name} repeats a keyword');
      }
    });

    test('the server filter is exactly one title.ilike term per keyword', () {
      final f = JobArea.health.orFilter.split(',');
      expect(f, hasLength(JobArea.health.keywords.length));
      expect(f.every((t) => t.startsWith('title.ilike.*') && t.endsWith('*')), isTrue);
    });

    test('real titles land in the right areas (any language listed), and a title can belong to several', () {
      expect(JobArea.of('Senior Flutter Developer'), contains(JobArea.technology));
      expect(JobArea.of('Registered Nurse'), [JobArea.health]);
      expect(JobArea.of('Pedreiro / mason').contains(JobArea.construction), isTrue);
      expect(JobArea.of('Enfermeira - Hospital São Paulo'), contains(JobArea.health));
      expect(JobArea.of('Desenvolvedor Backend'), containsAll([JobArea.technology]));
      expect(JobArea.of('Data Engineer'), containsAll([JobArea.technology, JobArea.data]));
      expect(JobArea.of('Customer Success Manager'), contains(JobArea.support));
      expect(JobArea.of('Account Executive, Enterprise'), contains(JobArea.sales));
      expect(JobArea.of('Chef de cozinha / cozinheiro'), contains(JobArea.hospitality));
      expect(JobArea.of('Motorista de caminhão'), contains(JobArea.logistics));
      expect(JobArea.of('Professor de matemática'), contains(JobArea.education));
    });

    test('short fragments that sit inside unrelated words do not match (Seoul, taxonomy, MongoDB, Windows, platform)', () {
      expect(JobArea.of('Business Analyst, Seoul').contains(JobArea.marketing), isFalse);
      expect(JobArea.of('Taxonomy Manager').contains(JobArea.finance), isFalse);
      expect(JobArea.of('MongoDB Support Specialist').contains(JobArea.public), isFalse);
      expect(JobArea.of('Windows Administrator').contains(JobArea.industry), isFalse);
      expect(JobArea.of('Platform Specialist').contains(JobArea.industry), isFalse);
    });

    test('an unknown profession belongs to no area (nothing is invented)', () {
      expect(JobArea.of('Interpreter of Georgian'), isEmpty);
    });
  });
}
