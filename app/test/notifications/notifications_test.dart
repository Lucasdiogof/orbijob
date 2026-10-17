import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/core/data/load_status.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/notifications/data/supabase_notifications_repository.dart';
import 'package:orbijob/features/notifications/domain/notifications_repository.dart';
import 'package:orbijob/features/notifications/presentation/notifications_cubit.dart';
import 'package:orbijob/features/searches/domain/saved_search.dart';
import 'package:orbijob/features/searches/domain/search_spec.dart';
import 'package:orbijob/preview/preview_fixtures.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers/fakes.dart';
import '../helpers/harness.dart';
import '../supabase/fake_backend.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.com');

AppNotification _n(
  String id,
  String title, {
  DateTime? at,
  bool read = false,
  List<String> searches = const [],
}) => AppNotification(
  id: id,
  title: title,
  company: 'Acme',
  country: 'DE',
  originalUrl: 'https://example.com/$id',
  jobId: 'job-$id',
  createdAt: at ?? DateTime.now().toUtc().subtract(const Duration(hours: 3)),
  searchIds: searches,
  readAt: read ? DateTime.now().toUtc() : null,
);

void main() {
  group('NotificationsCubit', () {
    late FakeNotifications repo;
    late FakeAccountSettings settings;
    late NotificationsCubit c;
    setUp(() {
      repo = FakeNotifications()
        ..rows.addAll([
          _n('1', 'Nurse'),
          _n('2', 'Welder', read: true),
          _n('3', 'Cook'),
        ]);
      settings = FakeAccountSettings();
      c = NotificationsCubit(repo, settings, refreshEvery: null);
    });
    tearDown(() => c.close());

    test(
      'loads the list, counts the unread ones and reads the alerts switch',
      () async {
        settings.data['notifications'] = {'enabled': false};
        await c.load();
        expect(c.state.status, LoadStatus.ready);
        expect(c.state.items.length, 3);
        expect(c.state.unread, 2);
        expect(c.state.alertsEnabled, isFalse);
      },
    );

    test(
      'alerts are on by default, and a failing settings read does not hide the list',
      () async {
        settings.error = StateError('x');
        await c.load();
        expect(c.state.status, LoadStatus.ready);
        expect(c.state.alertsEnabled, isTrue);
        expect(alertsEnabledIn({}), isTrue);
        expect(alertsEnabledIn({'notifications': 'weird'}), isTrue);
        expect(
          alertsEnabledIn({
            'notifications': {'enabled': false},
          }),
          isFalse,
        );
      },
    );

    test(
      'marking one read is immediate and stored; a failure puts it back',
      () async {
        await c.load();
        final first = c.state.items.first;
        await c.markRead(first);
        expect(c.state.unread, 1);
        expect(repo.rows.first.unread, isFalse);
        final other = c.state.items.last;
        repo.error = sb.AuthRetryableFetchException(message: 'offline');
        await c.markRead(other);
        expect(c.state.unread, 1);
        expect(c.state.actionFailure, DataFailureKind.network);
      },
    );

    test(
      'mark all read, dismiss one, clear all; each failure restores the list',
      () async {
        await c.load();
        await c.markAllRead();
        expect(c.state.unread, 0);
        await c.dismiss(c.state.items.first);
        expect(c.state.items.length, 2);
        expect(repo.dismissed, {'1'});
        repo.error = StateError('boom');
        await c.dismissAll();
        expect(c.state.items.length, 2);
        repo.error = null;
        await c.dismissAll();
        expect(c.state.items, isEmpty);
        expect(repo.dismissed, {'1', '2', '3'});
      },
    );

    test('the alerts switch is stored first or put back', () async {
      await c.load();
      expect(await c.setAlertsEnabled(false), isTrue);
      expect(settings.data['notifications'], {'enabled': false});
      expect(c.state.alertsEnabled, isFalse);
      settings.error = StateError('boom');
      expect(await c.setAlertsEnabled(true), isFalse);
      expect(c.state.alertsEnabled, isFalse);
      expect(c.state.actionFailure, isNotNull);
    });

    test(
      'refresh picks up new notifications quietly and keeps the list when it fails',
      () async {
        await c.load();
        repo.rows.insert(0, _n('4', 'Pilot'));
        await c.refresh();
        expect(c.state.items.first.title, 'Pilot');
        repo.error = StateError('boom');
        await c.refresh();
        expect(c.state.items.first.title, 'Pilot');
        expect(c.state.status, LoadStatus.ready);
      },
    );

    test('signed out and not configured are reported, not hidden', () async {
      final auth = FakeAuth();
      final out = NotificationsCubit(
        FakeNotifications(auth: auth),
        FakeAccountSettings(),
        refreshEvery: null,
      );
      await out.load();
      expect(out.state.status, LoadStatus.failure);
      expect(needsSignIn(out.state.failure!), isTrue);
      final none = NotificationsCubit(null, null, refreshEvery: null);
      await none.load();
      expect(none.state.failure, DataFailureKind.notConfigured);
      expect(await none.setAlertsEnabled(false), isFalse);
    });
  });

  group('the Supabase repository', () {
    test(
      'lists only what is not dismissed, newest first, and maps the columns',
      () async {
        final b = FakeBackend(
          respond: (m, u, body) => (
            200,
            [
              {
                'id': 'n1',
                'job_id': 'j1',
                'search_ids': ['s1', 's2'],
                'title': 'Nurse',
                'company': 'Acme',
                'original_url': 'https://example.com/1',
                'source_id': 'jobicy',
                'country': 'de',
                'created_at': '2026-10-13T10:00:00+00:00',
                'read_at': null,
              },
              {'id': 'bad', 'title': '', 'created_at': 'x'},
            ],
          ),
        );
        final list = await SupabaseNotificationsRepository(b.client).list();
        expect(list.length, 1);
        expect(list.single.country, 'DE');
        expect(list.single.searchIds, ['s1', 's2']);
        expect(list.single.unread, isTrue);
        expect(list.single.kind, NotificationKind.newJob);
        final q = b.last.query;
        expect(q['dismissed_at'], 'is.null');
        expect(q['order'], startsWith('created_at.desc'));
      },
    );

    test('reminder rows keep their kind and application', () async {
      final b = FakeBackend(
        respond: (m, u, body) => (
          200,
          [
            {
              'id': 'r1',
              'kind': 'interview',
              'application_id': 'a1',
              'job_id': null,
              'title': 'Physio',
              'created_at': '2026-10-13T10:00:00+00:00',
            },
            {
              'id': 'r2',
              'kind': 'follow_up',
              'title': 'Nurse',
              'created_at': '2026-10-13T10:00:00+00:00',
            },
          ],
        ),
      );
      final list = await SupabaseNotificationsRepository(b.client).list();
      expect(list.map((n) => n.kind), [
        NotificationKind.interview,
        NotificationKind.followUp,
      ]);
      expect(list.first.applicationId, 'a1');
      expect(list.first.jobId, isNull);
      expect(b.last.query['select'], contains('kind'));
    });

    test('marking and dismissing send only read_at / dismissed_at', () async {
      final b = FakeBackend(respond: (m, u, body) => (204, null));
      final repo = SupabaseNotificationsRepository(b.client);
      await repo.markRead(['a', 'b']);
      expect((b.last.json as Map).keys, ['read_at']);
      await repo.markAllRead();
      expect((b.last.json as Map).keys, ['read_at']);
      await repo.dismiss('a');
      expect((b.last.json as Map).keys, ['dismissed_at']);
      expect(b.last.query['id'], 'eq.a');
      await repo.dismissAll();
      expect((b.last.json as Map).keys, ['dismissed_at']);
    });

    test('the settings are merged, never replaced', () async {
      final b = FakeBackend(
        respond: (m, u, body) => m == 'GET'
            ? (
                200,
                {
                  'settings': {'other': 1},
                },
              )
            : (204, null),
      );
      await SupabaseAccountSettingsRepository(
        b.client,
      ).setKey('notifications', {'enabled': false});
      final sent = b.last.json as Map;
      expect(sent['user_id'], testUserA);
      expect(sent['settings'], {
        'other': 1,
        'notifications': {'enabled': false},
      });
    });

    test('signed out: refused before any request', () async {
      final b = FakeBackend(signedIn: false);
      await expectLater(
        SupabaseNotificationsRepository(b.client).list(),
        throwsA(isA<Exception>()),
      );
      expect(b.requests, isEmpty);
    });
  });

  group('the notification centre on screen', () {
    testWidgets(
      'the bell shows the unread count and the page lists, reads, dismisses',
      (t) async {
        final auth = FakeAuth()..currentUser = _user;
        final fakes = Fakes(auth: auth);
        fakes.savedSearches.rows.add(
          SavedSearch(
            id: 's1',
            name: 'Nurses in Germany',
            alertsEnabled: true,
            query: const SearchSpec(term: 'nurse').toQuery(),
          ),
        );
        fakes.notifications.rows.addAll([
          _n('1', 'Registered Nurse', searches: ['s1']),
          _n('2', 'Welder', read: true),
        ]);
        await pumpApp(
          t,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: fakes,
          size: const Size(390, 900),
        );
        expect(find.byTooltip('Notifications, 1 unread'), findsOneWidget);
        await t.tap(find.byTooltip('Notifications, 1 unread'));
        await t.pumpAndSettle();
        expect(find.text('Registered Nurse'), findsOneWidget);
        expect(find.text('Acme · Germany'), findsNWidgets(2));
        expect(find.text('Matches: Nurses in Germany'), findsOneWidget);
        expect(find.text('3 hours ago'), findsNWidgets(2));
        expect(find.text('New job'), findsNWidgets(2));
        // dismiss one
        await t.tap(find.byTooltip('Remove from list').last);
        await t.pumpAndSettle();
        expect(find.text('Welder'), findsNothing);
        expect(fakes.notifications.dismissed, {'2'});
        // mark all read removes the badge
        await t.tap(find.byTooltip('Mark all as read'));
        await t.pumpAndSettle();
        expect(find.byTooltip('Mark all as read'), findsNothing);
        expect(fakes.notifications.rows.every((n) => !n.unread), isTrue);
      },
    );

    testWidgets(
      'a reminder shows what it is about and opens the applications',
      (t) async {
        final auth = FakeAuth()..currentUser = _user;
        final fakes = Fakes(auth: auth);
        fakes.notifications.rows.addAll([
          AppNotification(
            id: 'r1',
            title: 'Pelvic physiotherapist',
            company: 'Clinic',
            kind: NotificationKind.interview,
            applicationId: 'app-1',
            createdAt: DateTime.now().toUtc().subtract(
              const Duration(hours: 1),
            ),
          ),
          AppNotification(
            id: 'r2',
            title: 'Nurse',
            kind: NotificationKind.followUp,
            applicationId: 'app-2',
            createdAt: DateTime.now().toUtc().subtract(
              const Duration(hours: 2),
            ),
          ),
        ]);
        await pumpApp(
          t,
          repo: PreviewSearchRepository(),
          auth: auth,
          fakes: fakes,
          size: const Size(390, 900),
        );
        await t.tap(find.byTooltip('Notifications, 2 unread'));
        await t.pumpAndSettle();
        expect(find.text('Interview in the next 24 hours'), findsOneWidget);
        expect(find.text('Follow-up day for this application'), findsOneWidget);
        expect(find.text('Interview'), findsOneWidget);
        expect(find.text('Follow-up'), findsOneWidget);
        expect(find.textContaining('Found'), findsNothing);
        await t.tap(find.text('Pelvic physiotherapist'));
        await t.pumpAndSettle();
        expect(find.text('Interview in the next 24 hours'), findsNothing);
        expect(
          fakes.notifications.rows.firstWhere((n) => n.id == 'r1').unread,
          isFalse,
        );
      },
    );

    testWidgets(
      'empty: says when new jobs are checked; the alerts switch is stored',
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
        await t.tap(find.byTooltip('Notifications'));
        await t.pumpAndSettle();
        expect(find.text('Nothing new yet'), findsOneWidget);
        expect(
          find.text('You have no saved search with alerts on.'),
          findsOneWidget,
        );
        await t.tap(find.text('Receive alerts'));
        await t.pumpAndSettle();
        expect(fakes.accountSettings.data['notifications'], {'enabled': false});
        expect(
          find.textContaining('also arrive as push notifications'),
          findsOneWidget,
        );
      },
    );

    testWidgets('signed out the page asks for an account', (t) async {
      final auth = FakeAuth();
      await pumpApp(
        t,
        repo: PreviewSearchRepository(),
        auth: auth,
        fakes: Fakes(auth: auth),
        size: const Size(390, 900),
      );
      await t.tap(find.byTooltip('Notifications'));
      await t.pumpAndSettle();
      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining('Sign in'), findsWidgets);
    });
  });
}
