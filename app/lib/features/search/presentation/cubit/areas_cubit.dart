import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  AreasCubit(this._repo, {this._prefs}) : super(const AreasState());
  final SearchRepository? _repo;
  final SharedPreferences? _prefs;

  /// Last counts that were read from the server (JSON `{area: count}`), shown at once on the next start while the fresh ones load.
  static const cacheKey = 'orbijob.area_counts.v1';

  bool _running = false;

  Map<JobArea, int> _cached() {
    try {
      final raw = _prefs?.getString(cacheKey);
      if (raw == null) return const {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final a in JobArea.values)
          if (map[a.name] is int && (map[a.name] as int) >= 0)
            a: map[a.name] as int,
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> _store(Map<JobArea, int> counts) async {
    try {
      await _prefs?.setString(
        cacheKey,
        jsonEncode({for (final e in counts.entries) e.key.name: e.value}),
      );
    } catch (_) {}
  }

  /// Loads the counts once at a time (a second call while one is running does nothing). Cached counts appear first, each fresh count
  /// replaces its own area as soon as it arrives, an area that fails keeps its last known number, and a total failure leaves the cached
  /// chips (or none) without touching the rest of the screen: the Home never waits for this.
  Future<void> load() async {
    final repo = _repo;
    if (repo is! AreaCountSource) return emit(const AreasState(loaded: true));
    if (_running) return;
    _running = true;
    final cached = _cached();
    if (cached.isNotEmpty) emit(AreasState(counts: cached));
    final fresh = <JobArea, int>{};
    void show(Map<JobArea, int> soFar) {
      if (isClosed) return;
      fresh
        ..clear()
        ..addAll(soFar);
      emit(AreasState(counts: {...cached, ...fresh}));
    }

    try {
      final counts = await (repo as AreaCountSource).areaCounts(
        onPartial: show,
      );
      await _store({...cached, ...counts});
      if (!isClosed) {
        emit(AreasState(loaded: true, counts: {...cached, ...counts}));
      }
    } catch (_) {
      // no wrong chips: only what was cached or already counted stays; the search itself still works
      if (!isClosed) {
        emit(AreasState(loaded: true, counts: {...cached, ...fresh}));
      }
    } finally {
      _running = false;
    }
  }
}
