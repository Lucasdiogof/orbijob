import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/core/data/load_status.dart';
import 'package:orbijob/features/applications/applications_cubit.dart';
import 'package:orbijob/features/applications/domain/application_record.dart';
import 'package:orbijob/features/search/data/job_snapshot.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers/fakes.dart';

void main() {
  late FakeApplications repo;
  late ApplicationsCubit c;
  setUp(() {
    repo = FakeApplications();
    c = ApplicationsCubit(repo, newId: () => 'fixed');
  });

  test('without a backend: not configured, nothing created', () async {
    final n = ApplicationsCubit(null);
    await n.load();
    expect(n.state.failure, DataFailureKind.notConfigured);
    expect(await n.create(company: 'A', title: 'B'), isFalse);
    expect(n.state.items, isEmpty);
  });

  test('starts empty and ready: "no data" is not an error', () async {
    await c.load();
    expect(c.state.status, LoadStatus.ready);
    expect(c.state.items, isEmpty);
  });

  test(
    'creates a manual application as a snapshot with the manual source',
    () async {
      await c.load();
      final ok = await c.create(
        company: ' Acme ',
        title: ' Nurse ',
        link: 'https://acme.example/jobs/1',
        note: '  call back  ',
        channel: 'E-mail',
        appliedAt: DateTime(2026, 3, 1),
      );
      expect(ok, isTrue);
      final a = c.state.items.single;
      expect(a.job.source, manualSource);
      expect(a.job.externalId, 'fixed');
      expect(a.job.company, 'Acme');
      expect(a.job.title, 'Nurse');
      expect(a.note, 'call back');
      expect(a.stage, ApplicationStage.applied);
      expect(repo.rows, hasLength(1));
    },
  );

  test(
    'a link is optional; a non-web link is rejected without calling the server',
    () async {
      await c.load();
      expect(await c.create(company: 'A', title: 'B', link: ''), isTrue);
      expect(
        await c.create(company: 'A', title: 'B', link: 'javascript:alert(1)'),
        isFalse,
      );
      expect(
        await c.create(company: 'A', title: 'B', link: 'ftp://x.example/a'),
        isFalse,
      );
      expect(c.state.actionFailure, DataFailureKind.invalidInput);
      expect(repo.rows, hasLength(1));
    },
  );

  test(
    'stage change is saved, then the history written by the trigger is re-read',
    () async {
      await c.load();
      await c.create(company: 'A', title: 'B');
      final id = c.state.items.single.id;
      await c.updateStage(id, ApplicationStage.interview);
      expect(c.state.items.single.stage, ApplicationStage.interview);
      expect(c.state.history[id]!.map((e) => e.stage), [
        ApplicationStage.applied,
        ApplicationStage.interview,
      ]);
    },
  );

  test(
    'a failed stage change leaves the stage untouched and reports why',
    () async {
      await c.load();
      await c.create(company: 'A', title: 'B');
      final id = c.state.items.single.id;
      repo.error = const sb.PostgrestException(
        message: 'denied',
        code: '42501',
      );
      await c.updateStage(id, ApplicationStage.offer);
      expect(c.state.items.single.stage, ApplicationStage.applied);
      expect(c.state.actionFailure, DataFailureKind.denied);
      expect(c.state.busy, isFalse);
    },
  );

  test('a history re-read failure after a saved change does not undo or hide the change', () async {
    await c.load();
    await c.create(company: 'A', title: 'B');
    final id = c.state.items.single.id;
    final flaky = _HistoryDown(repo);
    final c2 = ApplicationsCubit(flaky);
    await c2.load();
    await c2.updateStage(id, ApplicationStage.screening);
    expect(c2.state.items.single.stage, ApplicationStage.screening);
    expect(c2.state.actionFailure, isNull);
  });

  test('note: saved, blank clears it', () async {
    await c.load();
    await c.create(company: 'A', title: 'B', note: 'x');
    final id = c.state.items.single.id;
    await c.updateNote(id, 'new');
    expect(c.state.items.single.note, 'new');
    await c.updateNote(id, '   ');
    expect(c.state.items.single.note, isNull);
  });

  test('delete removes it and its cached history', () async {
    await c.load();
    await c.create(company: 'A', title: 'B');
    final id = c.state.items.single.id;
    await c.loadHistory(id);
    await c.delete(id);
    expect(c.state.items, isEmpty);
    expect(c.state.history, isEmpty);
  });

  test('quota (2000) is reported as such', () async {
    await c.load();
    repo.error = const sb.PostgrestException(
      message: 'applications quota exceeded',
      code: '53400',
    );
    expect(await c.create(company: 'A', title: 'B'), isFalse);
    expect(c.state.actionFailure, DataFailureKind.quotaExceeded);
    expect(c.state.items, isEmpty);
  });

  test('offline load shows the network failure, not an empty list', () async {
    repo.error = http404Network();
    await c.load();
    expect(c.state.status, LoadStatus.failure);
    expect(c.state.failure, DataFailureKind.network);
  });
}

Object http404Network() => sb.AuthRetryableFetchException(message: 'offline');

class _HistoryDown extends FakeApplications {
  _HistoryDown(FakeApplications from) {
    rows.addAll(from.rows);
  }
  @override
  Future<List<ApplicationEvent>> history(String id) async =>
      throw StateError('down');
}
