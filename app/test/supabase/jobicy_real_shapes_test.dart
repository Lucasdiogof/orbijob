import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/format/job_format.dart';
import 'package:orbijob/features/search/data/supabase_job_catalog_repository.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/l10n/app_localizations.dart';

import 'fake_backend.dart';

// Shapes observed in the first real Jobicy ingestion (299 listings, 2026-10-10), rebuilt with made-up text: nothing here is
// real listing content. Mocked HTTP only. What matters is how the app maps and shows each geographic and salary shape.

const _jobicy = {
  'id': 'jobicy',
  'attribution': 'Remote jobs via Jobicy (https://jobicy.com)',
  'can_redistribute': true,
  'status': 'CONDITIONAL',
};

Map<String, Object?> row(
  String ext, {
  Object? country,
  List<String> geo = const [],
  Object? min,
  Object? max,
  String? cur,
  String? per,
}) => {
  'id': '00000000-0000-0000-0000-0000000$ext',
  'source_id': 'jobicy',
  'external_id': ext,
  'company': 'Example Co',
  'title': 'Example role $ext',
  'description': 'Plain text description.',
  'country': country,
  'city': null,
  'language': null,
  'work_mode': 'remote',
  'contract_type': 'Full-Time',
  'salary_min': min,
  'salary_max': max,
  'salary_currency': cur,
  'salary_period': per,
  'published_at': '2026-10-09T18:42:49+00:00',
  'original_url': 'https://jobicy.com/jobs/$ext-example',
  'apply_url': 'https://jobicy.com/jobs/$ext-example',
  'status': 'open',
  'geo_restrictions': geo,
  'job_sources': _jobicy,
};

Future<JobPosting> load(Map<String, Object?> r) async {
  final b = FakeBackend(
    respond: (m, url, _) => url.path.endsWith('/job_sources')
        ? (
            200,
            [
              {'id': 'jobicy'},
            ],
          )
        : (200, [r]),
  );
  final repo = SupabaseJobCatalogRepository(
    b.client,
    now: () => DateTime.utc(2026, 10, 10, 12),
  );
  final res = await repo.search('');
  return res.jobs.single.job;
}

void main() {
  late AppLocalizations l;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('geographic shapes of the real data are preserved, never widened', () {
    test('US only (156 of 299): country US and the list kept', () async {
      final j = await load(row('1', country: 'US', geo: ['US']));
      expect(j.country, 'US');
      expect(j.geoRestrictions, ['US']);
    });

    test(
      'several countries (e.g. CA+US): no single country is invented',
      () async {
        final j = await load(row('2', geo: ['CA', 'US']));
        expect(j.country, isNull);
        expect(j.geoRestrictions, ['CA', 'US']);
        expect(placeLabel(j, l), 'Canada, United States');
      },
    );

    test('regions stay regions (EMEA, LATAM, APAC, Europe) and are not expanded into countries', () async {
      for (final g in ['EMEA', 'LATAM', 'APAC', 'Europe']) {
        final j = await load(row('3', geo: [g]));
        expect(j.country, isNull);
        expect(j.geoRestrictions, [g]);
      }
    });

    test('mixed countries and regions keep their order', () async {
      final j = await load(
        row('4', geo: ['CA', 'US', 'APAC', 'EMEA', 'LATAM']),
      );
      expect(j.geoRestrictions, ['CA', 'US', 'APAC', 'EMEA', 'LATAM']);
    });

    test('a missing or empty location (5 of 299 are stored as an empty list): the app claims no place and no eligibility', () async {
      final j = await load(row('5'));
      expect(j.geoRestrictions, isEmpty);
      expect(j.country, isNull);
      expect(placeLabel(j, l), isNull);
    });
  });

  group('attribution and link', () {
    test(
      'the source is named Jobicy and the original Jobicy URL is kept',
      () async {
        final j = await load(row('6', country: 'US', geo: ['US']));
        expect(j.sourceName, 'Jobicy');
        expect(j.originalUrl, 'https://jobicy.com/jobs/6-example');
        expect(l.sourceLabel(j.sourceName!), contains('Jobicy'));
      },
    );
  });

  group('salary shapes', () {
    test('range with currency and period', () async {
      final j = await load(
        row(
          '7',
          country: 'US',
          geo: ['US'],
          min: 120000,
          max: 145000,
          cur: 'USD',
          per: 'year',
        ),
      );
      expect(formatSalary(j, l), contains('120,000–145,000'));
    });

    test('equal min and max is shown once', () async {
      final j = await load(
        row('8', min: 150000, max: 150000, cur: 'USD', per: 'year'),
      );
      expect(formatSalary(j, l), isNot(contains('–')));
    });

    test('no salary: nothing is shown', () async {
      final j = await load(row('9'));
      expect(formatSalary(j, l), isNull);
    });

    test('a salary with only one side (5 of 299) is shown as "Up to", never like an exact amount', () async {
      final j = await load(
        row('10', min: null, max: 110000, cur: 'USD', per: 'year'),
      );
      final s = formatSalary(j, l)!;
      expect(s, anyOf(contains('up to'), contains('Up to')));
    });
  });
}
