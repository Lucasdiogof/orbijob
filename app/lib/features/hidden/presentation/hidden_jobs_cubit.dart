import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/data_failure.dart';
import '../../../core/data/load_status.dart';
import '../../search/domain/entities/job_posting.dart';
import '../domain/hidden_jobs_repository.dart';

class HiddenJobsState extends Equatable {
  const HiddenJobsState({
    this.status = LoadStatus.loading,
    this.failure,
    this.items = const {},
    this.actionFailure,
    this.actionTick = 0,
  });

  final LoadStatus status;
  final DataFailureKind? failure;

  /// Hidden jobs by key, newest first.
  final Map<String, HiddenJob> items;
  final DataFailureKind? actionFailure;
  final int actionTick;

  bool isHidden(JobPosting j) => items.containsKey(hiddenKey(j));

  HiddenJobsState copyWith({
    LoadStatus? status,
    DataFailureKind? failure,
    bool clearFailure = false,
    Map<String, HiddenJob>? items,
    DataFailureKind? actionFailure,
  }) => HiddenJobsState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    items: items ?? this.items,
    actionFailure: actionFailure,
    actionTick: actionFailure == null ? actionTick : actionTick + 1,
  );

  @override
  List<Object?> get props => [
    status,
    failure,
    items.keys.toList(),
    actionFailure,
    actionTick,
  ];
}

/// The jobs the person hid. Hiding and restoring show at once and are put back if the server refuses, so the list on screen is never ahead of
/// what is stored. Lists elsewhere in the app drop hidden jobs through [visible]; nothing is ever deleted from the catalogue.
class HiddenJobsCubit extends Cubit<HiddenJobsState> {
  HiddenJobsCubit(this._repo) : super(const HiddenJobsState());

  final HiddenJobsRepository? _repo;

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
      final list = await repo.list();
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          clearFailure: true,
          items: {for (final h in list) h.key: h},
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: LoadStatus.failure, failure: mapDataError(e)),
      );
    }
  }

  /// The jobs of [all] that are not hidden, in the same order. Without a loaded list (signed out, offline) nothing is dropped.
  List<T> visible<T>(Iterable<T> all, JobPosting Function(T) job) => [
    for (final x in all)
      if (!state.isHidden(job(x))) x,
  ];

  Future<bool> hide(JobPosting job) async {
    final repo = _repo;
    if (repo == null) return _fail(DataFailureKind.notConfigured);
    if (state.status == LoadStatus.failure &&
        needsSignIn(state.failure ?? DataFailureKind.unknown)) {
      return _fail(state.failure!);
    }
    if (state.isHidden(job)) return true;
    final before = state.items;
    final h = HiddenJob.of(job, DateTime.now().toUtc());
    emit(state.copyWith(items: {h.key: h, ...before}));
    try {
      await repo.hide(job);
      return true;
    } catch (e) {
      emit(state.copyWith(items: before, actionFailure: mapDataError(e)));
      return false;
    }
  }

  Future<bool> restore(String key) async {
    final repo = _repo;
    if (repo == null) return _fail(DataFailureKind.notConfigured);
    final before = state.items;
    if (!before.containsKey(key)) return true;
    emit(state.copyWith(items: {...before}..remove(key)));
    try {
      await repo.restore(key);
      return true;
    } catch (e) {
      emit(state.copyWith(items: before, actionFailure: mapDataError(e)));
      return false;
    }
  }

  bool _fail(DataFailureKind k) {
    emit(state.copyWith(actionFailure: k));
    return false;
  }
}
