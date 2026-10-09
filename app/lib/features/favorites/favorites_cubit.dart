import 'package:flutter_bloc/flutter_bloc.dart';

import '../search/domain/entities/job_posting.dart';

/// In-memory favourites (not persisted yet). Keyed by source + external id.
class FavoritesCubit extends Cubit<Map<String, ScoredJob>> {
  FavoritesCubit() : super(const {});

  static String keyOf(JobPosting j) => '${j.source}:${j.externalId}';

  bool isFavorite(JobPosting j) => state.containsKey(keyOf(j));

  void toggle(ScoredJob s) {
    final next = Map<String, ScoredJob>.of(state);
    final key = keyOf(s.job);
    if (next.remove(key) == null) next[key] = s;
    emit(next);
  }
}
