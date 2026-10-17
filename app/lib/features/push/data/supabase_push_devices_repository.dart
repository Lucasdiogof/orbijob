import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/user_scope.dart';
import '../domain/push_messaging.dart';

/// `public.push_devices` under Row Level Security: the person inserts, refreshes and deletes only their own rows. At the 10-device quota the
/// least recently seen device makes room (a new phone must never fail to register).
class SupabasePushDevicesRepository implements PushDevicesRepository {
  SupabasePushDevicesRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<void> register({
    required String token,
    required String platform,
    String? locale,
  }) async {
    final uid = requireUserId(_client);
    final row = {
      'user_id': uid,
      'token': token,
      'platform': platform,
      'locale': locale,
    };
    try {
      await _upsert(row);
    } on PostgrestException catch (e) {
      if (!e.message.contains('quota')) rethrow;
      final oldest = await _client
          .from('push_devices')
          .select('id')
          .neq('token', token)
          .order('last_seen_at', ascending: true)
          .limit(1);
      if (oldest.isEmpty) rethrow;
      await _client.from('push_devices').delete().eq('id', oldest.first['id']);
      await _upsert(row);
    }
  }

  Future<void> _upsert(Map<String, Object?> row) async {
    final existing = await _client
        .from('push_devices')
        .select('id')
        .eq('token', row['token']!)
        .limit(1);
    if (existing.isEmpty) {
      await _client.from('push_devices').insert(row);
    } else {
      await _client
          .from('push_devices')
          .update({
            'platform': row['platform'],
            'locale': row['locale'],
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', existing.first['id']);
    }
  }

  @override
  Future<void> remove(String token) async {
    requireUserId(_client);
    await _client.from('push_devices').delete().eq('token', token);
  }
}
