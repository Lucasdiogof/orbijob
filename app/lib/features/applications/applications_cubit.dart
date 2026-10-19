import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/data/data_failure.dart';
import '../../core/data/list_mirror.dart';
import '../../core/data/load_status.dart';
import '../search/data/job_snapshot.dart';
import '../search/domain/entities/job_posting.dart';
import 'domain/application_record.dart';

class ApplicationsState extends Equatable {
  const ApplicationsState({
    this.status = LoadStatus.loading,
    this.failure,
    this.items = const [],
    this.history = const {},
    this.busy = false,
    this.actionFailure,
    this.actionTick = 0,
    this.cachedAt,
  });

  /// Set when the list is the copy kept on the device (no connection): when it was saved.
  final DateTime? cachedAt;

  final LoadStatus status;
  final DataFailureKind? failure;
  final List<ApplicationRecord> items;

  /// Stage history by application id (loaded on demand, written by a database trigger).
  final Map<String, List<ApplicationEvent>> history;
  final bool busy;
  final DataFailureKind? actionFailure;
  final int actionTick;

  ApplicationsState copyWith({
    LoadStatus? status,
    DataFailureKind? failure,
    bool clearFailure = false,
    List<ApplicationRecord>? items,
    Map<String, List<ApplicationEvent>>? history,
    bool? busy,
    DataFailureKind? actionFailure,
    DateTime? cachedAt,
    bool clearCachedAt = false,
  }) => ApplicationsState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    items: items ?? this.items,
    history: history ?? this.history,
    busy: busy ?? this.busy,
    actionFailure: actionFailure,
    actionTick: actionFailure == null ? actionTick : actionTick + 1,
    cachedAt: clearCachedAt ? null : (cachedAt ?? this.cachedAt),
  );

  @override
  List<Object?> get props => [
    status,
    failure,
    items,
    history,
    busy,
    actionFailure,
    actionTick,
    cachedAt,
  ];
}

/// The user's own application tracking. It records what the USER says they did: OrbiJob never sends an
/// application, so an entry here is not proof that anything was submitted. Every change waits for the server
/// (no optimistic state), because the stage history is written by a database trigger.
class ApplicationsCubit extends Cubit<ApplicationsState> {
  ApplicationsCubit(this._repo, {String Function()? newId})
    : _newId = newId ?? _randomId,
      super(const ApplicationsState());

  final ApplicationsRepository? _repo;
  final String Function() _newId;

  static String _randomId() {
    final r = Random.secure();
    return 'manual-${DateTime.now().microsecondsSinceEpoch}-'
        '${r.nextInt(1 << 32).toRadixString(16)}';
  }

  /// Only http(s) links are kept: anything else is rejected, never opened.
  static bool isWebLink(String v) {
    final u = Uri.tryParse(v.trim());
    return u != null &&
        u.hasAuthority &&
        (u.scheme == 'https' || u.scheme == 'http');
  }

  Future<void> load() async {
    final repo = _repo;
    if (repo == null) {
      return emit(
        state.copyWith(
          status: LoadStatus.failure,
          failure: DataFailureKind.notConfigured,
        ),
      );
    }
    emit(state.copyWith(status: LoadStatus.loading, clearFailure: true));
    try {
      final items = await repo.list();
      final saved = repo is ListedFromMirror
          ? (repo as ListedFromMirror).listedFromMirrorAt
          : null;
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          clearFailure: true,
          items: items,
          cachedAt: saved,
          clearCachedAt: saved == null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: LoadStatus.failure, failure: mapDataError(e)),
      );
    }
  }

  Future<T?> _write<T>(Future<T> Function(ApplicationsRepository r) run) async {
    final repo = _repo;
    if (repo == null) {
      emit(state.copyWith(actionFailure: DataFailureKind.notConfigured));
      return null;
    }
    if (state.busy) return null;
    emit(state.copyWith(busy: true));
    try {
      final v = await run(repo);
      emit(state.copyWith(busy: false));
      return v;
    } catch (e) {
      emit(state.copyWith(busy: false, actionFailure: mapDataError(e)));
      return null;
    }
  }

  /// Adds an application the user made outside OrbiJob. [link] is optional and must be http(s).
  Future<bool> create({
    required String company,
    required String title,
    String? link,
    ApplicationStage stage = ApplicationStage.applied,
    DateTime? appliedAt,
    String? note,
    String? channel,
    String? profileId,
  }) async {
    final url = (link ?? '').trim();
    if (url.isNotEmpty && !isWebLink(url)) {
      emit(state.copyWith(actionFailure: DataFailureKind.invalidInput));
      return false;
    }
    final record = await _write(
      (r) => r.create(
        JobPosting(
          source: manualSource,
          externalId: _newId(),
          company: company.trim(),
          title: title.trim(),
          originalUrl: url,
        ),
        stage: stage,
        appliedAt: appliedAt,
        note: _blank(note),
        channel: _blank(channel),
        profileId: profileId,
      ),
    );
    if (record == null) return false;
    emit(state.copyWith(items: [record, ...state.items]));
    return true;
  }

  /// Moves the application to [stage]; the history row is written by the server, then re-read.
  Future<void> updateStage(String id, ApplicationStage stage) async {
    final repo = _repo;
    if (repo == null) {
      return emit(state.copyWith(actionFailure: DataFailureKind.notConfigured));
    }
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      await repo.changeStage(id, stage);
      final current = state.items.where((a) => a.id == id).firstOrNull;
      DateTime? appliedNow;
      if (stage.impliesApplied &&
          current != null &&
          current.appliedAt == null) {
        // The person moved it to a stage that only exists after applying: today is the best honest date, and it can be corrected.
        appliedNow = DateTime.now();
        try {
          await repo.updateDates(id, appliedAt: appliedNow);
        } catch (_) {
          appliedNow = null;
        }
      }
      // The change is saved; a failure to re-read the history must not look like a failed change.
      List<ApplicationEvent>? events;
      try {
        events = await repo.history(id);
      } catch (_) {}
      emit(
        state.copyWith(
          busy: false,
          items: [
            for (final a in state.items)
              if (a.id == id)
                a.copyWith(stage: stage, appliedAt: appliedNow)
              else
                a,
          ],
          history: events == null ? null : {...state.history, id: events},
        ),
      );
    } catch (e) {
      emit(state.copyWith(busy: false, actionFailure: mapDataError(e)));
    }
  }

  Future<void> updateNote(String id, String? note) async {
    final repo = _repo;
    if (repo == null) {
      return emit(state.copyWith(actionFailure: DataFailureKind.notConfigured));
    }
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      await repo.updateNote(id, _blank(note));
      emit(
        state.copyWith(
          busy: false,
          items: [
            for (final a in state.items)
              if (a.id == id)
                a.copyWith(note: _blank(note), clearNote: _blank(note) == null)
              else
                a,
          ],
        ),
      );
    } catch (e) {
      emit(state.copyWith(busy: false, actionFailure: mapDataError(e)));
    }
  }

  /// Sets (or, with null, clears) the interview date and time.
  Future<void> setInterview(String id, DateTime? at) => _setDate(
    id,
    (r) => r.updateDates(id, interviewAt: at, clearInterview: at == null),
    (a) => a.copyWith(interviewAt: at, clearInterview: at == null),
  );

  /// Sets (or, with null, clears) the day to follow up with the employer.
  Future<void> setFollowUp(String id, DateTime? at) => _setDate(
    id,
    (r) => r.updateDates(id, followUpAt: at, clearFollowUp: at == null),
    (a) => a.copyWith(followUpAt: at, clearFollowUp: at == null),
  );

  Future<void> _setDate(
    String id,
    Future<void> Function(ApplicationsRepository r) write,
    ApplicationRecord Function(ApplicationRecord a) apply,
  ) async {
    final repo = _repo;
    if (repo == null) {
      return emit(state.copyWith(actionFailure: DataFailureKind.notConfigured));
    }
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      await write(repo);
      emit(
        state.copyWith(
          busy: false,
          items: [for (final a in state.items) a.id == id ? apply(a) : a],
        ),
      );
    } catch (e) {
      emit(state.copyWith(busy: false, actionFailure: mapDataError(e)));
    }
  }

  /// Keeps an eye on a listing without claiming anything was sent: stage "interested", no application date. Refuses a second entry for the
  /// same listing. Returns false (and reports why) when nothing was stored; [alreadyTracked] tells the two apart.
  Future<bool> trackInterest(JobPosting job) async {
    if (isTracked(job)) {
      emit(state.copyWith(actionFailure: DataFailureKind.duplicate));
      return false;
    }
    final hasListing = job.source != manualSource && job.originalUrl.isNotEmpty;
    return create(
      company: job.company.isEmpty ? job.title : job.company,
      title: job.title,
      link: hasListing ? job.originalUrl : null,
      channel: job.sourceName,
      stage: ApplicationStage.interested,
    );
  }

  /// Whether this listing is already followed (by its link, or by title and company for entries typed by hand).
  bool isTracked(JobPosting job) => state.items.any(
    (a) =>
        (job.originalUrl.isNotEmpty && a.job.originalUrl == job.originalUrl) ||
        (a.job.source == job.source && a.job.externalId == job.externalId),
  );

  Future<void> delete(String id) async {
    final repo = _repo;
    if (repo == null) {
      return emit(state.copyWith(actionFailure: DataFailureKind.notConfigured));
    }
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      await repo.delete(id);
      emit(
        state.copyWith(
          busy: false,
          items: [
            for (final a in state.items)
              if (a.id != id) a,
          ],
          history: {...state.history}..remove(id),
        ),
      );
    } catch (e) {
      emit(state.copyWith(busy: false, actionFailure: mapDataError(e)));
    }
  }

  Future<void> loadHistory(String id) async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final events = await repo.history(id);
      emit(state.copyWith(history: {...state.history, id: events}));
    } catch (e) {
      emit(state.copyWith(actionFailure: mapDataError(e)));
    }
  }

  static String? _blank(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }
}
