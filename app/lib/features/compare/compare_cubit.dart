import 'package:flutter_bloc/flutter_bloc.dart';

import '../search/data/job_snapshot.dart';
import '../search/domain/entities/job_posting.dart';

enum CompareChange { added, removed, full }

/// The jobs picked to be compared side by side, in the order they were picked. Kept in memory for the session only (a comparison is a
/// short-lived scratch pad, not something to store). At most [maxJobs], so each column stays readable.
class CompareCubit extends Cubit<List<JobPosting>> {
  CompareCubit() : super(const []);

  static const maxJobs = 3;

  bool contains(JobPosting j) => state.any((e) => jobKey(e) == jobKey(j));

  /// Adds the job, or removes it when already picked. A fourth job is refused (and reported), never replaces another silently.
  CompareChange toggle(JobPosting j) {
    if (contains(j)) {
      emit([
        for (final e in state)
          if (jobKey(e) != jobKey(j)) e,
      ]);
      return CompareChange.removed;
    }
    if (state.length >= maxJobs) return CompareChange.full;
    emit([...state, j]);
    return CompareChange.added;
  }

  void remove(JobPosting j) => emit([
    for (final e in state)
      if (jobKey(e) != jobKey(j)) e,
  ]);

  void clear() => emit(const []);
}
