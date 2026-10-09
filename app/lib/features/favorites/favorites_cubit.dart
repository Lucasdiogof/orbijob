import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/data/data_failure.dart';
import '../../core/data/load_status.dart';
import '../search/data/job_snapshot.dart';
import '../search/domain/entities/job_posting.dart';
import 'domain/favorites_repository.dart';

class FavoritesState extends Equatable {
  const FavoritesState({
    this.status = LoadStatus.loading,
    this.failure,
    this.items = const {},
    this.pending = const {},
    this.actionFailure,
    this.actionTick = 0,
  });

  final LoadStatus status;
  final DataFailureKind? failure;

  /// Saved jobs by [jobKey], newest first.
  final Map<String, ScoredJob> items;

  /// Keys with a request in flight: a second tap on the same job is ignored until it finishes.
  final Set<String> pending;

  /// The last failed save/remove (shown once as a message); [actionTick] makes repeats observable.
  final DataFailureKind? actionFailure;
  final int actionTick;

  FavoritesState copyWith({
    LoadStatus? status,
    DataFailureKind? failure,
    bool clearFailure = false,
    Map<String, ScoredJob>? items,
    Set<String>? pending,
    DataFailureKind? actionFailure,
  }) => FavoritesState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    items: items ?? this.items,
    pending: pending ?? this.pending,
    actionFailure: actionFailure,
    actionTick: actionFailure == null ? actionTick : actionTick + 1,
  );

  @override
  List<Object?> get props => [
    status,
    failure,
    items,
    pending,
    actionFailure,
    actionTick,
  ];
}

/// Saved jobs of the signed-in user, persisted through [FavoritesRepository]. The heart updates at once and is
/// rolled back with a message if the server refuses (quota, policy, network): a failed request is never shown as
/// saved. One request per job at a time, so a double tap or two devices cannot create duplicates (the server also
/// upserts on `(user_id, job_key)`).
class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit(this._repo) : super(const FavoritesState());

  /// Null when this build has no backend: the feature is reported as not configured instead of faking storage.
  final FavoritesRepository? _repo;

  static String keyOf(JobPosting j) => jobKey(j);

  bool isFavorite(JobPosting j) => state.items.containsKey(keyOf(j));
  bool isPending(JobPosting j) => state.pending.contains(keyOf(j));

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
      final jobs = await repo.list();
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          clearFailure: true,
          items: {for (final j in jobs) keyOf(j): ScoredJob(j)},
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: LoadStatus.failure, failure: mapDataError(e)),
      );
    }
  }

  Future<void> toggle(ScoredJob s) async {
    final repo = _repo;
    if (repo == null) {
      return emit(state.copyWith(actionFailure: DataFailureKind.notConfigured));
    }
    if (state.status == LoadStatus.failure &&
        needsSignIn(state.failure ?? DataFailureKind.unknown)) {
      return emit(state.copyWith(actionFailure: state.failure));
    }
    final key = keyOf(s.job);
    if (state.pending.contains(key)) return;
    final wasFavorite = state.items.containsKey(key);
    emit(
      state.copyWith(
        items: wasFavorite
            ? (Map.of(state.items)..remove(key))
            : {key: s, ...state.items},
        pending: {...state.pending, key},
      ),
    );
    try {
      wasFavorite ? await repo.remove(s.job) : await repo.add(s.job);
      emit(state.copyWith(pending: {...state.pending}..remove(key)));
    } catch (e) {
      // Undo only this job: other taps may have changed other keys meanwhile.
      emit(
        state.copyWith(
          items: wasFavorite
              ? {key: s, ...state.items}
              : (Map.of(state.items)..remove(key)),
          pending: {...state.pending}..remove(key),
          actionFailure: mapDataError(e),
        ),
      );
    }
  }
}
