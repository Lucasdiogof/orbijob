import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/data/data_failure.dart';
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
  });

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
  }) => ApplicationsState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    items: items ?? this.items,
    history: history ?? this.history,
    busy: busy ?? this.busy,
    actionFailure: actionFailure,
    actionTick: actionFailure == null ? actionTick : actionTick + 1,
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
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          clearFailure: true,
          items: await repo.list(),
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
              if (a.id == id) _withStage(a, stage) else a,
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
              if (a.id == id) _withNote(a, _blank(note)) else a,
          ],
        ),
      );
    } catch (e) {
      emit(state.copyWith(busy: false, actionFailure: mapDataError(e)));
    }
  }

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

  static ApplicationRecord _withStage(
    ApplicationRecord a,
    ApplicationStage s,
  ) => ApplicationRecord(
    id: a.id,
    job: a.job,
    stage: s,
    channel: a.channel,
    appliedAt: a.appliedAt,
    note: a.note,
    profileId: a.profileId,
  );

  static ApplicationRecord _withNote(ApplicationRecord a, String? n) =>
      ApplicationRecord(
        id: a.id,
        job: a.job,
        stage: a.stage,
        channel: a.channel,
        appliedAt: a.appliedAt,
        note: n,
        profileId: a.profileId,
      );
}
