import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/job_area.dart';
import '../../domain/search_repository.dart';

/// How many open jobs each professional area has right now. Areas with no job are not offered, so no chip ever leads to
/// an empty list because the catalogue simply has nothing there.
class AreasState extends Equatable {
  const AreasState({this.loaded = false, this.counts = const {}});

  /// The request finished (successfully or not).
  final bool loaded;
  final Map<JobArea, int> counts;

  /// Areas with at least one job, in the declaration order of [JobArea].
  List<JobArea> get available => [
    for (final a in JobArea.values)
      if ((counts[a] ?? 0) > 0) a,
  ];

  @override
  List<Object?> get props => [loaded, counts];
}

class AreasCubit extends Cubit<AreasState> {
  AreasCubit(this._repo) : super(const AreasState());
  final SearchRepository? _repo;

  Future<void> load() async {
    final repo = _repo;
    if (repo is! AreaCountSource) return emit(const AreasState(loaded: true));
    try {
      final counts = await (repo as AreaCountSource).areaCounts();
      emit(AreasState(loaded: true, counts: counts));
    } catch (_) {
      emit(
        const AreasState(loaded: true),
      ); // no chips rather than wrong ones; the search itself still works
    }
  }
}
