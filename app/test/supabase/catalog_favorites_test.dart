import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/data/user_scope.dart';
import 'package:orbijob/features/favorites/data/supabase_favorites_repository.dart';
import 'package:orbijob/features/search/data/job_snapshot.dart';
import 'package:orbijob/features/search/data/supabase_job_catalog_repository.dart';

import 'fake_backend.dart';

// Favourites of CATALOGUE jobs against a mocked PostgREST. The 16 KB snapshot limit and the unique (user, job_key)
// are enforced by the real table (see migration 20261010000000_app_integration.sql); here the client side of that
// contract is checked.

Map<String, Object?> catalogRow({
  String? description,
  Object? company = 'Juniper Square',
}) => {
  'source_id': 'jobicy',
  'external_id': '154956',
  'company': company,
  'title': 'Account Executive, Private Equity',
  'description': description,
  'country': null,
  'work_mode': 'remote',
  'contract_type': 'Full-Time',
  'salary_min': 120000,
  'salary_max': 145000,
  'salary_currency': 'USD',
  'salary_period': 'year',
  'published_at': '2026-10-09T18:42:49+00:00',
  'original_url': 'https://jobicy.com/jobs/154956-account-executive',
  'apply_url': 'https://jobicy.com/jobs/154956-account-executive',
  'status': 'open',
  'geo_restrictions': ['CA', 'US'],
  'job_sources': {
    'id': 'jobicy',
    'attribution': 'x',
    'can_redistribute': true,
    'status': 'CONDITIONAL',
  },
};

void main() {
  final job = jobFromCatalogRow(catalogRow(description: 'Plain text.'))!;

  test('a catalogue job is saved under source:id with the data needed to show and open it later', () async {
    final b = FakeBackend();
    await SupabaseFavoritesRepository(b.client).add(job);
    final r = b.last;
    expect(r.method, 'POST');
    expect(r.path, '/rest/v1/saved_jobs');
    expect(r.query['on_conflict'], 'user_id,job_key');
    final body = r.json as Map;
    expect(body['user_id'], testUserA);
    expect(body['job_key'], 'jobicy:154956');
    final snap = body['snapshot'] as Map;
    expect(snap['source'], 'jobicy');
    expect(snap['sourceName'], 'Jobicy');
    expect(
      snap['originalUrl'],
      'https://jobicy.com/jobs/154956-account-executive',
    );
    expect(snap['geoRestrictions'], ['CA', 'US']);
    expect(snap['salaryCurrency'], 'USD');
  });

  test('the description is never written to the snapshot, so it cannot exceed the 16 KB limit', () async {
    final huge = jobFromCatalogRow(catalogRow(description: 'x' * 200000))!;
    expect(huge.description!.length, 200000);
    final snap = jobToSnapshot(huge);
    expect(snap.containsKey('description'), isFalse);
    expect(utf8.encode(jsonEncode(snap)).length, lessThan(16384));
    final b = FakeBackend();
    await SupabaseFavoritesRepository(b.client).add(huge);
    expect(utf8.encode(b.last.body).length, lessThan(16384));
  });

  test('saving the same job twice is one row (upsert on user + key)', () async {
    final b = FakeBackend();
    final repo = SupabaseFavoritesRepository(b.client);
    await repo.add(job);
    await repo.add(job);
    expect(b.requests.map((r) => (r.json as Map)['job_key']).toSet(), {
      'jobicy:154956',
    });
    expect(
      b.requests.every((r) => r.query['on_conflict'] == 'user_id,job_key'),
      isTrue,
    );
  });

  test('a saved catalogue job comes back identical, with eligibility kept and no description', () async {
    final snap = jobToSnapshot(job);
    final b = FakeBackend(
      respond: (_, _, _) => (
        200,
        [
          {'snapshot': snap},
        ],
      ),
    );
    final back = (await SupabaseFavoritesRepository(b.client).list()).single;
    expect(back, job); // identity: source + external id
    expect(back.geoRestrictions, ['CA', 'US']);
    expect(back.salaryMin, 120000);
    expect(back.sourceName, 'Jobicy');
    expect(back.description, isNull);
    expect(back.originalUrl, job.originalUrl);
  });

  test('a job with no company name is not lost when it is read back', () async {
    final noCompany = jobFromCatalogRow(catalogRow(company: ''))!;
    final snap = jobToSnapshot(noCompany);
    expect(snap['company'], '');
    final back = jobFromSnapshot(snap);
    expect(back, isNotNull);
    expect(back!.company, '');
  });

  test('older snapshots without eligibility still load', () {
    final old = jobToSnapshot(job)..remove('geoRestrictions');
    expect(jobFromSnapshot(old)!.geoRestrictions, isEmpty);
    final weird = jobToSnapshot(job)..['geoRestrictions'] = ['US', 7, '', null];
    expect(jobFromSnapshot(weird)!.geoRestrictions, ['US']);
  });

  test('removal is scoped to the signed-in user and the job key', () async {
    final b = FakeBackend();
    await SupabaseFavoritesRepository(b.client).remove(job);
    final r = b.last;
    expect(r.method, 'DELETE');
    expect(r.query['user_id'], 'eq.$testUserA');
    expect(r.query['job_key'], 'eq.jobicy:154956');
  });

  test('signed out: nothing is sent, the caller is told to sign in', () async {
    final b = FakeBackend(signedIn: false);
    final repo = SupabaseFavoritesRepository(b.client);
    await expectLater(repo.add(job), throwsA(isA<NotSignedInException>()));
    await expectLater(repo.remove(job), throwsA(isA<NotSignedInException>()));
    await expectLater(repo.list(), throwsA(isA<NotSignedInException>()));
    expect(b.requests, isEmpty);
  });

  test(
    'server refusals reach the caller (the Cubit rolls the heart back)',
    () async {
      final b = FakeBackend(
        respond: (_, _, _) =>
            (403, {'code': '53400', 'message': 'quota exceeded'}),
      );
      await expectLater(
        SupabaseFavoritesRepository(b.client).add(job),
        throwsA(anything),
      );
    },
  );
}
