import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/health_specialty.dart';
import 'package:orbijob/features/search/domain/job_area.dart';
import 'package:orbijob/features/search/domain/title_pattern.dart';

void main() {
  test('joins keywords with | and escapes every regex metacharacter', () {
    expect(
      titleAlternation(['c++', 'ux/ui', 'node.js']),
      r'c\+\+|ux/ui|node\.js',
    );
    expect(titleAlternation(['a(b)', r'x\y', '[z]']), r'a\(b\)|x\\y|\[z\]');
    expect(titleAlternation(['軟體', 'logística']), '軟體|logística');
  });

  test(
    'the regex is equivalent to "title contains any keyword, ignoring case" for every area and specialty',
    () {
      final titles = [
        'Senior Software Engineer',
        'ENFERMEIRO(A) - UTI',
        'Fisioterapeuta Pélvica',
        'Barista',
        'Kindergarten Teacher',
        '軟體工程師',
        'C++ Developer',
      ];
      final rules = <(String, bool Function(String))>[
        for (final a in JobArea.values)
          (a.titleRegex, (t) => a.keywords.any(t.toLowerCase().contains)),
        for (final s in HealthSpecialty.values)
          (s.titleRegex, (t) => s.keywords.any(t.toLowerCase().contains)),
      ];
      for (final (regex, byKeyword) in rules) {
        final re = RegExp(regex, caseSensitive: false);
        for (final t in titles) {
          expect(re.hasMatch(t), byKeyword(t), reason: '$t against /$regex/');
        }
      }
    },
  );

  test(
    'no area or specialty keyword is empty (an empty alternative would match every title)',
    () {
      for (final a in JobArea.values) {
        expect(
          a.keywords.every((k) => k.trim().isNotEmpty),
          isTrue,
          reason: a.name,
        );
      }
      for (final s in HealthSpecialty.values) {
        expect(
          s.keywords.every((k) => k.trim().isNotEmpty),
          isTrue,
          reason: s.name,
        );
      }
    },
  );
}
