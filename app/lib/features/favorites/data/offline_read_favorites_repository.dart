import '../../../core/data/list_mirror.dart';
import '../../search/data/job_cache_codec.dart';
import '../../search/data/offline_first_search_repository.dart'
    show isConnectivityProblem;
import '../../search/domain/entities/job_posting.dart';
import '../domain/favorites_repository.dart';

/// Reads the favourites from the server and keeps the last answer on the device, so the list opens without a connection (ORBI-001). Saving and
/// removing are never answered locally: they go to the server or fail with the usual message.
class OfflineReadFavoritesRepository
    implements FavoritesRepository, ListedFromMirror {
  OfflineReadFavoritesRepository(this._inner, this._mirror, this._userId);

  final FavoritesRepository _inner;
  final ListMirror _mirror;

  /// The signed-in user's id, or null when nobody is signed in.
  final String? Function() _userId;
  static const listName = 'favorites';
  DateTime? _fromMirrorAt;

  @override
  DateTime? get listedFromMirrorAt => _fromMirrorAt;

  @override
  Future<List<JobPosting>> list() async {
    final uid = _userId();
    try {
      final jobs = await _inner.list();
      _fromMirrorAt = null;
      if (uid != null) {
        await _mirror.write(listName, uid, [
          for (final j in jobs) jobToCacheJson(j),
        ]);
      }
      return jobs;
    } catch (e) {
      if (uid == null || !isConnectivityProblem(e)) rethrow;
      final saved = _mirror.read(listName, uid);
      if (saved == null) rethrow;
      _fromMirrorAt = saved.at;
      return [for (final j in saved.items) ?jobFromCacheJson(j)];
    }
  }

  @override
  Future<void> add(JobPosting job) => _inner.add(job);

  @override
  Future<void> remove(JobPosting job) => _inner.remove(job);
}
