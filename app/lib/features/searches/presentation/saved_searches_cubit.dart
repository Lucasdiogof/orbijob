import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/data_failure.dart';
import '../../../core/data/load_status.dart';
import '../domain/saved_search.dart';
import '../domain/search_spec.dart';

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

/// Searches the person chose to keep (stored in the account), with their alert settings. Different from the recent searches list, which stays on
/// the device. Every change goes to the server first or is rolled back: what is on screen is what is stored.
class SavedSearchesCubit extends Cubit<SavedSearchesState> {
  SavedSearchesCubit(this._repo) : super(const SavedSearchesState());

  final SavedSearchesRepository? _repo;

  static const maxTermLength = 200;
  static const maxNameLength = 80;

  /// Alerts are limited so a person cannot make the hourly run expensive: the database also caps one pass per search.
  static const maxAlerts = 20;

  /// The saved search that has exactly this meaning, if any.
  SavedSearch? savedFor(SearchSpec spec) {
    final c = spec.canonical;
    for (final s in state.items) {
      if (s.spec.canonical == c) return s;
    }
    return null;
  }

  bool isSaved(String term, {String? countryCode}) =>
      savedFor(SearchSpec(term: term, countryCode: countryCode)) != null;

  int get alertCount => state.items.where((s) => s.alertsEnabled).length;

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

  /// Quick save of a term (the bookmark next to the results).
  Future<bool> save(String term, {String? countryCode}) =>
      saveSpec(SearchSpec(term: term, countryCode: countryCode));

  Future<bool> saveSpec(
    SearchSpec spec, {
    String? name,
    bool alerts = false,
    AlertFrequency frequency = AlertFrequency.daily,
    bool allowDuplicate = false,
  }) async {
    final repo = _repo;
    final n = name?.trim();
    if (repo == null) return _fail(DataFailureKind.notConfigured);
    if (spec.isEmpty ||
        spec.term.trim().length > maxTermLength ||
        (n != null && (n.isEmpty || n.length > maxNameLength))) {
      return _fail(DataFailureKind.invalidInput);
    }
    if (state.status == LoadStatus.failure &&
        needsSignIn(state.failure ?? DataFailureKind.unknown)) {
      return _fail(state.failure!);
    }
    if (state.busy) return false;
    if (!allowDuplicate && savedFor(spec) != null) {
      return _fail(DataFailureKind.duplicate);
    }
    if (alerts && alertCount >= maxAlerts) {
      return _fail(DataFailureKind.quotaExceeded);
    }
    emit(state.copyWith(busy: true));
    try {
      final s = await repo.add(
        spec.toQuery(),
        name: n,
        alertsEnabled: alerts,
        frequency: frequency,
      );
      emit(state.copyWith(busy: false, items: [s, ...state.items]));
      return true;
    } catch (e) {
      return _fail(mapDataError(e), busy: false);
    }
  }

  /// Replaces what a saved search looks for and/or how it is called.
  Future<bool> update(
    String id, {
    SearchSpec? spec,
    String? name,
    bool? alerts,
    AlertFrequency? frequency,
  }) async {
    final repo = _repo;
    final n = name?.trim();
    if (repo == null) return _fail(DataFailureKind.notConfigured);
    final current = state.items.where((s) => s.id == id).firstOrNull;
    if (current == null || state.busy) return false;
    if ((spec != null && spec.isEmpty) ||
        (n != null && (n.isEmpty || n.length > maxNameLength))) {
      return _fail(DataFailureKind.invalidInput);
    }
    if (alerts == true && !current.alertsEnabled && alertCount >= maxAlerts) {
      return _fail(DataFailureKind.quotaExceeded);
    }
    emit(state.copyWith(busy: true));
    try {
      final s = await repo.update(
        id,
        name: n,
        query: spec?.toQuery(),
        alertsEnabled: alerts,
        frequency: frequency,
      );
      emit(
        state.copyWith(
          busy: false,
          items: [for (final e in state.items) e.id == id ? s : e],
        ),
      );
      return true;
    } catch (e) {
      return _fail(mapDataError(e), busy: false);
    }
  }

  Future<bool> rename(String id, String name) => update(id, name: name);
  Future<bool> setAlerts(String id, bool on) => update(id, alerts: on);
  Future<bool> setFrequency(String id, AlertFrequency f) =>
      update(id, frequency: f);

  /// A copy with its own name and alerts off (it does not inherit the alert state).
  Future<bool> duplicate(String id, {required String name}) async {
    final s = state.items.where((e) => e.id == id).firstOrNull;
    if (s == null) return false;
    return saveSpec(
      s.spec,
      name: name,
      frequency: s.frequency,
      allowDuplicate: true,
    );
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

  bool _fail(DataFailureKind k, {bool? busy}) {
    emit(state.copyWith(busy: busy, actionFailure: k));
    return false;
  }
}
