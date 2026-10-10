import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/data/supabase_job_catalog_repository.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_backend.dart';

// Mocked HTTP: nothing here talks to a real Supabase project. The Worker's PGlite tests (worker/test/rls.test.ts and
// jobicy-schema.test.ts) are what exercise the real policy and table; this file checks what the app sends and does
// with the answers.

const _jobicy = {
  'id': 'jobicy',
  'attribution': 'Remote jobs via Jobicy (https://jobicy.com)',
  'can_redistribute': true,
  'status': 'CONDITIONAL',
};

/// A row shaped like what PostgREST returns for the select in the repository (values mirror a real Jobicy listing).
Map<String, Object?> row({
  String ext = '154956',
  String title = 'Account Executive, Private Equity',
  Object? company = 'Juniper Square',
  Object? source = _jobicy,
  Map<String, Object?> extra = const {},
}) => {
  'id': '00000000-0000-0000-0000-0000000$ext',
  'source_id': 'jobicy',
  'external_id': ext,
  'company': company,
  'title': title,
  'description': 'Plain text description.',
  'country': 'US',
  'city': null,
  'language': null,
  'work_mode': 'remote',
  'contract_type': 'Full-Time',
  'salary_min': 120000,
  'salary_max': 145000,
  'salary_currency': 'USD',
  'salary_period': 'year',
  'published_at': '2026-10-09T18:42:49+00:00',
  'original_url': 'https://jobicy.com/jobs/$ext-account-executive',
  'apply_url': 'https://jobicy.com/jobs/$ext-account-executive',
  'status': 'open',
  'geo_restrictions': ['US'],
  'job_sources': source,
  ...extra,
};

(int, Object?) Function(String, Uri, String) answer(
  List<Object?> jobs, {
  List<Object?> sources = const [
    {'id': 'jobicy'},
  ],
}) =>
    (m, url, _) =>
        url.path.endsWith('/job_sources') ? (200, sources) : (200, jobs);

void main() {
  final fixedNow = DateTime.utc(2026, 10, 10, 12);
  SupabaseJobCatalogRepository repoFor(FakeBackend b) =>
      SupabaseJobCatalogRepository(b.client, now: () => fixedNow);

  group('request shape', () {
    test('reads public.jobs with the publishable key, only open jobs of authorised sources', () async {
      final b = FakeBackend(respond: answer([row()]));
      await repoFor(b).search('flutter');
      final r = b.requests.first;
      expect(r.method, 'GET');
      expect(r.path, '/rest/v1/jobs');
      expect(r.request.headers['apikey'], testPublishableKey);
      expect(r.query['status'], 'eq.open');
      expect(r.query['select'], contains('job_sources!inner('));
      expect(r.query['job_sources.can_redistribute'], 'eq.true');
      expect(
        r.query['job_sources.status'],
        allOf(contains('READY'), contains('CONDITIONAL')),
      );
    });

    test('works signed out: the anon key is the bearer, no user id is sent anywhere', () async {
      final b = FakeBackend(signedIn: false, respond: answer([row()]));
      final res = await repoFor(b).search('');
      expect(res.jobs, hasLength(1));
      expect(b.requests.first.request.headers['apikey'], testPublishableKey);
      expect(
        b.requests.first.request.headers['Authorization'],
        'Bearer $testPublishableKey',
      );
      expect(
        b.requests.first.request.url.toString(),
        isNot(contains(testUserA)),
      );
    });

    test(
      'never touches a service key: the only credential is the publishable one',
      () async {
        final b = FakeBackend(respond: answer([row()]));
        await repoFor(b).search('x');
        for (final r in b.requests) {
          expect(r.request.headers['apikey'], testPublishableKey);
          expect(
            r.request.headers.values.join(' '),
            isNot(contains('service_role')),
          );
        }
      },
    );

    test('stable ordering: newest first, id as tie-break; page = offset and limit + 1 row', () async {
      final b = FakeBackend(respond: answer([row()]));
      await repoFor(b).search('', offset: 40, limit: 20);
      final q = b.requests.first.query;
      expect(q['order'], 'published_at.desc.nullslast,id.desc.nullslast');
      expect(q['offset'], '40');
      expect(q['limit'], '21');
    });

    test('limit is clamped and negative offsets are ignored', () async {
      final b = FakeBackend(respond: answer([row()]));
      await repoFor(b).search('', offset: -5, limit: 9999);
      expect(b.requests.first.query['offset'], '0');
      expect(b.requests.first.query['limit'], '101');
    });
  });

  group('text search', () {
    test(
      'uses the generated search column and a title substring, in one OR group',
      () async {
        final b = FakeBackend(respond: answer([row()]));
        await repoFor(b).search('  Flutter  Developer ');
        final or =
            b.requests.first.request.url.queryParametersAll['or']!.single;
        expect(
          or,
          '(search.wfts(simple).Flutter Developer,title.ilike.*Flutter Developer*)',
        );
      },
    );

    test('an empty or punctuation-only query adds no text filter (browse the newest)', () async {
      for (final q in ['', '   ', ',()"*%']) {
        final b = FakeBackend(respond: answer([row()]));
        await repoFor(b).search(q);
        expect(
          b.requests.first.request.url.queryParametersAll.containsKey('or'),
          isFalse,
          reason: q,
        );
      }
    });

    test('user text can never add filters or break the OR list', () async {
      final b = FakeBackend(respond: answer([row()]));
      await repoFor(b).search('a),status.eq.closed,(b"c*d%e_f\\g');
      final or = b.requests.first.request.url.queryParametersAll['or']!.single;
      expect(or, startsWith('(search.wfts(simple).'));
      expect(or, endsWith('*)'));
      // exactly two top-level terms: one comma between them, none from the user
      expect(','.allMatches(or).length, 1);
      expect('('.allMatches(or).length, 2); // the group and wfts(simple)
      expect(')'.allMatches(or).length, 2);
      expect(or, isNot(contains('"')));
      expect(b.requests.first.query['status'], 'eq.open');
    });

    test('keeps accents, digits and tech symbols; trims to 100 characters', () {
      expect(
        sanitizeSearchTerm('Eletricista – São Paulo'),
        'Eletricista São Paulo',
      );
      expect(sanitizeSearchTerm('C++ / C# dev'), 'C++ C# dev');
      expect(sanitizeSearchTerm('x' * 300).length, 100);
    });
  });

  group('filters', () {
    test(
      'work mode becomes an IN list (unspecified is never offered)',
      () async {
        final b = FakeBackend(respond: answer([row()]));
        await repoFor(b).search(
          '',
          filters: const JobFilters(
            workModes: {WorkMode.remote, WorkMode.hybrid},
          ),
        );
        expect(
          b.requests.first.query['work_mode'],
          allOf(contains('remote'), contains('hybrid'), startsWith('in.')),
        );
      },
    );

    test('publication window is computed from the injected clock', () async {
      final b = FakeBackend(respond: answer([row()]));
      await repoFor(b)
          .search('', filters: const JobFilters(publishedWithinDays: 7));
      expect(
        b.requests.first.query['published_at'],
        'gte.2026-10-03T12:00:00.000Z',
      );
    });

    test(
      '"only with salary" requires an amount, a currency and a period',
      () async {
        final b = FakeBackend(respond: answer([row()]));
        await repoFor(b)
            .search('', filters: const JobFilters(onlyWithSalary: true));
        final u = b.requests.first.request.url;
        expect(
          u.queryParametersAll['or']!.single,
          '(salary_min.not.is.null,salary_max.not.is.null)',
        );
        expect(b.requests.first.query['salary_currency'], 'not.is.null');
        expect(b.requests.first.query['salary_period'], 'not.is.null');
      },
    );

    test('country matches the job, an explicit eligibility entry, or a remote job the source marks as Anywhere (an EMPTY list is unknown and never matches)', () async {
      final b = FakeBackend(respond: answer([row()]));
      await repoFor(b).search('', filters: const JobFilters(countryCode: 'pt'));
      expect(
        b.requests.first.request.url.queryParametersAll['or']!.single,
        '(country.eq.PT,geo_restrictions.cs.{PT},and(work_mode.eq.remote,geo_restrictions.cs.{Anywhere}))',
      );
    });

    test('only jobs the source vouched for within 72 hours are requested (a stale "open" job is never offered)', () async {
      final b = FakeBackend(respond: answer([row()]));
      await repoFor(b).search('');
      final v = b
          .requests
          .first
          .request
          .url
          .queryParametersAll['last_checked_at']!
          .single;
      expect(v, startsWith('gte.'));
      expect(
        DateTime.parse(v.substring(4)),
        fixedNow.subtract(
          SupabaseJobCatalogRepository.defaultMaxVerificationAge,
        ),
      );
      expect(
        SupabaseJobCatalogRepository.defaultMaxVerificationAge,
        const Duration(hours: 72),
      );
    });

    test('an invalid country code is ignored, not sent', () async {
      expect(normalizeCountry('Portugal'), isNull);
      expect(normalizeCountry('p1'), isNull);
      expect(normalizeCountry(' br '), 'BR');
      final b = FakeBackend(respond: answer([row()]));
      await repoFor(b)
          .search('', filters: const JobFilters(countryCode: 'Portugal'));
      expect(
        b.requests.first.request.url.queryParametersAll.containsKey('or'),
        isFalse,
      );
    });

    test('text and country together produce two independent OR groups (ANDed by the server)', () async {
      final b = FakeBackend(respond: answer([row()]));
      await repoFor(b)
          .search('nurse', filters: const JobFilters(countryCode: 'CA'));
      expect(
        b.requests.first.request.url.queryParametersAll['or'],
        hasLength(2),
      );
    });

    test('the legacy countryCode argument still works and the filter wins when both are given', () async {
      final b = FakeBackend(respond: answer([row()]));
      await repoFor(b).search('', countryCode: 'DE');
      expect(
        b.requests.first.request.url.queryParametersAll['or']!.single,
        contains('country.eq.DE'),
      );
      final b2 = FakeBackend(respond: answer([row()]));
      await repoFor(b2).search(
        '',
        countryCode: 'DE',
        filters: const JobFilters(countryCode: 'FR'),
      );
      expect(
        b2.requests.first.request.url.queryParametersAll['or']!.single,
        contains('country.eq.FR'),
      );
    });
  });

  group('pagination', () {
    test(
      'a full page plus one extra row means "more"; the extra row is not shown',
      () async {
        final rows = [
          for (var i = 1; i <= 21; i++) row(ext: '$i', title: 'Job $i'),
        ];
        final b = FakeBackend(respond: answer(rows));
        final r = await repoFor(b).search('', limit: 20);
        expect(r.jobs, hasLength(20));
        expect(r.hasMore, isTrue);
        expect(r.consumed, 20);
        expect(r.jobs.last.job.externalId, '20');
      },
    );

    test('a short page ends the list', () async {
      final b = FakeBackend(
        respond: answer([row(ext: '1'), row(ext: '2')]),
      );
      final r = await repoFor(b).search('', limit: 20);
      expect(r.hasMore, isFalse);
      expect(r.consumed, 2);
    });

    test('skipped invalid rows still advance the offset (consumed counts server rows)', () async {
      final rows = [
        row(ext: '1'),
        row(ext: '2', extra: {'original_url': 'javascript:alert(1)'}),
        row(ext: '3', extra: {'status': 'closed'}),
        row(ext: '4'),
      ];
      final r = await repoFor(FakeBackend(respond: answer(rows)))
          .search('', limit: 20);
      expect(r.jobs.map((j) => j.job.externalId), ['1', '4']);
      expect(r.consumed, 4);
    });
  });

  group('empty catalogue and unauthorised sources', () {
    test('no rows and no authorised source: "no integrated source", not "nothing found"', () async {
      final b = FakeBackend(respond: answer([], sources: []));
      final r = await repoFor(b).search('nurse');
      expect(r.hasIntegratedSource, isFalse);
      expect(r.jobs, isEmpty);
      final srcReq = b.requests.last;
      expect(srcReq.path, '/rest/v1/job_sources');
      expect(srcReq.query['can_redistribute'], 'eq.true');
      expect(
        srcReq.query['status'],
        allOf(contains('READY'), contains('CONDITIONAL')),
      );
    });

    test(
      'no rows but an authorised source exists: an honest empty result',
      () async {
        final r = await repoFor(FakeBackend(respond: answer([])))
            .search('nurse');
        expect(r.hasIntegratedSource, isTrue);
        expect(r.jobs, isEmpty);
        expect(r.hasMore, isFalse);
      },
    );

    test('an empty later page does not trigger the source check', () async {
      final b = FakeBackend(respond: answer([]));
      await repoFor(b).search('nurse', offset: 20);
      expect(b.requests.where((r) => r.path.endsWith('/job_sources')), isEmpty);
    });

    test('rows of a source that is not authorised are dropped even if the server sent them', () {
      for (final bad in <Object?>[
        {..._jobicy, 'can_redistribute': false},
        {..._jobicy, 'status': 'RESEARCH'},
        {..._jobicy, 'status': 'BLOCKED'},
        {..._jobicy, 'can_redistribute': null},
        null,
        'jobicy',
      ]) {
        expect(jobFromCatalogRow(row(source: bad)), isNull, reason: '$bad');
      }
      expect(
        jobFromCatalogRow(row(source: [_jobicy])),
        isNotNull,
        reason: 'embed as one-element list',
      );
    });

    test('closed, unknown-status and expired rows are dropped', () {
      for (final s in ['closed', 'unknown', null, 'OPEN']) {
        expect(
          jobFromCatalogRow(row(extra: {'status': s})),
          isNull,
          reason: '$s',
        );
      }
    });
  });

  group('row mapping', () {
    test('a complete Jobicy row keeps source, attribution name, links, eligibility and salary', () {
      final j = jobFromCatalogRow(row())!;
      expect(j.source, 'jobicy');
      expect(j.sourceName, 'Jobicy');
      expect(j.company, 'Juniper Square');
      expect(j.originalUrl, 'https://jobicy.com/jobs/154956-account-executive');
      expect(j.applyUrl, j.originalUrl);
      expect(j.workMode, WorkMode.remote);
      expect(j.country, 'US');
      expect(j.geoRestrictions, ['US']);
      expect(j.salaryMin, 120000);
      expect(j.salaryMax, 145000);
      expect(j.salaryCurrency, 'USD');
      expect(j.salaryPeriod, SalaryPeriod.year);
      expect(j.publishedAt, DateTime.utc(2026, 10, 9, 18, 42, 49));
      expect(j.description, 'Plain text description.');
    });

    test(
      'an unknown source falls back to its attribution text, then to its id',
      () {
        final a = jobFromCatalogRow(
          row(
            source: {..._jobicy, 'id': 'x', 'attribution': 'Via Example'},
            extra: {'source_id': 'example'},
          ),
        )!;
        expect(a.sourceName, 'Via Example');
        final b = jobFromCatalogRow(
          row(
            source: {..._jobicy, 'attribution': null},
            extra: {'source_id': 'example'},
          ),
        )!;
        expect(b.sourceName, 'example');
      },
    );

    test('sparse rows are accepted: optional fields stay empty, nothing is invented', () {
      final j = jobFromCatalogRow({
        'source_id': 'jobicy',
        'external_id': '9',
        'title': 'Barista',
        'company': '',
        'original_url': 'https://jobicy.com/jobs/9',
        'status': 'open',
        'job_sources': _jobicy,
      })!;
      expect(j.company, '');
      expect(j.country, isNull);
      expect(j.workMode, WorkMode.unspecified);
      expect(j.salaryMin, isNull);
      expect(j.publishedAt, isNull);
      expect(j.geoRestrictions, isEmpty);
      expect(j.description, isNull);
      expect(j.applyUrl, isNull);
    });

    test('rows without identity or title are skipped', () {
      for (final k in ['source_id', 'external_id', 'title', 'original_url']) {
        expect(jobFromCatalogRow(row(extra: {k: null})), isNull, reason: k);
        expect(
          jobFromCatalogRow(row(extra: {k: '  '})),
          isNull,
          reason: '$k blank',
        );
      }
      expect(jobFromCatalogRow(null), isNull);
      expect(jobFromCatalogRow('x'), isNull);
    });

    test('links: only http(s) with a host; a bad apply link is dropped, a bad original link drops the job', () {
      for (final bad in [
        'javascript:alert(1)',
        'data:text/html,x',
        '/jobs/1',
        'ftp://x.com/1',
        'not a url',
        'https://',
        '',
      ]) {
        expect(
          jobFromCatalogRow(row(extra: {'original_url': bad})),
          isNull,
          reason: bad,
        );
        expect(
          jobFromCatalogRow(row(extra: {'apply_url': bad}))!.applyUrl,
          isNull,
          reason: 'apply $bad',
        );
      }
      expect(
        jobFromCatalogRow(
          row(extra: {'original_url': 'http://jobicy.com/jobs/1'}),
        )!.originalUrl,
        'http://jobicy.com/jobs/1',
      );
    });

    test('salary is shown only when amount, currency and period are all valid and consistent', () {
      JobPosting? with_(Map<String, Object?> extra) =>
          jobFromCatalogRow(row(extra: extra));
      expect(with_({'salary_currency': null})!.salaryMin, isNull);
      expect(with_({'salary_currency': 'usd'})!.salaryMin, isNull);
      expect(with_({'salary_currency': 'US'})!.salaryMin, isNull);
      expect(with_({'salary_period': null})!.salaryMin, isNull);
      expect(with_({'salary_period': 'fortnight'})!.salaryMin, isNull);
      expect(
        with_({'salary_min': 200000, 'salary_max': 100000})!.salaryMin,
        isNull,
      );
      expect(with_({'salary_min': -1})!.salaryMin, isNull);
      expect(
        with_({'salary_min': null, 'salary_max': null})!.salaryMin,
        isNull,
      );
      // a single-sided range is legitimate
      final one = with_({'salary_min': 90000, 'salary_max': null})!;
      expect([one.salaryMin, one.salaryMax], [90000, null]);
      // PostgREST can send numerics as strings
      final str = with_({
        'salary_min': '60',
        'salary_max': '70.5',
        'salary_period': 'hour',
      })!;
      expect(
        [str.salaryMin, str.salaryMax, str.salaryPeriod],
        [60, 70.5, SalaryPeriod.hour],
      );
    });

    test(
      'geo restrictions keep codes, regions and unknown names as written',
      () {
        final j = jobFromCatalogRow(
          row(
            extra: {
              'geo_restrictions': ['CA', 'EMEA', ' Atlantis ', '', 7],
            },
          ),
        )!;
        expect(j.geoRestrictions, ['CA', 'EMEA', 'Atlantis']);
      },
    );
  });

  group('errors surface to the caller (the cubit turns them into a retryable state)', () {
    test('HTTP 500 throws', () async {
      final b = FakeBackend(respond: (_, _, _) => (500, {'message': 'boom'}));
      await expectLater(
        repoFor(b).search('x'),
        throwsA(isA<PostgrestException>()),
      );
    });
    test(
      'an expired session (401 / PGRST303) throws a mappable error',
      () async {
        final b = FakeBackend(
          respond: (_, _, _) =>
              (401, {'code': 'PGRST303', 'message': 'JWT expired'}),
        );
        await expectLater(
          repoFor(b).search('x'),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', 'PGRST303'),
          ),
        );
      },
    );
  });
}
