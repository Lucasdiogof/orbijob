import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/user_scope.dart';
import '../../search/data/job_snapshot.dart';
import '../../search/domain/entities/job_posting.dart';
import '../domain/favorites_repository.dart';

class SupabaseFavoritesRepository implements FavoritesRepository {
  SupabaseFavoritesRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<JobPosting>> list() async {
    requireUserId(_client);
    final rows = await _client
        .from('saved_jobs')
        .select('snapshot')
        .order('created_at', ascending: false);
    return [for (final r in rows) ?jobFromSnapshot(r['snapshot'])];
  }

  @override
  Future<void> add(JobPosting job) async {
    final uid = requireUserId(_client);
    await _client.from('saved_jobs').upsert({
      'user_id': uid,
      'job_key': jobKey(job),
      'snapshot': jobToSnapshot(job),
    }, onConflict: 'user_id,job_key');
  }

  @override
  Future<void> remove(JobPosting job) async {
    final uid = requireUserId(_client);
    await _client
        .from('saved_jobs')
        .delete()
        .eq('user_id', uid)
        .eq('job_key', jobKey(job));
  }
}
