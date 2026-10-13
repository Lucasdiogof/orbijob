import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/search_suggestions.dart';

void main() {
  group('search suggestions (nothing found)', () {
    test('a narrowed profession suggests the broader one', () {
      expect(
        searchSuggestions('fisioterapia pélvica'),
        contains('fisioterapia'),
      );
      expect(searchSuggestions('civil engineer'), contains('engineer'));
      expect(
        searchSuggestions('desenvolvedor flutter'),
        contains('desenvolvedor'),
      );
    });

    test('a misspelled profession suggests the closest names', () {
      final s = searchSuggestions('electricain');
      expect(s, isNotEmpty);
      expect(s.map((x) => x.toLowerCase()), contains('electrician'));
      expect(searchSuggestions('plumbr'), isNotEmpty);
    });

    test(
      'a correct profession, a place or unrelated text suggests nothing wrong',
      () {
        expect(searchSuggestions('electrician'), isEmpty);
        expect(searchSuggestions('ab'), isEmpty);
        expect(searchSuggestions(''), isEmpty);
        expect(searchSuggestions('zzzzqqqq'), isEmpty);
        expect(searchSuggestions('goiania').contains('goiania'), isFalse);
      },
    );

    test('never suggests the search itself and respects the limit', () {
      for (final t in [
        'nurce',
        'enfermeria',
        'accountnt',
        'desenvolvedor flutter',
      ]) {
        final s = searchSuggestions(t, max: 2);
        expect(s.length, lessThanOrEqualTo(2), reason: t);
        expect(s, isNot(contains(t)));
      }
    });
  });
}
