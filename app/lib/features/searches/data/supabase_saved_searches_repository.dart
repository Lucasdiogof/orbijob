import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/user_scope.dart';
import '../domain/saved_search.dart';

const _columns = 'id, name, query, alerts_enabled, frequency, created_at';

SavedSearch savedSearchFromRow(Map<String, dynamic> r) => SavedSearch(
  id: r['id'] as String,
  query: Map<String, dynamic>.from(r['query'] as Map),
  name: (r['name'] as String?)?.trim().isEmpty ?? true
      ? null
      : (r['name'] as String).trim(),
  alertsEnabled: r['alerts_enabled'] == true,
  frequency: AlertFrequency.parse(r['frequency']),
  createdAt: DateTime.tryParse('${r['created_at'] ?? ''}'),
);

/// Saved searches in `public.saved_searches` (row level security: the owner only). The alert cursor and run time are written by the database
/// alone; this repository never sends them.
class SupabaseSavedSearchesRepository implements SavedSearchesRepository {
  SupabaseSavedSearchesRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<SavedSearch>> list() async {
    requireUserId(_client);
    final rows = await _client
        .from('saved_searches')
        .select(_columns)
        .order('created_at', ascending: false);
    return [for (final r in rows) savedSearchFromRow(r)];
  }

  @override
  Future<SavedSearch> add(
    Map<String, dynamic> query, {
    String? name,
    bool alertsEnabled = false,
    AlertFrequency frequency = AlertFrequency.daily,
  }) async {
    final uid = requireUserId(_client);
    final r = await _client
        .from('saved_searches')
        .insert({
          'user_id': uid,
          'query': query,
          'name': ?name,
          'alerts_enabled': alertsEnabled,
          'frequency': frequency.name,
        })
        .select(_columns)
        .single();
    return savedSearchFromRow(r);
  }

  @override
  Future<SavedSearch> update(
    String id, {
    String? name,
    Map<String, dynamic>? query,
    bool? alertsEnabled,
    AlertFrequency? frequency,
  }) async {
    requireUserId(_client);
    final r = await _client
        .from('saved_searches')
        .update({
          'name': ?name,
          'query': ?query,
          'alerts_enabled': ?alertsEnabled,
          'frequency': ?frequency?.name,
        })
        .eq('id', id)
        .select(_columns)
        .single();
    return savedSearchFromRow(r);
  }

  @override
  Future<void> remove(String id) async {
    requireUserId(_client);
    await _client.from('saved_searches').delete().eq('id', id);
  }
}
