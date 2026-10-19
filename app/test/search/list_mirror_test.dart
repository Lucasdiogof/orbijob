import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/core/data/list_mirror.dart';
import 'package:orbijob/features/applications/applications_cubit.dart';
import 'package:orbijob/features/applications/data/offline_read_applications_repository.dart';
import 'package:orbijob/features/applications/domain/application_record.dart';
import 'package:orbijob/features/favorites/data/offline_read_favorites_repository.dart';
import 'package:orbijob/features/favorites/domain/favorites_repository.dart';
import 'package:orbijob/features/favorites/favorites_cubit.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ORBI-001: the signed-in user's own lists (favourites, applications) open without a connection, per user, read-only, and are removed at sign-out.

JobPosting job(String id) => JobPosting(
  source: 'jobicy',
  externalId: id,
  company: 'Acme',
  title: 'Flutter Developer $id',
  originalUrl: 'https://example.com/$id',
  description: 'Texto original.',
  sourceName: 'Jobicy',
);

class FakeFavorites implements FavoritesRepository {
  List<JobPosting> jobs = [];
  Object? error;
  final added = <String>[];
  @override
  Future<List<JobPosting>> list() async {
    if (error != null) throw error!;
    return jobs;
  }

  @override
  Future<void> add(JobPosting j) async {
    if (error != null) throw error!;
    added.add(j.externalId);
  }

  @override
  Future<void> remove(JobPosting j) async {
    if (error != null) throw error!;
  }
}

class FakeApplications implements ApplicationsRepository {
  List<ApplicationRecord> items = [];
  Object? error;
  @override
  Future<List<ApplicationRecord>> list() async {
    if (error != null) throw error!;
    return items;
  }

  @override
  Future<ApplicationRecord> create(
    JobPosting job, {
    ApplicationStage stage = ApplicationStage.applied,
    String? channel,
    DateTime? appliedAt,
    String? note,
    String? profileId,
  }) async {
    if (error != null) throw error!;
    return ApplicationRecord(id: 'new', job: job, stage: stage);
  }

  @override
  Future<void> changeStage(String id, ApplicationStage stage) async {
    if (error != null) throw error!;
  }

  @override
  Future<void> updateNote(String id, String? note) async {}
  @override
  Future<void> updateDates(
    String id, {
    DateTime? appliedAt,
    DateTime? interviewAt,
    bool clearInterview = false,
    DateTime? followUpAt,
    bool clearFollowUp = false,
  }) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<List<ApplicationEvent>> history(String id) async => [];
}

void main() {
  final t0 = DateTime.utc(2026, 10, 19, 12);
  late ListMirror mirror;
  String? user = 'u1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mirror = ListMirror(await SharedPreferences.getInstance(), now: () => t0);
    user = 'u1';
  });

  group('favourites', () {
    test('online: fresh list and a copy kept; no connection: the copy, dated; the list says it came from the device', () async {
      final net = FakeFavorites()..jobs = [job('1'), job('2')];
      final repo = OfflineReadFavoritesRepository(net, mirror, () => user);
      expect(await repo.list(), hasLength(2));
      expect(repo.listedFromMirrorAt, isNull);

      net.error = http.ClientException('offline');
      final saved = await repo.list();
      expect(saved.map((j) => j.externalId), ['1', '2']);
      expect(saved.first.description, 'Texto original.');
      expect(repo.listedFromMirrorAt, t0);

      net.error = null;
      await repo.list();
      expect(
        repo.listedFromMirrorAt,
        isNull,
        reason: 'the next online read says it is fresh again',
      );
    });

    test(
      'another account on the same device never reads it; sign-out removes it',
      () async {
        final net = FakeFavorites()..jobs = [job('1')];
        final repo = OfflineReadFavoritesRepository(net, mirror, () => user);
        await repo.list();
        net.error = http.ClientException('offline');

        user = 'u2';
        await expectLater(repo.list(), throwsA(isA<http.ClientException>()));
        user = null;
        await expectLater(repo.list(), throwsA(isA<http.ClientException>()));
        user = 'u1';
        expect(await repo.list(), hasLength(1));
        await mirror.clearAll();
        await expectLater(repo.list(), throwsA(isA<http.ClientException>()));
      },
    );

    test('changes are never answered locally, and an answer the server gave on purpose is not hidden behind the copy', () async {
      final net = FakeFavorites()..jobs = [job('1')];
      final repo = OfflineReadFavoritesRepository(net, mirror, () => user);
      await repo.list();
      net.error = http.ClientException('offline');
      await expectLater(
        repo.add(job('9')),
        throwsA(isA<http.ClientException>()),
      );
      net.error = const DataFailure(DataFailureKind.denied);
      await expectLater(repo.list(), throwsA(isA<DataFailure>()));
    });

    test('the cubit shows the date of the device copy and clears it when the list is fresh', () async {
      final net = FakeFavorites()..jobs = [job('1')];
      final cubit = FavoritesCubit(
        OfflineReadFavoritesRepository(net, mirror, () => user),
      );
      await cubit.load();
      expect(cubit.state.cachedAt, isNull);
      net.error = http.ClientException('offline');
      await cubit.load();
      expect(cubit.state.cachedAt, t0);
      expect(cubit.state.items, hasLength(1));
      net.error = null;
      await cubit.load();
      expect(cubit.state.cachedAt, isNull);
      await cubit.close();
    });
  });

  group('applications', () {
    test('round-trips every field offline; stage changes still need the connection', () async {
      final net = FakeApplications()
        ..items = [
          ApplicationRecord(
            id: 'a1',
            job: job('1'),
            stage: ApplicationStage.interview,
            channel: 'site',
            appliedAt: DateTime.utc(2026, 10, 1),
            note: 'Falar com RH',
            profileId: 'p1',
            interviewAt: DateTime.utc(2026, 10, 25, 14),
            followUpAt: DateTime.utc(2026, 10, 28),
          ),
        ];
      final repo = OfflineReadApplicationsRepository(net, mirror, () => user);
      await repo.list();
      net.error = http.ClientException('offline');
      final back = (await repo.list()).single;
      expect(back.id, 'a1');
      expect(back.stage, ApplicationStage.interview);
      expect(back.channel, 'site');
      expect(back.note, 'Falar com RH');
      expect(back.interviewAt, DateTime.utc(2026, 10, 25, 14));
      expect(back.followUpAt, DateTime.utc(2026, 10, 28));
      expect(back.job.title, 'Flutter Developer 1');
      expect(repo.listedFromMirrorAt, t0);
      await expectLater(
        repo.changeStage('a1', ApplicationStage.offer),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('the cubit keeps the date of the device copy', () async {
      final net = FakeApplications()
        ..items = [
          ApplicationRecord(
            id: 'a1',
            job: job('1'),
            stage: ApplicationStage.applied,
          ),
        ];
      final cubit = ApplicationsCubit(
        OfflineReadApplicationsRepository(net, mirror, () => user),
      );
      await cubit.load();
      expect(cubit.state.cachedAt, isNull);
      net.error = http.ClientException('offline');
      await cubit.load();
      expect(cubit.state.cachedAt, t0);
      expect(cubit.state.items, hasLength(1));
      await cubit.close();
    });
  });

  test('a damaged copy is ignored, never shown half-read', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${ListMirror.prefix}favorites.u1', '{broken');
    expect(mirror.read('favorites', 'u1'), isNull);
    await prefs.setString(
      '${ListMirror.prefix}favorites.u1',
      '{"at":"nope","items":[]}',
    );
    expect(mirror.read('favorites', 'u1'), isNull);
  });
}
