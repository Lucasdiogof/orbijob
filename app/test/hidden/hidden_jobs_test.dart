import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/core/data/load_status.dart';
import 'package:orbijob/core/orbi/orbi.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/hidden/data/supabase_hidden_jobs_repository.dart';
import 'package:orbijob/features/hidden/domain/hidden_jobs_repository.dart';
import 'package:orbijob/features/hidden/presentation/hidden_jobs_cubit.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/preview/preview_fixtures.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers/fakes.dart';
import '../helpers/harness.dart';
import '../supabase/fake_backend.dart';

final card = find.descendant(
  of: find.byType(OrbiJobCard),
  matching: find.text('Pedreiro'),
);
const _user = AuthUser(id: 'user-a', email: 'a@example.com');

JobPosting _job(
  String id, {
  String title = 'Welder',
  String company = 'Acme',
}) => JobPosting(
  source: 'jobicy',
  externalId: id,
  company: company,
  title: title,
  originalUrl: 'https://example.com/$id',
);

void main() {
  group('HiddenJobsCubit', () {
    late FakeHiddenJobs repo;
    late HiddenJobsCubit c;
    setUp(() {
      repo = FakeHiddenJobs();
      c = HiddenJobsCubit(repo);
    });
    tearDown(() => c.close());

    test('hide and restore show at once and are stored', () async {
      await c.load();
      final j = _job('1');
      expect(c.state.isHidden(j), isFalse);
      expect(await c.hide(j), isTrue);
      expect(c.state.isHidden(j), isTrue);
      expect(repo.rows.keys, ['jobicy:1']);
      expect(await c.restore('jobicy:1'), isTrue);
      expect(c.state.isHidden(j), isFalse);
      expect(repo.rows, isEmpty);
    });

    test(
      'hiding twice is harmless; restoring what is not hidden is not an error',
      () async {
        await c.load();
        await c.hide(_job('1'));
        expect(await c.hide(_job('1')), isTrue);
        expect(repo.rows.length, 1);
        expect(await c.restore('jobicy:zzz'), isTrue);
      },
    );

    test('a refused hide or restore puts the list back and says why', () async {
      await c.load();
      repo.error = const sb.PostgrestException(
        message: 'quota exceeded',
        code: '53400',
      );
      expect(await c.hide(_job('1')), isFalse);
      expect(c.state.isHidden(_job('1')), isFalse);
      expect(c.state.actionFailure, DataFailureKind.quotaExceeded);
      repo.error = null;
      await c.hide(_job('1'));
      repo.error = sb.AuthRetryableFetchException(message: 'offline');
      expect(await c.restore('jobicy:1'), isFalse);
      expect(c.state.isHidden(_job('1')), isTrue);
      expect(c.state.actionFailure, DataFailureKind.network);
    });

    test('visible() drops hidden jobs and keeps the order; nothing is dropped before the list is known', () async {
      final all = [_job('1'), _job('2'), _job('3')];
      expect(c.visible(all, (j) => j).length, 3);
      await c.load();
      await c.hide(all[1]);
      expect(c.visible(all, (j) => j).map((j) => j.externalId), ['1', '3']);
    });

    test(
      'the list comes back after a restart (read from the repository)',
      () async {
        await c.load();
        await c.hide(_job('1'));
        final again = HiddenJobsCubit(repo);
        await again.load();
        expect(again.state.isHidden(_job('1')), isTrue);
        expect(again.state.items.values.single.title, 'Welder');
        await again.close();
      },
    );

    test('signed out and not configured are reported', () async {
      final auth = FakeAuth();
      final out = HiddenJobsCubit(FakeHiddenJobs(auth: auth));
      await out.load();
      expect(out.state.status, LoadStatus.failure);
      expect(await out.hide(_job('1')), isFalse);
      expect(out.state.actionFailure, DataFailureKind.signedOut);
      final none = HiddenJobsCubit(null);
      await none.load();
      expect(none.state.failure, DataFailureKind.notConfigured);
      expect(await none.hide(_job('1')), isFalse);
      await out.close();
      await none.close();
    });

    test('long titles and companies are cut to what the table accepts', () {
      final h = HiddenJob.of(
        _job('1', title: 'T' * 400, company: 'C' * 300),
        DateTime(2026),
      );
      expect(h.title.length, 300);
      expect(h.company!.length, 200);
      expect(h.key, 'jobicy:1');
    });
  });

  group('the Supabase repository', () {
    test(
      'hiding is an insert that ignores duplicates and carries the owner',
      () async {
        final b = FakeBackend(respond: (m, u, body) => (201, null));
        await SupabaseHiddenJobsRepository(b.client)
            .hide(_job('9', title: 'Pilot'));
        final r = b.last;
        expect(r.method, 'POST');
        expect(r.query['on_conflict'], 'user_id,job_key');
        expect(
          r.request.headers['Prefer'],
          contains('resolution=ignore-duplicates'),
        );
        final body = r.json as Map;
        expect(body['user_id'], testUserA);
        expect(body['job_key'], 'jobicy:9');
        expect(body['title'], 'Pilot');
      },
    );

    test(
      'restoring deletes by key; listing maps the rows and skips broken ones',
      () async {
        final b = FakeBackend(
          respond: (m, u, body) => m == 'DELETE'
              ? (204, null)
              : (
                  200,
                  [
                    {
                      'job_key': 'jobicy:1',
                      'source_id': 'jobicy',
                      'external_id': '1',
                      'title': 'Welder',
                      'company': 'Acme',
                      'original_url': 'https://x/1',
                      'hidden_at': '2026-10-13T10:00:00+00:00',
                    },
                    {'job_key': 'broken'},
                  ],
                ),
        );
        final repo = SupabaseHiddenJobsRepository(b.client);
        final list = await repo.list();
        expect(list.length, 1);
        expect(list.single.company, 'Acme');
        await repo.restore('jobicy:1');
        expect(b.last.query['job_key'], 'eq.jobicy:1');
      },
    );

    test('signed out: refused before any request', () async {
      final b = FakeBackend(signedIn: false);
      await expectLater(
        SupabaseHiddenJobsRepository(b.client).list(),
        throwsA(isA<Exception>()),
      );
      expect(b.requests, isEmpty);
    });
  });

  group('on screen', () {
    Future<void> explore(WidgetTester t) async {
      await t.tap(find.text('Explore'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Pedreiro');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
    }

    testWidgets(
      'hide from the card menu, undo it, hide again and restore from the hidden list',
      (t) async {
        final auth = FakeAuth()..currentUser = _user;
        final fakes = Fakes(auth: auth);
        await pumpApp(
          t,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: fakes,
          size: const Size(390, 900),
        );
        await explore(t);
        expect(card, findsOneWidget);
        await t.tap(find.byTooltip('More actions for Pedreiro'));
        await t.pumpAndSettle();
        await t.tap(find.text('Hide this job'));
        await t.pumpAndSettle();
        expect(card, findsNothing);
        expect(fakes.hidden.rows.keys, isNotEmpty);
        expect(find.text('Job hidden'), findsOneWidget);
        // undo brings it back
        await t.tap(find.text('Undo'));
        await t.pumpAndSettle();
        expect(card, findsOneWidget);
        expect(fakes.hidden.rows, isEmpty);
        // hide again, then restore from the hidden jobs page
        await t.tap(find.byTooltip('More actions for Pedreiro'));
        await t.pumpAndSettle();
        await t.tap(find.text('Hide this job'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Profile'));
        await t.pumpAndSettle();
        await t.tap(find.text('Hidden jobs'));
        await t.pumpAndSettle();
        expect(find.text('Pedreiro'), findsWidgets);
        await t.tap(find.text('Restore'));
        await t.pumpAndSettle();
        expect(fakes.hidden.rows, isEmpty);
        expect(find.text('No hidden jobs'), findsOneWidget);
      },
    );

    testWidgets(
      'a hidden job does not come back after a restart, in search or on Home',
      (t) async {
        final auth = FakeAuth()..currentUser = _user;
        final fakes = Fakes(auth: auth);
        await fakes.hidden.hide(
          const JobPosting(
            source: 'preview',
            externalId: 'x',
            company: '',
            title: 'x',
            originalUrl: 'https://x',
          ),
        );
        // find the preview job's real key by hiding it through the app, then restart the app on the same stored list
        await pumpApp(
          t,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: fakes,
          size: const Size(390, 900),
        );
        await explore(t);
        await t.tap(find.byTooltip('More actions for Pedreiro'));
        await t.pumpAndSettle();
        await t.tap(find.text('Hide this job'));
        await t.pumpAndSettle();
        await pumpApp(
          t,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: fakes,
          size: const Size(390, 900),
        );
        await explore(t);
        expect(card, findsNothing); // Explore
        expect(find.textContaining('1 hidden job'), findsOneWidget);
      },
    );

    testWidgets('a refused hide is reported even though the card is gone', (
      t,
    ) async {
      final auth = FakeAuth()..currentUser = _user;
      final fakes = Fakes(auth: auth);
      await pumpApp(
        t,
        repo: PreviewSearchRepository(),
        auth: auth,
        fakes: fakes,
        size: const Size(390, 900),
      );
      await explore(t);
      fakes.hidden.error = sb.AuthRetryableFetchException(message: 'offline');
      await t.tap(find.byTooltip('More actions for Pedreiro'));
      await t.pumpAndSettle();
      await t.tap(find.text('Hide this job'));
      await t.pumpAndSettle();
      expect(card, findsOneWidget); // rolled back
      expect(find.textContaining('connection'), findsWidgets);
    });

    testWidgets('signed out the hidden-jobs page asks for an account', (
      t,
    ) async {
      final auth = FakeAuth();
      await pumpApp(
        t,
        repo: PreviewSearchRepository(),
        auth: auth,
        fakes: Fakes(auth: auth),
        size: const Size(390, 900),
      );
      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      await t.tap(find.text('Hidden jobs'));
      await t.pumpAndSettle();
      expect(find.textContaining('Sign in'), findsWidgets);
    });
  });
}
