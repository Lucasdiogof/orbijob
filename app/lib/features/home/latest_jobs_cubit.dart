import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../search/domain/entities/job_posting.dart';
import '../search/domain/job_filters.dart';
import '../search/domain/search_repository.dart';

enum LatestStatus { loading, ready, empty, notConfigured, failure }

class LatestJobsState extends Equatable {
  const LatestJobsState({
    this.status = LatestStatus.loading,
    this.jobs = const [],
  });
  final LatestStatus status;
  final List<ScoredJob> jobs;
  @override
  List<Object?> get props => [status, jobs];
}

/// The newest jobs of the catalogue, shown on Home as soon as the app opens (no search term needed).
class LatestJobsCubit extends Cubit<LatestJobsState> {
  LatestJobsCubit(this._repo, {this.filters = const JobFilters()})
    : super(const LatestJobsState());
  final SearchRepository _repo;

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
      emit(LatestJobsState(status: LatestStatus.ready, jobs: r.jobs));
    } catch (_) {
      emit(const LatestJobsState(status: LatestStatus.failure));
    }
  }
}

/// The newest REMOTE jobs (Home section). Same behaviour as [LatestJobsCubit], restricted to the remote work mode.
class RemoteJobsCubit extends LatestJobsCubit {
  RemoteJobsCubit(super.repo)
    : super(filters: const JobFilters(workModes: {WorkMode.remote}));
}
