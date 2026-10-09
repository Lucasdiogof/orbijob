import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/data_failure.dart';
import '../../../core/data/load_status.dart';
import '../domain/user_preferences.dart';

class PreferencesState extends Equatable {
  const PreferencesState({
    this.status = LoadStatus.loading,
    this.failure,
    this.prefs = const UserPreferences(),
    this.saving = false,
    this.actionFailure,
    this.actionTick = 0,
  });

  final LoadStatus status;
  final DataFailureKind? failure;
  final UserPreferences prefs;
  final bool saving;
  final DataFailureKind? actionFailure;
  final int actionTick;

  /// True once the preferences came from (and can go back to) the account.
  bool get synced => status == LoadStatus.ready;

  PreferencesState copyWith({
    LoadStatus? status,
    DataFailureKind? failure,
    bool clearFailure = false,
    UserPreferences? prefs,
    bool? saving,
    DataFailureKind? actionFailure,
  }) => PreferencesState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    prefs: prefs ?? this.prefs,
    saving: saving ?? this.saving,
    actionFailure: actionFailure,
    actionTick: actionFailure == null ? actionTick : actionTick + 1,
  );

  @override
  List<Object?> get props => [
    status,
    failure,
    prefs,
    saving,
    actionFailure,
    actionTick,
  ];
}

/// Theme, language and countries of interest, kept in the account. Theme and language are applied on the device
/// at once by the caller; this cubit only persists them (and reports when persisting failed, so a change is never
/// presented as saved when it was not).
class PreferencesCubit extends Cubit<PreferencesState> {
  PreferencesCubit(this._repo) : super(const PreferencesState());

  final PreferencesRepository? _repo;

  static const maxCountries =
      30; // `user_preferences.countries_of_interest` check constraint

  /// Two-letter ISO 3166-1 code in upper case, or null when [raw] is not one.
  static String? normalizeCountry(String raw) {
    final c = raw.trim().toUpperCase();
    return RegExp(r'^[A-Z]{2}$').hasMatch(c) ? c : null;
  }

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
          prefs: await repo.load(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: LoadStatus.failure, failure: mapDataError(e)),
      );
    }
  }

  Future<bool> _persist(UserPreferences next) async {
    final repo = _repo;
    // Not loaded from an account (signed out, unavailable): the change stays on this device only.
    if (repo == null || !state.synced) return false;
    if (state.saving) return false;
    final before = state.prefs;
    emit(state.copyWith(saving: true, prefs: next));
    try {
      await repo.save(next);
      emit(state.copyWith(saving: false));
      return true;
    } catch (e) {
      emit(
        state.copyWith(
          saving: false,
          prefs: before,
          actionFailure: mapDataError(e),
        ),
      );
      return false;
    }
  }

  Future<bool> setTheme(String theme) => _persist(
    UserPreferences(
      theme: theme,
      locale: state.prefs.locale,
      countriesOfInterest: state.prefs.countriesOfInterest,
    ),
  );

  Future<bool> setLocale(String? locale) => _persist(
    UserPreferences(
      theme: state.prefs.theme,
      locale: locale,
      countriesOfInterest: state.prefs.countriesOfInterest,
    ),
  );

  /// Adds a country (ISO code). False when the code is invalid, repeated or over the limit.
  Future<bool> addCountry(String raw) async {
    final c = normalizeCountry(raw);
    final list = state.prefs.countriesOfInterest;
    if (c == null || list.contains(c) || list.length >= maxCountries) {
      emit(state.copyWith(actionFailure: DataFailureKind.invalidInput));
      return false;
    }
    return _persist(
      UserPreferences(
        theme: state.prefs.theme,
        locale: state.prefs.locale,
        countriesOfInterest: [...list, c],
      ),
    );
  }

  Future<bool> removeCountry(String code) => _persist(
    UserPreferences(
      theme: state.prefs.theme,
      locale: state.prefs.locale,
      countriesOfInterest: [
        for (final c in state.prefs.countriesOfInterest)
          if (c != code) c,
      ],
    ),
  );
}
