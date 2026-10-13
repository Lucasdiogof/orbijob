import 'package:equatable/equatable.dart';

/// A job the database announced because it matches one of the person's saved searches with alerts on. It keeps just enough of the job to be
/// read on its own (title, company, link): the job itself may leave the catalogue later.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.createdAt,
    this.jobId,
    this.company,
    this.originalUrl,
    this.sourceId,
    this.country,
    this.searchIds = const [],
    this.readAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final String? jobId;
  final String? company;
  final String? originalUrl;
  final String? sourceId;
  final String? country;

  /// The saved searches that matched this job.
  final List<String> searchIds;
  final DateTime? readAt;

  bool get unread => readAt == null;

  AppNotification markedRead(DateTime at) => AppNotification(
    id: id,
    title: title,
    createdAt: createdAt,
    jobId: jobId,
    company: company,
    originalUrl: originalUrl,
    sourceId: sourceId,
    country: country,
    searchIds: searchIds,
    readAt: readAt ?? at,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    createdAt,
    jobId,
    company,
    originalUrl,
    sourceId,
    country,
    searchIds,
    readAt,
  ];
}

/// The notification centre of the account. Notifications are created by the database alone; the app can read them, mark them read and
/// dismiss them (a dismissed one stays stored for a while so the same job is not announced again).
abstract class NotificationsRepository {
  /// Newest first, without the dismissed ones.
  Future<List<AppNotification>> list({int limit = 100});
  Future<void> markRead(List<String> ids);
  Future<void> markAllRead();
  Future<void> dismiss(String id);
  Future<void> dismissAll();
}

/// Small account-level switches kept in `user_preferences.settings` (a JSON object). Changing one key leaves the others alone.
abstract class AccountSettingsRepository {
  Future<Map<String, dynamic>> load();

  /// Sets `settings[key] = value` (merging into what is stored).
  Future<void> setKey(String key, Object? value);
}

/// Whether the person wants alerts at all (default: yes). Stored as `settings.notifications.enabled`.
bool alertsEnabledIn(Map<String, dynamic> settings) {
  final n = settings['notifications'];
  return n is Map ? n['enabled'] != false : true;
}
