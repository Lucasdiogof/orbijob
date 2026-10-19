import '../../../core/data/list_mirror.dart';
import '../../search/data/job_cache_codec.dart';
import '../../search/data/offline_first_search_repository.dart'
    show isConnectivityProblem;
import '../../search/domain/entities/job_posting.dart';
import '../domain/application_record.dart';

Map<String, Object?> applicationToMirror(ApplicationRecord r) => {
  'id': r.id,
  'job': jobToCacheJson(r.job),
  'stage': r.stage.name,
  'channel': ?r.channel,
  'appliedAt': ?r.appliedAt?.toUtc().toIso8601String(),
  'note': ?r.note,
  'profileId': ?r.profileId,
  'interviewAt': ?r.interviewAt?.toUtc().toIso8601String(),
  'followUpAt': ?r.followUpAt?.toUtc().toIso8601String(),
};

ApplicationRecord? applicationFromMirror(Object? raw) {
  if (raw is! Map) return null;
  final job = jobFromCacheJson(raw['job']);
  final id = raw['id'];
  if (job == null || id is! String) return null;
  return ApplicationRecord(
    id: id,
    job: job,
    stage: ApplicationStage.values.firstWhere(
      (s) => s.name == raw['stage'],
      orElse: () => ApplicationStage.applied,
    ),
    channel: raw['channel'] as String?,
    appliedAt: DateTime.tryParse('${raw['appliedAt'] ?? ''}'),
    note: raw['note'] as String?,
    profileId: raw['profileId'] as String?,
    interviewAt: DateTime.tryParse('${raw['interviewAt'] ?? ''}')?.toUtc(),
    followUpAt: DateTime.tryParse('${raw['followUpAt'] ?? ''}')?.toUtc(),
  );
}

/// Reads the applications from the server and keeps the last answer on the device, so the list opens without a connection (ORBI-001). Every change
/// (create, stage, note, dates, delete) and the history still go to the server and fail with the usual message when there is no connection.
class OfflineReadApplicationsRepository
    implements ApplicationsRepository, ListedFromMirror {
  OfflineReadApplicationsRepository(this._inner, this._mirror, this._userId);

  final ApplicationsRepository _inner;
  final ListMirror _mirror;
  final String? Function() _userId;
  static const listName = 'applications';
  DateTime? _fromMirrorAt;

  @override
  DateTime? get listedFromMirrorAt => _fromMirrorAt;

  @override
  Future<List<ApplicationRecord>> list() async {
    final uid = _userId();
    try {
      final items = await _inner.list();
      _fromMirrorAt = null;
      if (uid != null) {
        await _mirror.write(listName, uid, [
          for (final r in items) applicationToMirror(r),
        ]);
      }
      return items;
    } catch (e) {
      if (uid == null || !isConnectivityProblem(e)) rethrow;
      final saved = _mirror.read(listName, uid);
      if (saved == null) rethrow;
      _fromMirrorAt = saved.at;
      return [for (final r in saved.items) ?applicationFromMirror(r)];
    }
  }

  @override
  Future<ApplicationRecord> create(
    JobPosting job, {
    ApplicationStage stage = ApplicationStage.applied,
    String? channel,
    DateTime? appliedAt,
    String? note,
    String? profileId,
  }) => _inner.create(
    job,
    stage: stage,
    channel: channel,
    appliedAt: appliedAt,
    note: note,
    profileId: profileId,
  );

  @override
  Future<void> changeStage(String id, ApplicationStage stage) =>
      _inner.changeStage(id, stage);

  @override
  Future<void> updateNote(String id, String? note) =>
      _inner.updateNote(id, note);

  @override
  Future<void> updateDates(
    String id, {
    DateTime? appliedAt,
    DateTime? interviewAt,
    bool clearInterview = false,
    DateTime? followUpAt,
    bool clearFollowUp = false,
  }) => _inner.updateDates(
    id,
    appliedAt: appliedAt,
    interviewAt: interviewAt,
    clearInterview: clearInterview,
    followUpAt: followUpAt,
    clearFollowUp: clearFollowUp,
  );

  @override
  Future<void> delete(String id) => _inner.delete(id);

  @override
  Future<List<ApplicationEvent>> history(String id) => _inner.history(id);
}
