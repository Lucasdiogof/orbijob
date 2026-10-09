import '../features/favorites/domain/favorites_repository.dart';
import '../features/search/data/job_snapshot.dart';
import '../features/search/domain/entities/job_posting.dart';

/// Favourites kept in memory for previews and tests only. The production entrypoint never references it: a
/// real build stores favourites in Supabase or reports "not configured".
class InMemoryFavoritesRepository implements FavoritesRepository {
  final _items = <String, JobPosting>{};

  @override
  Future<List<JobPosting>> list() async =>
      _items.values.toList().reversed.toList();

  @override
  Future<void> add(JobPosting job) async => _items[jobKey(job)] = job;

  @override
  Future<void> remove(JobPosting job) async => _items.remove(jobKey(job));
}
