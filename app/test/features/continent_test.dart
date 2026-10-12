import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/continent.dart';

void main() {
  test('every country code belongs to exactly one continent', () {
    final seen = <String, Continent>{};
    for (final k in Continent.values) {
      for (final c in k.countries) {
        expect(
          seen.containsKey(c),
          isFalse,
          reason: '$c is in ${seen[c]} and $k',
        );
        seen[c] = k;
      }
    }
  });

  test(
    'codes are two upper-case ASCII letters, so the filter cannot be altered',
    () {
      for (final k in Continent.values) {
        for (final c in k.countries) {
          expect(RegExp(r'^[A-Z]{2}$').hasMatch(c), isTrue, reason: c);
        }
        expect(RegExp(r'^[A-Za-z0-9._,(){}]+$').hasMatch(k.orFilter), isTrue);
      }
    },
  );

  test('the countries the catalogue shows land where the owner expects', () {
    expect(Continent.ofCountry('SE'), Continent.europe);
    expect(Continent.ofCountry('pt'), Continent.europe);
    expect(Continent.ofCountry('AU'), Continent.oceania);
    expect(Continent.ofCountry('NZ'), Continent.oceania);
    expect(Continent.ofCountry('SG'), Continent.asia);
    expect(Continent.ofCountry('ZA'), Continent.africa);
    expect(Continent.ofCountry('US'), Continent.northAmerica);
    expect(Continent.ofCountry('MX'), Continent.northAmerica);
    expect(Continent.ofCountry('BR'), Continent.southAmerica);
    expect(Continent.ofCountry('ZZ'), isNull);
    expect(Continent.ofCountry(null), isNull);
  });
}
