import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../search/data/offline_first_search_repository.dart'
    show classifyCatalogueError;
import '../search/domain/entities/job_posting.dart';
import '../search/domain/job_filters.dart';
import '../search/domain/search_repository.dart';

/// [offline]: no connection and nothing saved to show; [unavailable]: the catalogue answered with an error and nothing is saved. With saved jobs the
/// status stays [ready] and [LatestJobsState.cachedAt] says when they were saved.
enum LatestStatus {
  loading,
  ready,
  empty,
  notConfigured,
  failure,
  offline,
  unavailable,
}

class LatestJobsState extends Equatable {
  const LatestJobsState({
    this.status = LatestStatus.loading,
    this.jobs = const [],
    this.cachedAt,
  });
  final LatestStatus status;
  final List<ScoredJob> jobs;

  /// Set when these are the saved jobs of the last online visit (no connection now): when they were saved.
  final DateTime? cachedAt;
  @override
  List<Object?> get props => [status, jobs, cachedAt];
}

/// The newest jobs of the catalogue, shown on Home as soon as the app opens (no search term needed).
class LatestJobsCubit extends Cubit<LatestJobsState> {
  LatestJobsCubit(
    this._repo, {
    this.filters = const JobFilters(),
    this.reconnectEvery,
  }) : super(const LatestJobsState());
  final SearchRepository _repo;

  /// While saved jobs (or an offline message) are on screen the list is tried again quietly this often; null = never (tests).
  final Duration? reconnectEvery;
  Timer? _reconnect;
  bool _retrying = false;

  @override
  Future<void> close() {
    _reconnect?.cancel();
    return super.close();
  }

  @override
  void onChange(Change<LatestJobsState> change) {
    super.onChange(change);
    final s = change.nextState;
    final waiting =
        s.cachedAt != null ||
        s.status == LatestStatus.offline ||
        s.status == LatestStatus.unavailable;
    final every = reconnectEvery;
    if (!waiting || every == null) {
      _reconnect?.cancel();
      _reconnect = null;
    } else {
      _reconnect ??= Timer.periodic(every, (_) => refreshQuietly());
    }
  }

  /// One quiet attempt: only a fresh answer replaces what is on screen (no loading flicker, no list jump while offline).
  Future<void> refreshQuietly() async {
    if (_retrying || isClosed) return;
    final s = state;
    if (s.status == LatestStatus.loading ||
        s.status == LatestStatus.ready && s.cachedAt == null) {
      return;
    }
    _retrying = true;
    try {
      final r = await _repo.search('', filters: filters, limit: count);
      if (isClosed || r.cachedAt != null || r.notConfigured) return;
      if (!r.hasIntegratedSource || r.jobs.isEmpty) {
        return emit(const LatestJobsState(status: LatestStatus.empty));
      }
      emit(LatestJobsState(status: LatestStatus.ready, jobs: r.jobs));
    } catch (_) {
      // still unreachable: keep what is on screen
    } finally {
      _retrying = false;
    }
  }

  /// What the list is restricted to (the remote-jobs section of Home uses the remote work mode).
  final JobFilters filters;

  static const count = 12;

  Future<void> load() async {
    emit(const LatestJobsState());
    try {
      final r = await _repo.search('', filters: filters, limit: count);
      if (r.notConfigured) {
        return emit(const LatestJobsState(status: LatestStatus.notConfigured));
      }
      if (!r.hasIntegratedSource || r.jobs.isEmpty) {
        return emit(const LatestJobsState(status: LatestStatus.empty));
      }
      emit(
        LatestJobsState(
          status: LatestStatus.ready,
          jobs: r.jobs,
          cachedAt: r.cachedAt,
        ),
      );
    } catch (e) {
      emit(
        LatestJobsState(
          status: switch (classifyCatalogueError(e)) {
            CatalogueFailure.offline => LatestStatus.offline,
            CatalogueFailure.server => LatestStatus.unavailable,
            CatalogueFailure.other => LatestStatus.failure,
          },
        ),
      );
    }
  }
}

/// The newest REMOTE jobs (Home section). Same behaviour as [LatestJobsCubit], restricted to the remote work mode.
class RemoteJobsCubit extends LatestJobsCubit {
  RemoteJobsCubit(super.repo, {super.reconnectEvery})
    : super(filters: const JobFilters(workModes: {WorkMode.remote}));
}
