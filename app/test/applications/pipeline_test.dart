import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/core/orbi/orbi.dart';
import 'package:orbijob/features/applications/applications_cubit.dart';
import 'package:orbijob/features/applications/data/supabase_applications_repository.dart';
import 'package:orbijob/features/applications/domain/application_agenda.dart';
import 'package:orbijob/features/applications/domain/application_record.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/preview/preview_fixtures.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers/fakes.dart';
import '../helpers/harness.dart';
import '../supabase/fake_backend.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.com');
final _now = DateTime(2026, 10, 13, 12);

ApplicationRecord _app(
  String id, {
  ApplicationStage stage = ApplicationStage.applied,
  DateTime? interview,
  DateTime? followUp,
  String title = 'Nurse',
}) => ApplicationRecord(
  id: id,
  stage: stage,
  interviewAt: interview,
  followUpAt: followUp,
  job: JobPosting(
    source: 'manual',
    externalId: id,
    company: 'Acme',
    title: title,
    originalUrl: '',
  ),
);

void main() {
  group('stages', () {
    test(
      'the pipeline: interested and hired exist, old stages and names are kept',
      () {
        expect(ApplicationStage.values.map((s) => s.name), [
          'interested',
          'applied',
          'screening',
          'interview',
          'offer',
          'hired',
          'rejected',
          'withdrawn',
          'closed',
        ]);
        expect(ApplicationStage.values.where((s) => s.isActive), [
          ApplicationStage.interested,
          ApplicationStage.applied,
          ApplicationStage.screening,
          ApplicationStage.interview,
          ApplicationStage.offer,
        ]);
      },
    );

    test('only stages that exist after applying imply an application date; "interested" never does', () {
      expect(ApplicationStage.interested.impliesApplied, isFalse);
      expect(ApplicationStage.rejected.impliesApplied, isFalse);
      expect(ApplicationStage.withdrawn.impliesApplied, isFalse);
      for (final s in [
        ApplicationStage.applied,
        ApplicationStage.screening,
        ApplicationStage.interview,
        ApplicationStage.offer,
        ApplicationStage.hired,
      ]) {
        expect(s.impliesApplied, isTrue);
      }
    });
  });

  group('agenda', () {
    test('lists interviews and follow-ups of open processes in the next 14 days; overdue first', () {
      final items = buildAgenda([
        _app('a', interview: DateTime(2026, 10, 15, 14)),
        _app('b', followUp: DateTime(2026, 10, 20)),
        _app('c', interview: DateTime(2026, 10, 10, 9)),
        _app('d', interview: DateTime(2026, 12, 25)),
        _app(
          'e',
          stage: ApplicationStage.rejected,
          interview: DateTime(2026, 10, 14),
        ),
        _app(
          'f',
          stage: ApplicationStage.hired,
          followUp: DateTime(2026, 10, 14),
        ),
      ], _now);
      expect(items.map((e) => e.application.id), ['c', 'a', 'b']);
      expect(items.first.overdue, isTrue);
      expect(items[1].overdue, isFalse);
    });

    test('a follow-up is a day: not overdue until the day is over; an interview is overdue as soon as its time passes', () {
      final today = buildAgenda([
        _app('a', followUp: DateTime(2026, 10, 13)),
      ], _now);
      expect(today.single.overdue, isFalse);
      final yesterday = buildAgenda([
        _app('a', followUp: DateTime(2026, 10, 12)),
      ], _now);
      expect(yesterday.single.overdue, isTrue);
      final earlier = buildAgenda([
        _app('a', interview: DateTime(2026, 10, 13, 9)),
      ], _now);
      expect(earlier.single.overdue, isTrue);
      final later = buildAgenda([
        _app('a', interview: DateTime(2026, 10, 13, 15)),
      ], _now);
      expect(later.single.overdue, isFalse);
    });

    test('very old dates are history, not reminders; both dates of one process appear', () {
      expect(
        buildAgenda([_app('a', interview: DateTime(2026, 8, 1))], _now),
        isEmpty,
      );
      final both = buildAgenda([
        _app(
          'a',
          interview: DateTime(2026, 10, 14, 10),
          followUp: DateTime(2026, 10, 16),
        ),
      ], _now);
      expect(both.map((e) => e.kind), [
        AgendaKind.interview,
        AgendaKind.followUp,
      ]);
    });

    test('nextDate: the interview first, otherwise the follow-up; none once the process is over', () {
      final both = _app(
        'a',
        interview: DateTime(2026, 10, 14),
        followUp: DateTime(2026, 10, 20),
      );
      expect(both.nextDate, DateTime(2026, 10, 14));
      expect(
        _app('b', followUp: DateTime(2026, 10, 20)).nextDate,
        DateTime(2026, 10, 20),
      );
      expect(
        _app(
          'c',
          stage: ApplicationStage.closed,
          followUp: DateTime(2026, 10, 20),
        ).nextDate,
        isNull,
      );
    });
  });

  group('cubit', () {
    late FakeApplications repo;
    late ApplicationsCubit c;
    setUp(() {
      repo = FakeApplications();
      c = ApplicationsCubit(
        repo,
        newId: () => 'id-${DateTime.now().microsecondsSinceEpoch}',
      );
    });

    JobPosting listing(String id) => JobPosting(
      source: 'jobicy',
      externalId: id,
      company: 'Acme',
      title: 'Welder',
      originalUrl: 'https://example.com/$id',
      sourceName: 'Jobicy',
    );

    test('"interested" keeps an eye on a listing: no application date, nothing claimed, never twice', () async {
      await c.load();
      expect(await c.trackInterest(listing('1')), isTrue);
      final a = c.state.items.single;
      expect(a.stage, ApplicationStage.interested);
      expect(a.appliedAt, isNull);
      expect(a.job.originalUrl, 'https://example.com/1');
      expect(c.isTracked(listing('1')), isTrue);
      expect(await c.trackInterest(listing('1')), isFalse);
      expect(c.state.actionFailure, DataFailureKind.duplicate);
      expect(c.state.items.length, 1);
    });

    test('moving to a stage that exists after applying records today once; moving back or around never overwrites it', () async {
      await c.load();
      await c.trackInterest(listing('1'));
      final id = c.state.items.single.id;
      await c.updateStage(id, ApplicationStage.applied);
      final first = c.state.items.single.appliedAt;
      expect(first, isNotNull);
      expect(repo.rows.single.appliedAt, first);
      await c.updateStage(id, ApplicationStage.interview);
      await c.updateStage(id, ApplicationStage.interested);
      await c.updateStage(id, ApplicationStage.offer);
      expect(c.state.items.single.appliedAt, first);
    });

    test('an application the person dated themselves keeps its date', () async {
      await c.load();
      await c.create(
        company: 'A',
        title: 'B',
        stage: ApplicationStage.interested,
      );
      final id = c.state.items.single.id;
      await repo.updateDates(id, appliedAt: DateTime(2026, 1, 5));
      await c.load();
      await c.updateStage(id, ApplicationStage.applied);
      expect(c.state.items.single.appliedAt, DateTime(2026, 1, 5));
    });

    test('interview and follow-up dates are stored, shown at once and cleared; a failure changes nothing', () async {
      await c.load();
      await c.create(company: 'A', title: 'B');
      final id = c.state.items.single.id;
      final at = DateTime(2026, 11, 2, 14, 30);
      await c.setInterview(id, at);
      await c.setFollowUp(id, DateTime(2026, 11, 5));
      expect(c.state.items.single.interviewAt, at);
      expect(repo.rows.single.followUpAt, DateTime(2026, 11, 5));
      await c.setInterview(id, null);
      expect(c.state.items.single.interviewAt, isNull);
      expect(c.state.items.single.followUpAt, DateTime(2026, 11, 5));
      repo.error = sb.AuthRetryableFetchException(message: 'offline');
      await c.setFollowUp(id, null);
      expect(c.state.items.single.followUpAt, DateTime(2026, 11, 5));
      expect(c.state.actionFailure, DataFailureKind.network);
    });

    test('notes are kept as before and can be cleared', () async {
      await c.load();
      await c.create(company: 'A', title: 'B', note: 'call on Monday');
      final id = c.state.items.single.id;
      expect(c.state.items.single.note, 'call on Monday');
      await c.updateNote(id, '   ');
      expect(c.state.items.single.note, isNull);
    });
  });

  group('the Supabase repository', () {
    test('rows keep working: an old stage name, no dates; the new columns are read as UTC instants', () {
      final old = applicationFromRow({
        'id': 'a',
        'stage': 'screening',
        'job_snapshot': {
          'source': 'manual',
          'externalId': 'x',
          'company': 'A',
          'title': 'B',
          'originalUrl': '',
        },
      })!;
      expect(old.stage, ApplicationStage.screening);
      expect(old.interviewAt, isNull);
      final fresh = applicationFromRow({
        'id': 'b',
        'stage': 'hired',
        'interview_at': '2026-11-02T14:30:00+00:00',
        'follow_up_at': '2026-11-05T00:00:00+00:00',
        'job_snapshot': {
          'source': 'manual',
          'externalId': 'y',
          'company': 'A',
          'title': 'B',
          'originalUrl': '',
        },
      })!;
      expect(fresh.stage, ApplicationStage.hired);
      expect(fresh.interviewAt, DateTime.utc(2026, 11, 2, 14, 30));
      expect(fresh.followUpAt!.isUtc, isTrue);
      expect(
        applicationFromRow({
          'id': 'c',
          'stage': 'unheard-of',
          'job_snapshot': {
            'source': 'manual',
            'externalId': 'z',
            'company': 'A',
            'title': 'B',
            'originalUrl': '',
          },
        })!.stage,
        ApplicationStage.applied,
      );
    });

    test(
      'updating dates sends only the columns asked for; clearing sends null',
      () async {
        final b = FakeBackend(respond: (m, u, body) => (204, null));
        final repo = SupabaseApplicationsRepository(b.client);
        await repo.updateDates(
          'a1',
          interviewAt: DateTime.utc(2026, 11, 2, 14),
        );
        expect((b.last.json as Map), {
          'interview_at': '2026-11-02T14:00:00.000Z',
        });
        expect(b.last.query['id'], 'eq.a1');
        await repo.updateDates('a1', clearFollowUp: true);
        expect((b.last.json as Map), {'follow_up_at': null});
        final n = b.requests.length;
        await repo.updateDates('a1');
        expect(b.requests.length, n, reason: 'nothing to change, nothing sent');
        await repo.updateDates('a1', appliedAt: DateTime.utc(2026, 11, 1));
        expect((b.last.json as Map).keys, ['applied_at']);
      },
    );
  });

  group('on screen', () {
    Future<Fakes> openApplications(
      WidgetTester t,
      List<ApplicationRecord> rows,
    ) async {
      final auth = FakeAuth()..currentUser = _user;
      final fakes = Fakes(auth: auth);
      fakes.applications.rows.addAll(rows);
      await pumpApp(
        t,
        repo: PreviewSearchRepository(),
        auth: auth,
        fakes: fakes,
        size: const Size(820, 1400),
      );
      await t.tap(find.text('Applications'));
      await t.pumpAndSettle();
      return fakes;
    }

    testWidgets(
      'the pipeline filters by stage, shows what is coming up and flags what slipped',
      (t) async {
        final soon = DateTime.now().add(const Duration(days: 2));
        final late = DateTime.now().subtract(const Duration(days: 3));
        await openApplications(t, [
          _app(
            '1',
            stage: ApplicationStage.interview,
            title: 'Welder',
            interview: DateTime(soon.year, soon.month, soon.day, 14, 30),
          ),
          _app(
            '2',
            stage: ApplicationStage.applied,
            title: 'Cook',
            followUp: DateTime(late.year, late.month, late.day),
          ),
          _app('3', stage: ApplicationStage.interested, title: 'Pilot'),
          _app('4', stage: ApplicationStage.rejected, title: 'Clerk'),
        ]);
        expect(find.text('Coming up'), findsOneWidget);
        expect(find.text('Overdue'), findsOneWidget);
        expect(find.textContaining('Interview · Welder'), findsOneWidget);
        expect(find.textContaining('Follow up · Cook'), findsOneWidget);
        expect(find.text('All (4)'), findsOneWidget);
        await t.tap(find.text('Interested (1)'));
        await t.pumpAndSettle();
        expect(find.text('Pilot'), findsOneWidget);
        expect(find.text('Clerk'), findsNothing);
        // the chip row scrolls sideways: bring the last chip well into view
        await t.drag(
          find
              .descendant(
                of: find.byType(OrbiChipRow),
                matching: find.byType(Scrollable),
              )
              .first,
          const Offset(-400, 0),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Rejected (1)'));
        await t.pumpAndSettle();
        expect(find.text('Clerk'), findsOneWidget);
        expect(find.text('Pilot'), findsNothing);
        await t.drag(
          find
              .descendant(
                of: find.byType(OrbiChipRow),
                matching: find.byType(Scrollable),
              )
              .first,
          const Offset(600, 0),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('All (4)'));
        await t.pumpAndSettle();
        expect(find.text('Pilot'), findsOneWidget);
      },
    );

    testWidgets(
      'the detail page sets and clears the follow-up date and says the stage is the person\'s call',
      (t) async {
        final fakes = await openApplications(t, [_app('1', title: 'Welder')]);
        await t.tap(find.text('Welder'));
        await t.pumpAndSettle();
        expect(find.textContaining('You decide the stage'), findsOneWidget);
        expect(find.text('Not set'), findsNWidgets(2));
        await t.tap(find.text('Choose').last);
        await t.pumpAndSettle();
        await t.tap(find.text('OK'));
        await t.pumpAndSettle();
        expect(fakes.applications.rows.single.followUpAt, isNotNull);
        expect(find.text('Clear'), findsOneWidget);
        await t.tap(find.text('Clear'));
        await t.pumpAndSettle();
        expect(fakes.applications.rows.single.followUpAt, isNull);
      },
    );

    testWidgets(
      '"Track this job" from the card menu adds it as interested, once, without applying',
      (t) async {
        final auth = FakeAuth()..currentUser = _user;
        final fakes = Fakes(auth: auth);
        await pumpApp(
          t,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: fakes,
          size: const Size(390, 1000),
        );
        await t.tap(find.text('Explore'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField), 'Pedreiro');
        await t.testTextInput.receiveAction(TextInputAction.search);
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('More actions for Pedreiro'));
        await t.pumpAndSettle();
        await t.tap(find.text('Track this job'));
        await t.pumpAndSettle();
        expect(
          fakes.applications.rows.single.stage,
          ApplicationStage.interested,
        );
        expect(fakes.applications.rows.single.appliedAt, isNull);
        expect(find.textContaining('Nothing was sent'), findsOneWidget);
        await t.tap(find.byTooltip('More actions for Pedreiro'));
        await t.pumpAndSettle();
        await t.tap(find.text('Track this job'));
        await t.pumpAndSettle();
        expect(fakes.applications.rows.length, 1);
        expect(
          find.textContaining('already in your applications'),
          findsOneWidget,
        );
      },
    );
  });
}
