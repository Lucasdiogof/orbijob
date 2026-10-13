import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/user_scope.dart';
import '../../search/domain/entities/job_posting.dart';
import '../domain/hidden_jobs_repository.dart';

HiddenJob? hiddenFromRow(Map<String, dynamic> r) {
  String? s(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
  final key = s(r['job_key']);
  final source = s(r['source_id']);
  final ext = s(r['external_id']);
  final at = DateTime.tryParse('${r['hidden_at'] ?? ''}');
  if (key == null || source == null || ext == null || at == null) return null;
  return HiddenJob(
    key: key,
    source: source,
    externalId: ext,
    title: r['title'] is String ? r['title'] as String : '',
    company: s(r['company']),
    originalUrl: s(r['original_url']),
    hiddenAt: at.toUtc(),
  );
}

class SupabaseHiddenJobsRepository implements HiddenJobsRepository {
  SupabaseHiddenJobsRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<HiddenJob>> list() async {
    requireUserId(_client);
    final rows = await _client
        .from('hidden_jobs')
        .select(
          'job_key, source_id, external_id, title, company, original_url, hidden_at',
        )
        .order('hidden_at', ascending: false)
        .limit(2000);
    return [for (final r in rows) ?hiddenFromRow(r)];
  }

  @override
  Future<void> hide(JobPosting job) async {
    final uid = requireUserId(_client);
    final h = HiddenJob.of(job, DateTime.now());
    await _client
        .from('hidden_jobs')
        .upsert(
          {
            'user_id': uid,
            'job_key': h.key,
            'source_id': h.source,
            'external_id': h.externalId,
            'title': h.title,
            'company': ?h.company,
            'original_url': ?h.originalUrl,
          },
          onConflict: 'user_id,job_key',
          ignoreDuplicates: true,
        );
  }

  @override
  Future<void> restore(String key) async {
    requireUserId(_client);
    await _client.from('hidden_jobs').delete().eq('job_key', key);
  }
}
