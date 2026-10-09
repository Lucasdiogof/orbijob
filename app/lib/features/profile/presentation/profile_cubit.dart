import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/data_failure.dart';
import '../../../core/data/load_status.dart';
import '../domain/professional_profile.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.status = LoadStatus.loading,
    this.failure,
    this.profile,
    this.experiences = const [],
    this.education = const [],
    this.saving = false,
    this.actionFailure,
    this.actionTick = 0,
  });

  final LoadStatus status;
  final DataFailureKind? failure;

  /// Null while ready means the user has not created a professional profile yet.
  final ProfessionalProfile? profile;
  final List<Experience> experiences;
  final List<Education> education;
  final bool saving;
  final DataFailureKind? actionFailure;
  final int actionTick;

  ProfileState copyWith({
    LoadStatus? status,
    DataFailureKind? failure,
    bool clearFailure = false,
    ProfessionalProfile? profile,
    List<Experience>? experiences,
    List<Education>? education,
    bool? saving,
    DataFailureKind? actionFailure,
  }) => ProfileState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    profile: profile ?? this.profile,
    experiences: experiences ?? this.experiences,
    education: education ?? this.education,
    saving: saving ?? this.saving,
    actionFailure: actionFailure,
    actionTick: actionFailure == null ? actionTick : actionTick + 1,
  );

  @override
  List<Object?> get props => [
    status,
    failure,
    profile,
    experiences,
    education,
    saving,
    actionFailure,
    actionTick,
  ];
}

int _byStartDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1; // undated entries go last
  if (b == null) return -1;
  return b.compareTo(a);
}

/// The user's professional profile (the first one they created), with experience and education. Every write waits
/// for the server; on failure nothing changes on screen and [ProfileState.actionFailure] explains why.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repo) : super(const ProfileState());

  final ProfileRepository? _repo;

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
      final profiles = await repo.profiles();
      if (profiles.isEmpty) {
        return emit(
          state.copyWith(status: LoadStatus.ready, clearFailure: true),
        );
      }
      final p = profiles.first;
      final lists = await Future.wait([
        repo.experiences(p.id!),
        repo.education(p.id!),
      ]);
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          clearFailure: true,
          profile: p,
          experiences: lists[0] as List<Experience>,
          education: lists[1] as List<Education>,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: LoadStatus.failure, failure: mapDataError(e)),
      );
    }
  }

  Future<bool> _write(Future<void> Function(ProfileRepository r) run) async {
    final repo = _repo;
    if (repo == null) {
      emit(state.copyWith(actionFailure: DataFailureKind.notConfigured));
      return false;
    }
    if (state.saving) return false;
    emit(state.copyWith(saving: true));
    try {
      await run(repo);
      emit(state.copyWith(saving: false));
      return true;
    } catch (e) {
      emit(state.copyWith(saving: false, actionFailure: mapDataError(e)));
      return false;
    }
  }

  Future<bool> saveProfile(ProfessionalProfile p) => _write((r) async {
    final saved = await r.save(p);
    emit(state.copyWith(profile: saved));
  });

  Future<bool> saveExperience(Experience e) => _write((r) async {
    final saved = e.id == null
        ? await r.addExperience(e)
        : await r.updateExperience(e);
    final rest = state.experiences.where((x) => x.id != saved.id);
    emit(
      state.copyWith(
        experiences: [...rest, saved]
          ..sort((a, b) => _byStartDesc(a.startDate, b.startDate)),
      ),
    );
  });

  Future<bool> removeExperience(String id) => _write((r) async {
    await r.removeExperience(id);
    emit(
      state.copyWith(
        experiences: [
          for (final x in state.experiences)
            if (x.id != id) x,
        ],
      ),
    );
  });

  Future<bool> saveEducation(Education e) => _write((r) async {
    final saved = e.id == null
        ? await r.addEducation(e)
        : await r.updateEducation(e);
    final rest = state.education.where((x) => x.id != saved.id);
    emit(
      state.copyWith(
        education: [...rest, saved]
          ..sort((a, b) => _byStartDesc(a.startDate, b.startDate)),
      ),
    );
  });

  Future<bool> removeEducation(String id) => _write((r) async {
    await r.removeEducation(id);
    emit(
      state.copyWith(
        education: [
          for (final x in state.education)
            if (x.id != id) x,
        ],
      ),
    );
  });
}
