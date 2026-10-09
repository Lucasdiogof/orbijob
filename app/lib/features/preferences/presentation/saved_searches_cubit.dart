import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/data_failure.dart';
import '../../../core/data/load_status.dart';
import '../domain/user_preferences.dart';

class SavedSearchesState extends Equatable {
  const SavedSearchesState({
    this.status = LoadStatus.loading,
    this.failure,
    this.items = const [],
    this.busy = false,
    this.actionFailure,
    this.actionTick = 0,
  });

  final LoadStatus status;
  final DataFailureKind? failure;
  final List<SavedSearch> items;
  final bool busy;
  final DataFailureKind? actionFailure;
  final int actionTick;

  SavedSearchesState copyWith({
    LoadStatus? status,
    DataFailureKind? failure,
    bool clearFailure = false,
    List<SavedSearch>? items,
    bool? busy,
    DataFailureKind? actionFailure,
  }) => SavedSearchesState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    items: items ?? this.items,
    busy: busy ?? this.busy,
    actionFailure: actionFailure,
    actionTick: actionFailure == null ? actionTick : actionTick + 1,
  );

  @override
  List<Object?> get props => [
    status,
    failure,
    items,
    busy,
    actionFailure,
    actionTick,
  ];
}

/// Searches the user chose to keep (stored in the account), as opposed to the "recent searches" list, which is
/// local to this device and session. A saved search is `{term, country?}`.
class SavedSearchesCubit extends Cubit<SavedSearchesState> {
  SavedSearchesCubit(this._repo) : super(const SavedSearchesState());

  final SavedSearchesRepository? _repo;

  static const maxTermLength = 200;

  static String termOf(SavedSearch s) => '${s.query['term'] ?? ''}';
  static String? countryOf(SavedSearch s) {
    final c = s.query['country'];
    return c is String && c.isNotEmpty ? c : null;
  }

  bool isSaved(String term, {String? countryCode}) => state.items.any(
    (s) =>
        termOf(s).toLowerCase() == term.trim().toLowerCase() &&
        countryOf(s) == countryCode,
  );

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

  Future<bool> save(String term, {String? countryCode}) async {
    final repo = _repo;
    final t = term.trim();
    if (repo == null) {
      emit(state.copyWith(actionFailure: DataFailureKind.notConfigured));
      return false;
    }
    if (t.isEmpty || t.length > maxTermLength) {
      emit(state.copyWith(actionFailure: DataFailureKind.invalidInput));
      return false;
    }
    if (state.status == LoadStatus.failure &&
        needsSignIn(state.failure ?? DataFailureKind.unknown)) {
      emit(state.copyWith(actionFailure: state.failure));
      return false;
    }
    if (state.busy) return false;
    if (isSaved(t, countryCode: countryCode)) {
      emit(state.copyWith(actionFailure: DataFailureKind.duplicate));
      return false;
    }
    emit(state.copyWith(busy: true));
    try {
      final s = await repo.add({'term': t, 'country': ?countryCode});
      emit(state.copyWith(busy: false, items: [s, ...state.items]));
      return true;
    } catch (e) {
      emit(state.copyWith(busy: false, actionFailure: mapDataError(e)));
      return false;
    }
  }

  Future<void> remove(String id) async {
    final repo = _repo;
    if (repo == null || state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      await repo.remove(id);
      emit(
        state.copyWith(
          busy: false,
          items: [
            for (final s in state.items)
              if (s.id != id) s,
          ],
        ),
      );
    } catch (e) {
      emit(state.copyWith(busy: false, actionFailure: mapDataError(e)));
    }
  }
}
