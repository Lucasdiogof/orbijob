import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/user_scope.dart';
import '../domain/notifications_repository.dart';

AppNotification? notificationFromRow(Map<String, dynamic> r) {
  final id = r['id'];
  final title = r['title'];
  final created = DateTime.tryParse('${r['created_at'] ?? ''}');
  if (id is! String || title is! String || title.isEmpty || created == null) {
    return null;
  }
  String? s(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  return AppNotification(
    id: id,
    title: title,
    createdAt: created.toUtc(),
    jobId: s(r['job_id']),
    company: s(r['company']),
    originalUrl: s(r['original_url']),
    sourceId: s(r['source_id']),
    country: s(r['country'])?.toUpperCase(),
    searchIds: [
      if (r['search_ids'] is List)
        for (final e in r['search_ids'] as List)
          if (e is String) e,
    ],
    readAt: DateTime.tryParse('${r['read_at'] ?? ''}')?.toUtc(),
    kind: NotificationKind.parse(r['kind']),
    applicationId: s(r['application_id']),
  );
}

/// `public.notifications` through Row Level Security (the owner reads and marks; only the database inserts). The app never sends a column other
/// than `read_at` / `dismissed_at`.
class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository(this._client);
  final SupabaseClient _client;

  static const _columns =
      'id, kind, application_id, job_id, search_ids, title, company, original_url, source_id, country, created_at, read_at';

  @override
  Future<List<AppNotification>> list({int limit = 100}) async {
    requireUserId(_client);
    final rows = await _client
        .from('notifications')
        .select(_columns)
        .isFilter('dismissed_at', null)
        .order('created_at', ascending: false)
        .limit(limit.clamp(1, 300));
    return [for (final r in rows) ?notificationFromRow(r)];
  }

  @override
  Future<void> markRead(List<String> ids) async {
    requireUserId(_client);
    if (ids.isEmpty) return;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('id', ids)
        .isFilter('read_at', null);
  }

  @override
  Future<void> markAllRead() async {
    requireUserId(_client);
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .isFilter('read_at', null)
        .isFilter('dismissed_at', null);
  }

  @override
  Future<void> dismiss(String id) async {
    requireUserId(_client);
    await _client
        .from('notifications')
        .update({'dismissed_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  @override
  Future<void> dismissAll() async {
    requireUserId(_client);
    await _client
        .from('notifications')
        .update({'dismissed_at': DateTime.now().toUtc().toIso8601String()})
        .isFilter('dismissed_at', null);
  }
}

/// `user_preferences.settings`: read, merge one key, write back. A new account has no row yet; the upsert creates it with the defaults of the table.
class SupabaseAccountSettingsRepository implements AccountSettingsRepository {
  SupabaseAccountSettingsRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> load() async {
    requireUserId(_client);
    final row = await _client
        .from('user_preferences')
        .select('settings')
        .maybeSingle();
    final s = row?['settings'];
    return s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{};
  }

  @override
  Future<void> setKey(String key, Object? value) async {
    final uid = requireUserId(_client);
    final current = await load();
    current[key] = value;
    await _client.from('user_preferences').upsert({
      'user_id': uid,
      'settings': current,
    }, onConflict: 'user_id');
  }
}
