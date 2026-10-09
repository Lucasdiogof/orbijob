import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/user_scope.dart';
import '../../search/data/job_snapshot.dart';
import '../../search/domain/entities/job_posting.dart';
import '../domain/application_record.dart';

ApplicationStage _stage(Object? v) => ApplicationStage.values.firstWhere(
  (s) => s.name == v,
  orElse: () => ApplicationStage.applied,
);

/// Row -> domain; null when the stored snapshot is unreadable.
ApplicationRecord? applicationFromRow(Map<String, dynamic> r) {
  final job = jobFromSnapshot(r['job_snapshot']);
  if (job == null) return null;
  return ApplicationRecord(
    id: r['id'] as String,
    job: job,
    stage: _stage(r['stage']),
    channel: r['channel'] as String?,
    appliedAt: DateTime.tryParse('${r['applied_at'] ?? ''}'),
    note: r['note'] as String?,
    profileId: r['profile_id'] as String?,
  );
}

class SupabaseApplicationsRepository implements ApplicationsRepository {
  SupabaseApplicationsRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<ApplicationRecord>> list() async {
    requireUserId(_client);
    final rows = await _client
        .from('applications')
        .select()
        .order('updated_at', ascending: false);
    return [for (final r in rows) ?applicationFromRow(r)];
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
    final uid = requireUserId(_client);
    final row = await _client
        .from('applications')
        .insert({
          'user_id': uid,
          'job_snapshot': jobToSnapshot(job),
          'stage': stage.name,
          'channel': ?channel,
          'applied_at': ?appliedAt?.toUtc().toIso8601String(),
          'note': ?note,
          'profile_id': ?profileId,
        })
        .select()
        .single();
    return applicationFromRow(row)!;
  }

  @override
  Future<void> changeStage(String id, ApplicationStage stage) async {
    requireUserId(_client);
    await _client
        .from('applications')
        .update({'stage': stage.name})
        .eq('id', id);
  }

  @override
  Future<void> updateNote(String id, String? note) async {
    requireUserId(_client);
    await _client.from('applications').update({'note': note}).eq('id', id);
  }

  @override
  Future<void> delete(String id) async {
    requireUserId(_client);
    await _client.from('applications').delete().eq('id', id);
  }

  @override
  Future<List<ApplicationEvent>> history(String id) async {
    requireUserId(_client);
    final rows = await _client
        .from('application_events')
        .select('stage, occurred_at, note')
        .eq('application_id', id)
        .order('occurred_at', ascending: true);
    return [
      for (final r in rows)
        ApplicationEvent(
          stage: _stage(r['stage']),
          occurredAt: DateTime.parse(r['occurred_at'] as String),
          note: r['note'] as String?,
        ),
    ];
  }
}
