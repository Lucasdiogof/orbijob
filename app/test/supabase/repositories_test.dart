import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/data/user_scope.dart';
import 'package:orbijob/features/applications/data/supabase_applications_repository.dart';
import 'package:orbijob/features/applications/domain/application_record.dart';
import 'package:orbijob/features/favorites/data/supabase_favorites_repository.dart';
import 'package:orbijob/features/preferences/data/supabase_preferences_repository.dart';
import 'package:orbijob/features/preferences/domain/user_preferences.dart';
import 'package:orbijob/features/profile/data/supabase_profile_repository.dart';
import 'package:orbijob/features/profile/data/supabase_resume_repository.dart';
import 'package:orbijob/features/profile/domain/professional_profile.dart';
import 'package:orbijob/features/profile/domain/resume_repository.dart';
import 'package:orbijob/features/search/data/job_snapshot.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';

import 'fake_backend.dart';

final job = JobPosting(
  source: 'lever',
  externalId: 'abc',
  company: 'Beispiel GmbH',
  title: 'Beckenboden-Physiotherapeut:in',
  originalUrl: 'https://example.invalid/j/abc',
  country: 'DE',
  city: 'Berlin',
  workMode: WorkMode.onsite,
  salaryMin: 3400,
  salaryMax: 4100,
  salaryCurrency: 'EUR',
  salaryPeriod: SalaryPeriod.month,
  publishedAt: DateTime.utc(2026, 10, 1),
  language: 'de',
);

void main() {
  group('job snapshot', () {
    test('round-trips every field and omits absent ones', () {
      final snap = jobToSnapshot(job);
      expect(jobFromSnapshot(snap), job);
      final back = jobFromSnapshot(snap)!;
      expect(
        (back.salaryMin, back.language, back.publishedAt),
        (3400.0, 'de', DateTime.utc(2026, 10, 1)),
      );
      final bare = jobToSnapshot(
        const JobPosting(
          source: 's',
          externalId: '1',
          company: 'c',
          title: 't',
          originalUrl: 'u',
        ),
      );
      expect(bare.keys.toSet(), {
        'source',
        'externalId',
        'company',
        'title',
        'originalUrl',
      });
    });
    test('unreadable snapshots are skipped, never guessed', () {
      expect(jobFromSnapshot(null), isNull);
      expect(jobFromSnapshot({'title': 'x'}), isNull);
      expect(jobFromSnapshot('text'), isNull);
    });
    test('key is source:externalId', () => expect(jobKey(job), 'lever:abc'));
  });

  group('signed out', () {
    test('every repository refuses without sending a request', () async {
      final b = FakeBackend(signedIn: false);
      await expectLater(
        SupabaseFavoritesRepository(b.client).list(),
        throwsA(isA<NotSignedInException>()),
      );
      await expectLater(
        SupabaseApplicationsRepository(b.client).list(),
        throwsA(isA<NotSignedInException>()),
      );
      await expectLater(
        SupabaseProfileRepository(b.client).profiles(),
        throwsA(isA<NotSignedInException>()),
      );
      await expectLater(
        SupabasePreferencesRepository(b.client).load(),
        throwsA(isA<NotSignedInException>()),
      );
      await expectLater(
        SupabaseSavedSearchesRepository(b.client).list(),
        throwsA(isA<NotSignedInException>()),
      );
      await expectLater(
        SupabaseResumeRepository(b.client).list('p'),
        throwsA(isA<NotSignedInException>()),
      );
      expect(b.requests, isEmpty);
    });
  });

  group('favourites', () {
    test('add upserts a snapshot keyed per user', () async {
      final b = FakeBackend(respond: (m, u, body) => (201, null));
      await SupabaseFavoritesRepository(b.client).add(job);
      final r = b.last;
      expect((r.method, r.path), ('POST', '/rest/v1/saved_jobs'));
      expect(r.query['on_conflict'], 'user_id,job_key');
      final body = r.json as Map;
      expect(body['user_id'], testUserA);
      expect(body['job_key'], 'lever:abc');
      expect((body['snapshot'] as Map)['title'], job.title);
      expect(r.request.headers['apikey'], testPublishableKey);
    });
    test('list maps snapshots and skips corrupt rows; remove filters by owner and key', () async {
      final b = FakeBackend(
        respond: (m, u, body) => m == 'GET'
            ? (
                200,
                [
                  {'snapshot': jobToSnapshot(job)},
                  {
                    'snapshot': {'broken': true},
                  },
                ],
              )
            : (204, null),
      );
      final repo = SupabaseFavoritesRepository(b.client);
      expect(await repo.list(), [job]);
      await repo.remove(job);
      expect(b.last.method, 'DELETE');
      expect(b.last.query['user_id'], 'eq.$testUserA');
      expect(b.last.query['job_key'], 'eq.lever:abc');
    });
  });

  group('applications', () {
    Map<String, Object?> row(String stage) => {
      'id': 'app-1',
      'job_snapshot': jobToSnapshot(job),
      'stage': stage,
      'channel': 'site',
      'applied_at': '2026-10-02T10:00:00Z',
      'note': null,
      'profile_id': null,
    };
    test('create sends only provided optional fields and stage name', () async {
      final b = FakeBackend(respond: (m, u, body) => (201, row('applied')));
      final rec = await SupabaseApplicationsRepository(b.client)
          .create(job, channel: 'site');
      final body = b.requests.first.json as Map;
      expect(body.keys.toSet(), {
        'user_id',
        'job_snapshot',
        'stage',
        'channel',
      });
      expect(body['stage'], 'applied');
      expect(rec.job, job);
      expect(rec.stage, ApplicationStage.applied);
    });
    test(
      'changing the stage updates only the stage (history is a DB trigger)',
      () async {
        final b = FakeBackend(respond: (m, u, body) => (204, null));
        await SupabaseApplicationsRepository(b.client)
            .changeStage('app-1', ApplicationStage.interview);
        expect(b.last.method, 'PATCH');
        expect(b.last.json, {'stage': 'interview'});
        expect(b.last.query['id'], 'eq.app-1');
        expect(
          b.requests.where((r) => r.path.endsWith('application_events')),
          isEmpty,
        );
      },
    );
    test('history reads events oldest first', () async {
      final b = FakeBackend(
        respond: (m, u, body) => (
          200,
          [
            {
              'stage': 'applied',
              'occurred_at': '2026-10-02T10:00:00Z',
              'note': null,
            },
            {
              'stage': 'interview',
              'occurred_at': '2026-10-05T10:00:00Z',
              'note': 'phone',
            },
          ],
        ),
      );
      final h = await SupabaseApplicationsRepository(b.client).history('app-1');
      expect(h.map((e) => e.stage), [
        ApplicationStage.applied,
        ApplicationStage.interview,
      ]);
      expect(b.last.query['application_id'], 'eq.app-1');
      expect(b.last.query['order'], startsWith('occurred_at.asc'));
    });
    test('list skips rows with unreadable snapshots', () async {
      final b = FakeBackend(
        respond: (m, u, body) => (
          200,
          [
            row('offer'),
            {'id': 'x', 'job_snapshot': {}, 'stage': 'applied'},
          ],
        ),
      );
      final l = await SupabaseApplicationsRepository(b.client).list();
      expect(l.single.stage, ApplicationStage.offer);
    });
  });

  group('preferences and saved searches', () {
    test('load returns defaults when no row exists', () async {
      final b = FakeBackend(respond: (m, u, body) => (200, []));
      expect(
        await SupabasePreferencesRepository(b.client).load(),
        const UserPreferences(),
      );
    });
    test('save upserts the caller row only', () async {
      final b = FakeBackend(respond: (m, u, body) => (201, null));
      await SupabasePreferencesRepository(b.client).save(
        const UserPreferences(
          theme: 'dark',
          locale: 'pt',
          countriesOfInterest: ['BR', 'PT'],
        ),
      );
      expect(b.last.query['on_conflict'], 'user_id');
      expect(b.last.json, {
        'user_id': testUserA,
        'theme': 'dark',
        'locale': 'pt',
        'countries_of_interest': ['BR', 'PT'],
      });
    });
    test('saved searches add/list/remove', () async {
      final b = FakeBackend(
        respond: (m, u, body) => m == 'DELETE'
            ? (204, null)
            : (
                200,
                {
                  'id': 's1',
                  'query': {'q': 'nurse'},
                },
              ),
      );
      final repo = SupabaseSavedSearchesRepository(b.client);
      final s = await repo.add({'q': 'nurse'});
      expect((b.requests.first.json as Map)['user_id'], testUserA);
      expect(s.query, {'q': 'nurse'});
      await repo.remove('s1');
      expect(b.last.query['id'], 'eq.s1');
    });
  });

  group('profile', () {
    test(
      'profile row mapping and insert carries user_id; update does not',
      () async {
        final p = const ProfessionalProfile(
          name: 'Nurse',
          countryOfResidence: 'BR',
          languages: [ProfileLanguage(code: 'pt', level: 'native')],
          occupations: ['2221'],
          skills: ['triage'],
        );
        final stored = {
          'id': 'p1',
          'name': 'Nurse',
          'country_of_residence': 'BR',
          'languages': [
            {'code': 'pt', 'level': 'native'},
          ],
          'occupations': ['2221'],
          'skills': ['triage'],
          'preferences': {},
        };
        final b = FakeBackend(respond: (m, u, body) => (200, stored));
        final repo = SupabaseProfileRepository(b.client);
        final saved = await repo.save(p);
        expect((b.requests.first.json as Map)['user_id'], testUserA);
        expect(saved.id, 'p1');
        expect(saved.languages.single.level, 'native');
        await repo.save(saved);
        expect((b.last.json as Map).containsKey('user_id'), isFalse);
        expect(b.last.query['id'], 'eq.p1');
      },
    );
    test(
      'deleting a profile removes its resume files first, then the profile',
      () async {
        final b = FakeBackend(
          respond: (m, u, body) {
            if (u.path.contains('/storage/')) return (200, <Object>[]);
            if (m == 'GET') {
              return (
                200,
                [
                  {'storage_path': '$testUserA/a.pdf'},
                  {'storage_path': '$testUserA/b.pdf'},
                ],
              );
            }
            return (204, null);
          },
        );
        await SupabaseProfileRepository(b.client).delete('p1');
        final order = [for (final r in b.requests) '${r.method} ${r.path}'];
        expect(order, [
          'GET /rest/v1/resumes',
          'DELETE /storage/v1/object/resumes',
          'DELETE /rest/v1/professional_profiles',
        ]);
        expect((b.requests[1].json as Map)['prefixes'], [
          '$testUserA/a.pdf',
          '$testUserA/b.pdf',
        ]);
      },
    );
    test('a storage failure keeps the profile (no orphaned files)', () async {
      final b = FakeBackend(
        respond: (m, u, body) => u.path.contains('/storage/')
            ? (500, {'message': 'storage down'})
            : (
                200,
                [
                  {'storage_path': '$testUserA/a.pdf'},
                ],
              ),
      );
      await expectLater(
        SupabaseProfileRepository(b.client).delete('p1'),
        throwsA(anything),
      );
      expect(
        b.requests.any((r) => r.path.endsWith('professional_profiles')),
        isFalse,
      );
    });
    test('profile without resumes skips Storage', () async {
      final b = FakeBackend(
        respond: (m, u, body) => m == 'GET' ? (200, []) : (204, null),
      );
      await SupabaseProfileRepository(b.client).delete('p1');
      expect(b.requests.any((r) => r.path.contains('/storage/')), isFalse);
    });
    test('experience and education are written with the owner id', () async {
      final b = FakeBackend(respond: (m, u, body) => (201, {'id': 'e1'}));
      final repo = SupabaseProfileRepository(b.client);
      await repo.addExperience(
        Experience(
          profileId: 'p1',
          company: 'C',
          title: 'T',
          startDate: DateTime(2020, 3, 1),
        ),
      );
      expect((b.last.json as Map)['user_id'], testUserA);
      expect((b.last.json as Map)['start_date'], '2020-03-01');
      await repo.addEducation(
        const Education(profileId: 'p1', institution: 'Uni'),
      );
      expect(b.last.path, '/rest/v1/education');
      expect((b.last.json as Map)['user_id'], testUserA);
    });
  });

  group('resumes', () {
    final pdf = Uint8List.fromList([
      0x25,
      0x50,
      0x44,
      0x46,
      0x2d,
      0x31,
      0x2e,
      0x37,
    ]);
    test('validation: signature, size, empty', () {
      expect(() => validateResume(pdf), returnsNormally);
      expect(
        () => validateResume(Uint8List.fromList([1, 2, 3, 4, 5, 6])),
        throwsA(
          isA<ResumeRejected>().having(
            (e) => e.reason,
            'r',
            ResumeRejection.notPdf,
          ),
        ),
      );
      expect(
        () => validateResume(Uint8List(0)),
        throwsA(
          isA<ResumeRejected>().having(
            (e) => e.reason,
            'r',
            ResumeRejection.empty,
          ),
        ),
      );
      final big = Uint8List(ResumeRepository.maxBytes + 1)..setAll(0, pdf);
      expect(
        () => validateResume(big),
        throwsA(
          isA<ResumeRejected>().having(
            (e) => e.reason,
            'r',
            ResumeRejection.tooLarge,
          ),
        ),
      );
    });
    test('invalid files never reach the network', () async {
      final b = FakeBackend();
      await expectLater(
        SupabaseResumeRepository(b.client)
            .upload('p1', Uint8List.fromList([1, 2, 3, 4, 5, 6])),
        throwsA(isA<ResumeRejected>()),
      );
      expect(b.requests, isEmpty);
    });
    test('upload stores under <user_id>/…pdf in the private bucket, then records the row', () async {
      final b = FakeBackend(
        respond: (m, u, body) => u.path.contains('/storage/')
            ? (200, m == 'DELETE' ? [] : {'Key': 'resumes/x'})
            : (
                201,
                {
                  'id': 'r1',
                  'profile_id': 'p1',
                  'storage_path': 'ignored',
                  'created_at': '2026-10-09T00:00:00Z',
                },
              ),
      );
      await SupabaseResumeRepository(b.client).upload('p1', pdf);
      final storage = b.requests.firstWhere(
        (r) => r.path.contains('/storage/v1/object/resumes/'),
      );
      expect(
        storage.path,
        matches(
          RegExp('^/storage/v1/object/resumes/$testUserA/[0-9a-f]{32}\\.pdf\$'),
        ),
      );
      final row =
          b.requests.firstWhere((r) => r.path == '/rest/v1/resumes').json
              as Map;
      expect(row['user_id'], testUserA);
      expect(row['storage_path'], startsWith('$testUserA/'));
    });
    test('row failure removes the uploaded object (no orphan)', () async {
      final b = FakeBackend(
        respond: (m, u, body) => u.path.contains('/storage/')
            ? (200, {'Key': 'k'})
            : (403, {'message': 'denied'}),
      );
      await expectLater(
        SupabaseResumeRepository(b.client).upload('p1', pdf),
        throwsA(anything),
      );
      expect(
        b.requests.any(
          (r) =>
              r.method == 'DELETE' &&
              r.path.contains('/storage/v1/object/resumes'),
        ),
        isTrue,
      );
    });
    test('signed URLs are short-lived and capped', () async {
      final b = FakeBackend(
        respond: (m, u, body) =>
            (200, {'signedURL': '/object/sign/resumes/x?token=t'}),
      );
      final f = ResumeFile(
        id: 'r1',
        profileId: 'p1',
        path: '$testUserA/a.pdf',
        createdAt: DateTime(2026),
      );
      await SupabaseResumeRepository(b.client)
          .signedUrl(f, validFor: const Duration(hours: 5));
      expect((b.last.json as Map)['expiresIn'], 300);
    });
  });
}
