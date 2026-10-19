import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/core/data/load_status.dart';
import 'package:orbijob/core/data/user_scope.dart';
import 'package:orbijob/features/favorites/favorites_cubit.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers/fakes.dart';

JobPosting job(String id) => JobPosting(
  source: 'x',
  externalId: id,
  company: 'Co $id',
  title: 'Job $id',
  originalUrl: 'https://example.com/$id',
);

void main() {
  test(
    'without a backend the feature says "not configured" and stores nothing',
    () async {
      final c = FavoritesCubit(null);
      await c.load();
      expect(c.state.status, LoadStatus.failure);
      expect(c.state.failure, DataFailureKind.notConfigured);
      await c.toggle(ScoredJob(job('1')));
      expect(c.state.items, isEmpty);
      expect(c.state.actionFailure, DataFailureKind.notConfigured);
    },
  );

  test('load lists what the repository returns', () async {
    final repo = FailingFavorites()..inner['x:1'] = job('1');
    final c = FavoritesCubit(repo);
    await c.load();
    expect(c.state.status, LoadStatus.ready);
    expect(c.state.items.length, 1);
  });

  test('load failure keeps the cause (offline, session ended)', () async {
    final repo = FailingFavorites()
      ..error = const sb.AuthApiException('x', statusCode: '401');
    final c = FavoritesCubit(repo);
    await c.load();
    expect(c.state.failure, DataFailureKind.sessionExpired);
  });

  test('toggle saves and removes, persisting through the repository', () async {
    final repo = FailingFavorites();
    final c = FavoritesCubit(repo);
    await c.load();
    await c.toggle(ScoredJob(job('1')));
    expect(c.isFavorite(job('1')), isTrue);
    expect(repo.inner.length, 1);
    await c.toggle(ScoredJob(job('1')));
    expect(c.isFavorite(job('1')), isFalse);
    expect(repo.inner, isEmpty);
  });

  test(
    'a refused save (quota) is rolled back and reported, never shown as saved',
    () async {
      final repo = FailingFavorites()
        ..error = const sb.PostgrestException(
          message: 'saved_jobs quota exceeded',
          code: '53400',
        );
      final c = FavoritesCubit(repo);
      await c.load.call().catchError((_) {});
      repo.error = const sb.PostgrestException(
        message: 'saved_jobs quota exceeded',
        code: '53400',
      );
      final states = <FavoritesState>[];
      final sub = c.stream.listen(states.add);
      await c.toggle(ScoredJob(job('1')));
      await sub.cancel();
      expect(
        states.first.items.containsKey(FavoritesCubit.keyOf(job('1'))),
        isTrue,
        reason: 'optimistic',
      );
      expect(c.state.items, isEmpty);
      expect(c.state.actionFailure, DataFailureKind.quotaExceeded);
      expect(c.state.pending, isEmpty);
    },
  );

  test('a refused removal puts the favourite back', () async {
    final repo = FailingFavorites()..inner['x:1'] = job('1');
    final c = FavoritesCubit(repo);
    await c.load();
    repo.error = http404();
    await c.toggle(ScoredJob(job('1')));
    expect(c.isFavorite(job('1')), isTrue);
    expect(c.state.actionFailure, isNotNull);
  });

  test('a second tap while the first is in flight is ignored (no duplicate request)', () async {
    final gate = Completer<void>();
    final repo = _Slow(gate);
    final c = FavoritesCubit(repo);
    await c.load();
    final first = c.toggle(ScoredJob(job('1')));
    final second = c.toggle(ScoredJob(job('1')));
    gate.complete();
    await Future.wait([first, second]);
    expect(repo.adds, 1);
    expect(c.isFavorite(job('1')), isTrue);
  });

  test('signed out: the tap asks for sign-in and sends nothing', () async {
    final repo = FailingFavorites()..error = NotSignedInException();
    final c = FavoritesCubit(repo);
    await c.load();
    expect(c.state.failure, DataFailureKind.signedOut);
    repo.error = null;
    await c.toggle(ScoredJob(job('1')));
    expect(c.state.items, isEmpty);
    expect(c.state.actionFailure, DataFailureKind.signedOut);
    expect(repo.inner, isEmpty);
  });
}

Object http404() =>
    const sb.PostgrestException(message: 'gone', code: 'PGRST116');

class _Slow extends FailingFavorites {
  _Slow(this.gate);
  final Completer<void> gate;
  int adds = 0;
  @override
  Future<void> add(JobPosting job) async {
    adds++;
    await gate.future;
    await super.add(job);
  }
}
