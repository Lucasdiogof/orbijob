import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/format/fold.dart';
import 'package:orbijob/features/search/domain/continent.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/health_specialty.dart';
import 'package:orbijob/features/search/domain/job_area.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:orbijob/features/searches/domain/saved_search.dart';
import 'package:orbijob/features/searches/domain/search_spec.dart';

/// A job as the golden file describes it (only the fields a saved search can look at).
class _Job {
  _Job(
    this.title, {
    this.country,
    this.city,
    this.geo = const [],
    this.mode = WorkMode.unspecified,
    this.daysAgo,
    this.salary = false,
  });
  final String title;
  final String? country;
  final String? city;
  final List<String> geo;
  final WorkMode mode;
  final int? daysAgo;
  final bool salary;

  Map<String, Object?> toJson() => {
    'title': title,
    'country': country,
    'city': city,
    'geo': geo,
    'mode': mode.name,
    'daysAgo': daysAgo,
    'salary': salary,
  };
}

/// The rules of the catalogue query (SupabaseJobCatalogRepository.search) applied to one job in plain Dart: the reference the database function
/// ops.alert_matches must agree with. The text term is reduced to "the title or the city contains it (or one of its other names)": the full-text
/// part of the real query is not reproduced here.
bool _matches(SearchSpec spec, _Job j) {
  final s = spec.canonical;
  final f = s.filters;
  final t = foldAccents(j.title);
  if (s.term.isNotEmpty) {
    final term = foldAccents(s.term);
    final alts = (s.toQuery()['match'] as Map)['alts'] as List? ?? const [];
    final hit =
        t.contains(term) ||
        foldAccents(j.city ?? '').contains(term) ||
        alts.any(
          (a) => a is List
              ? a.every((p) => t.contains(foldAccents('$p')))
              : t.contains(foldAccents('$a')),
        );
    if (!hit) return false;
  }
  final c = s.countryCode;
  if (c != null) {
    final ok =
        j.country == c ||
        j.geo.contains(c) ||
        (j.mode == WorkMode.remote && j.geo.contains('Anywhere'));
    if (!ok) return false;
  } else if (f.continent != null) {
    final k = f.continent!;
    final ok =
        (j.country != null && k.countries.contains(j.country)) ||
        j.geo.any((g) => k.countries.contains(g) || k.regions.contains(g));
    if (!ok) return false;
  }
  final modes = f.workModes.where((m) => m != WorkMode.unspecified);
  if (modes.isNotEmpty && !modes.contains(j.mode)) return false;
  if (f.area != null && !f.area!.matches(j.title)) return false;
  if (f.specialty != null && !f.specialty!.matches(j.title)) return false;
  final days = f.publishedWithinDays;
  if (days != null && days > 0 && (j.daysAgo == null || j.daysAgo! > days)) {
    return false;
  }
  if (f.onlyWithSalary && !j.salary) return false;
  return true;
}

void main() {
  group('SearchSpec', () {
    test('a stored query reads back to the same search (round trip)', () {
      const spec = SearchSpec(
        term: 'physio',
        filters: JobFilters(
          workModes: {WorkMode.remote, WorkMode.hybrid},
          publishedWithinDays: 7,
          onlyWithSalary: true,
          countryCode: 'DE',
          area: JobArea.health,
          specialty: HealthSpecialty.pelvicPhysio,
        ),
      );
      expect(SearchSpec.fromQuery(spec.toQuery()), spec);
      expect(SearchSpec.fromQuery(spec.toQuery()).toQuery(), spec.toQuery());
    });

    test('the same meaning is the same search, however it was entered', () {
      const a = SearchSpec(term: ' nurse ', countryCode: 'de');
      const b = SearchSpec(
        term: 'nurse',
        filters: JobFilters(countryCode: 'DE'),
      );
      expect(a, b);
      expect(a.toQuery(), b.toQuery());
      expect(
        const SearchSpec(term: 'nurse'),
        isNot(
          const SearchSpec(
            term: 'nurse',
            filters: JobFilters(countryCode: 'DE'),
          ),
        ),
      );
    });

    test('searches saved by earlier builds ({term, country}) still open', () {
      final s = SearchSpec.fromQuery({'term': 'Pedreiro', 'country': 'BR'});
      expect(s.term, 'Pedreiro');
      expect(s.countryCode, 'BR');
      expect(s.filters.workModes, isEmpty);
      expect(SearchSpec.fromQuery({'term': 'x'}).countryCode, isNull);
    });

    test('malformed parts are ignored, never guessed', () {
      final s = SearchSpec.fromQuery({
        'term': 42,
        'country': 'Germany',
        'area': 'astrology',
        'modes': ['remote', 'teleport', 'unspecified', 7],
        'days': -3,
        'continent': 'atlantis',
        'specialty': 'pelvicPhysio', // without a health area it means nothing
      });
      expect(s.term, '');
      expect(s.countryCode, isNull);
      expect(s.filters.area, isNull);
      expect(s.filters.specialty, isNull);
      expect(s.filters.workModes, {WorkMode.remote});
      expect(s.filters.publishedWithinDays, isNull);
      expect(s.filters.continent, isNull);
    });

    test('an empty search is empty; a filter alone is a search', () {
      expect(const SearchSpec().isEmpty, isTrue);
      expect(const SearchSpec(term: '   ').isEmpty, isTrue);
      expect(
        const SearchSpec(filters: JobFilters(area: JobArea.finance)).isEmpty,
        isFalse,
      );
      expect(const SearchSpec(term: 'a').isEmpty, isFalse);
    });

    test('the compiled block carries what the database needs, and a country wins over a continent', () {
      final m =
          const SearchSpec(
                term: 'fisioterapeuta',
                filters: JobFilters(
                  continent: Continent.europe,
                  area: JobArea.health,
                  specialty: HealthSpecialty.pelvicPhysio,
                ),
              ).toQuery()['match']
              as Map;
      expect(m['term'], 'fisioterapeuta');
      expect(m['alts'], contains('physiotherap'));
      expect(m['cc'], contains('DE'));
      expect(m['regions'], isNotEmpty);
      // area, the specialty's own words and its parent's: three title groups, all required
      expect((m['title_groups'] as List).length, 3);
      final withCountry =
          const SearchSpec(
                filters: JobFilters(
                  countryCode: 'BR',
                  continent: Continent.europe,
                ),
              ).toQuery()['match']
              as Map;
      expect(withCountry['country'], 'BR');
      expect(withCountry.containsKey('cc'), isFalse);
    });

    test(
      'the largest possible search stays far below the database limit (12 KiB)',
      () {
        for (final k in Continent.values) {
          for (final sp in HealthSpecialty.values) {
            final q = SearchSpec(
              term: 'x' * 100,
              filters: JobFilters(
                workModes: {WorkMode.remote, WorkMode.hybrid, WorkMode.onsite},
                publishedWithinDays: 30,
                onlyWithSalary: true,
                continent: k,
                area: JobArea.health,
                specialty: sp,
              ),
            ).toQuery();
            expect(
              utf8.encode(jsonEncode(q)).length,
              lessThan(8192),
              reason: '$k $sp',
            );
          }
        }
      },
    );

    test(
      'compiled keywords are plain text (nothing that could act as a pattern)',
      () {
        for (final a in JobArea.values) {
          for (final kw in a.keywords) {
            expect(kw, isNot(contains('%')));
            expect(kw, isNot(contains('_')));
            expect(kw, isNot(contains('\\')));
          }
        }
        for (final sp in HealthSpecialty.values) {
          for (final kw in sp.keywords) {
            expect(kw, isNot(contains('%')));
            expect(kw, isNot(contains('_')));
          }
        }
      },
    );
  });

  group('SavedSearch', () {
    test('exposes its spec and copies only what changes', () {
      final s = SavedSearch(
        id: '1',
        query: const SearchSpec(term: 'nurse').toQuery(),
        name: 'Nurses',
      );
      expect(s.spec.term, 'nurse');
      final t = s.copyWith(
        alertsEnabled: true,
        frequency: AlertFrequency.weekly,
      );
      expect(t.name, 'Nurses');
      expect(t.alertsEnabled, isTrue);
      expect(t.frequency, AlertFrequency.weekly);
      expect(AlertFrequency.parse('bogus'), AlertFrequency.daily);
      expect(AlertFrequency.parse('instant'), AlertFrequency.instant);
    });
  });

  // The database function ops.alert_matches is tested against this file (worker/test/v3-alerts.test.ts): the same specs, the same jobs, the
  // answers the plain-Dart reference gives. Regenerate with UPDATE_GOLDEN=1 flutter test test/searches/search_spec_test.dart.
  group('golden: the compiled searches agree with the app rules', () {
    final specs = <String, SearchSpec>{
      'term-only': const SearchSpec(term: 'nurse'),
      'term-synonym': const SearchSpec(term: 'fisioterapeuta'),
      'profession-qualified': const SearchSpec(term: 'engenheiro civil'),
      'profession-parts': const SearchSpec(term: 'desenvolvedor flutter'),
      'profession-esco': const SearchSpec(term: 'eletricista'),
      'profession-specialty': const SearchSpec(term: 'fisioterapia pélvica'),
      // accents never decide (ops.title_has folds both sides): typed with or without them, the same jobs
      'accent-typed': const SearchSpec(term: 'sênior'),
      'accent-plain': const SearchSpec(term: 'senior'),
      'accent-city': const SearchSpec(term: 'goiania'),
      'accent-profession': const SearchSpec(term: 'médico'),
      'country': const SearchSpec(filters: JobFilters(countryCode: 'BR')),
      'continent': const SearchSpec(
        filters: JobFilters(continent: Continent.europe),
      ),
      'remote-only': const SearchSpec(
        filters: JobFilters(workModes: {WorkMode.remote}),
      ),
      'remote-hybrid': const SearchSpec(
        filters: JobFilters(workModes: {WorkMode.remote, WorkMode.hybrid}),
      ),
      'finance-area': const SearchSpec(
        filters: JobFilters(area: JobArea.finance),
      ),
      'tech-area-de': const SearchSpec(
        filters: JobFilters(area: JobArea.technology, countryCode: 'DE'),
      ),
      'health-physio': const SearchSpec(
        filters: JobFilters(
          area: JobArea.health,
          specialty: HealthSpecialty.physiotherapy,
        ),
      ),
      'health-pelvic': const SearchSpec(
        filters: JobFilters(
          area: JobArea.health,
          specialty: HealthSpecialty.pelvicPhysio,
        ),
      ),
      'last-7-days': const SearchSpec(
        filters: JobFilters(publishedWithinDays: 7),
      ),
      'with-salary': const SearchSpec(
        filters: JobFilters(onlyWithSalary: true),
      ),
      'everything': const SearchSpec(
        term: 'engineer',
        filters: JobFilters(
          workModes: {WorkMode.remote},
          publishedWithinDays: 30,
          onlyWithSalary: true,
          continent: Continent.europe,
          area: JobArea.technology,
        ),
      ),
    };
    final jobs = <_Job>[
      _Job('Desenvolvedor Sênior', country: 'BR', daysAgo: 3),
      _Job('Senior Medico', country: 'PT', city: 'Lisboa', daysAgo: 4),
      _Job(
        'Registered Nurse',
        country: 'DE',
        city: 'Berlin',
        mode: WorkMode.onsite,
        daysAgo: 2,
      ),
      _Job(
        'Enfermeiro(a) UTI',
        country: 'BR',
        city: 'Goiânia',
        mode: WorkMode.onsite,
        daysAgo: 12,
      ),
      _Job('Fisioterapeuta', country: 'BR', mode: WorkMode.onsite, daysAgo: 1),
      _Job(
        'Physiotherapist',
        country: 'GB',
        mode: WorkMode.hybrid,
        daysAgo: 20,
        salary: true,
      ),
      _Job(
        'Pelvic Floor Physiotherapist',
        country: 'DE',
        mode: WorkMode.hybrid,
        daysAgo: 3,
      ),
      _Job(
        'Pelvic Floor Ultrasound Sonographer',
        country: 'DE',
        mode: WorkMode.onsite,
        daysAgo: 3,
      ),
      _Job(
        'Senior Software Engineer',
        mode: WorkMode.remote,
        geo: ['Anywhere'],
        daysAgo: 5,
        salary: true,
      ),
      _Job(
        'Backend Engineer',
        mode: WorkMode.onsite,
        geo: ['Anywhere'],
        daysAgo: 5,
      ),
      _Job(
        'Software Developer',
        country: 'DE',
        mode: WorkMode.remote,
        daysAgo: 40,
        salary: true,
      ),
      _Job(
        'Accountant',
        country: 'US',
        mode: WorkMode.remote,
        geo: ['US', 'CA'],
        daysAgo: 8,
      ),
      _Job(
        'Buchhalter (m/w/d)',
        country: 'AT',
        mode: WorkMode.hybrid,
        daysAgo: 6,
      ),
      _Job('Site Engineer', geo: ['EMEA'], mode: WorkMode.remote, daysAgo: 4),
      _Job('Warehouse Operator', country: 'PL', mode: WorkMode.onsite),
      _Job(
        'Marketing Specialist',
        mode: WorkMode.unspecified,
        daysAgo: 0,
        salary: true,
      ),
      _Job('Bauingenieur (m/w/d)', country: 'AT', daysAgo: 3),
      _Job('Civil Engineer', country: 'GB', daysAgo: 3),
      _Job('Mechanical Engineer', country: 'GB', daysAgo: 3),
      _Job('Senior Flutter-Entwickler', country: 'DE', daysAgo: 3),
      _Job('Flutter Developer', country: 'US', daysAgo: 3),
      _Job('Java Developer', country: 'US', daysAgo: 3),
      _Job('Kfz-Elektriker', country: 'DE', daysAgo: 3),
      _Job('Electrician', country: 'GB', daysAgo: 3),
      _Job('Electrical Engineer', country: 'GB', daysAgo: 3),
      _Job('Beckenbodenphysiotherapeut', country: 'DE', daysAgo: 3),
      _Job('Physiotherapist', country: 'DE', daysAgo: 3),
      _Job(
        'Line Cook',
        country: 'BR',
        city: 'São Paulo',
        mode: WorkMode.onsite,
        daysAgo: 9,
      ),
    ];

    Map<String, Object?> build() => {
      'jobs': [for (final j in jobs) j.toJson()],
      'searches': [
        for (final e in specs.entries)
          {
            'name': e.key,
            'query': e.value.toQuery(),
            'expected': [for (final j in jobs) _matches(e.value, j)],
          },
      ],
    };

    test('the golden file is current', () {
      final file = File('../worker/test/fixtures/v3-specs.golden.json');
      final text = '${const JsonEncoder.withIndent('  ').convert(build())}\n';
      if (Platform.environment['UPDATE_GOLDEN'] == '1') {
        file.writeAsStringSync(text);
      }
      expect(
        file.existsSync(),
        isTrue,
        reason: 'run once with UPDATE_GOLDEN=1',
      );
      expect(jsonDecode(file.readAsStringSync()), jsonDecode(text));
    });

    test('the reference itself behaves (sanity)', () {
      final n = specs['term-only']!;
      expect(jobs.where((j) => _matches(n, j)).map((j) => j.title), [
        'Registered Nurse',
        'Enfermeiro(a) UTI',
      ]); // nurse also finds its other names
      List<String> titles(String name) => [
        for (final j in jobs)
          if (_matches(specs[name]!, j)) j.title,
      ];
      expect(titles('health-pelvic'), [
        'Pelvic Floor Physiotherapist',
        'Beckenbodenphysiotherapeut',
      ]);
      // a profession keeps its qualifier: other engineers, other developers and other physiotherapists are not matches
      expect(titles('profession-qualified'), [
        'Bauingenieur (m/w/d)',
        'Civil Engineer',
      ]);
      expect(titles('profession-parts'), [
        'Senior Flutter-Entwickler',
        'Flutter Developer',
      ]);
      expect(titles('profession-esco'), ['Kfz-Elektriker', 'Electrician']);
      expect(titles('profession-specialty'), [
        'Pelvic Floor Physiotherapist',
        'Beckenbodenphysiotherapeut',
      ]);
    });
  });
}
