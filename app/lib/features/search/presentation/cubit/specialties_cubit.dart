import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/health_specialty.dart';
import '../../domain/search_repository.dart';

/// How many open jobs each health specialty has. Loaded once, the first time the Health area is opened.
class SpecialtiesState extends Equatable {
  const SpecialtiesState({this.loaded = false, this.counts = const {}});

  final bool loaded;
  final Map<HealthSpecialty, int> counts;

  int countOf(HealthSpecialty s) => counts[s] ?? 0;

  @override
  List<Object?> get props => [loaded, counts];
}

class SpecialtiesCubit extends Cubit<SpecialtiesState> {
  SpecialtiesCubit(this._repo) : super(const SpecialtiesState());
  final SearchRepository? _repo;
  bool _started = false;

  Future<void> ensureLoaded() async {
    if (_started) return;
    _started = true;
    final repo = _repo;
    if (repo is! SpecialtyCountSource) {
      return emit(const SpecialtiesState(loaded: true));
    }
    try {
      final counts = await (repo as SpecialtyCountSource).specialtyCounts();
      emit(SpecialtiesState(loaded: true, counts: counts));
    } catch (_) {
      emit(const SpecialtiesState(loaded: true));
    }
  }
}
