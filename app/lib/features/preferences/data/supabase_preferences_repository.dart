import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/user_scope.dart';
import '../domain/user_preferences.dart';

class SupabasePreferencesRepository implements PreferencesRepository {
  SupabasePreferencesRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<UserPreferences> load() async {
    requireUserId(_client);
    final row = await _client.from('user_preferences').select().maybeSingle();
    if (row == null) return const UserPreferences();
    return UserPreferences(
      theme: row['theme'] as String? ?? 'system',
      locale: row['locale'] as String?,
      countriesOfInterest: [
        for (final c in (row['countries_of_interest'] as List? ?? const []))
          c.toString().trim().toUpperCase(),
      ],
    );
  }

  @override
  Future<void> save(UserPreferences p) async {
    final uid = requireUserId(_client);
    await _client.from('user_preferences').upsert({
      'user_id': uid,
      'theme': p.theme,
      'locale': p.locale,
      'countries_of_interest': p.countriesOfInterest,
    }, onConflict: 'user_id');
  }
}

class SupabaseSavedSearchesRepository implements SavedSearchesRepository {
  SupabaseSavedSearchesRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<SavedSearch>> list() async {
    requireUserId(_client);
    final rows = await _client
        .from('saved_searches')
        .select('id, query')
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        SavedSearch(
          id: r['id'] as String,
          query: Map<String, dynamic>.from(r['query'] as Map),
        ),
    ];
  }

  @override
  Future<SavedSearch> add(Map<String, dynamic> query) async {
    final uid = requireUserId(_client);
    final r = await _client
        .from('saved_searches')
        .insert({'user_id': uid, 'query': query})
        .select('id, query')
        .single();
    return SavedSearch(
      id: r['id'] as String,
      query: Map<String, dynamic>.from(r['query'] as Map),
    );
  }

  @override
  Future<void> remove(String id) async {
    requireUserId(_client);
    await _client.from('saved_searches').delete().eq('id', id);
  }
}
