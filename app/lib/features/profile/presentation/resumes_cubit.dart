import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/data_failure.dart';
import '../../../core/data/load_status.dart';
import '../data/supabase_resume_repository.dart' show validateResume;
import '../domain/resume_repository.dart';

class ResumesState extends Equatable {
  const ResumesState({
    this.status = LoadStatus.loading,
    this.failure,
    this.items = const [],
    this.uploading = false,
    this.busyId,
    this.actionFailure,
    this.actionTick = 0,
  });

  final LoadStatus status;
  final DataFailureKind? failure;
  final List<ResumeFile> items;
  final bool uploading;

  /// A résumé being deleted or opened.
  final String? busyId;
  final DataFailureKind? actionFailure;
  final int actionTick;

  ResumesState copyWith({
    LoadStatus? status,
    DataFailureKind? failure,
    bool clearFailure = false,
    List<ResumeFile>? items,
    bool? uploading,
    String? busyId,
    bool clearBusy = false,
    DataFailureKind? actionFailure,
  }) => ResumesState(
    status: status ?? this.status,
    failure: clearFailure ? null : (failure ?? this.failure),
    items: items ?? this.items,
    uploading: uploading ?? this.uploading,
    busyId: clearBusy ? null : (busyId ?? this.busyId),
    actionFailure: actionFailure,
    actionTick: actionFailure == null ? actionTick : actionTick + 1,
  );

  @override
  List<Object?> get props => [
    status,
    failure,
    items,
    uploading,
    busyId,
    actionFailure,
    actionTick,
  ];
}

/// Private résumés (PDF, 5 MiB, at most [ResumeRepository.maxFiles]) of one profile. The file is checked on the
/// device first; the repository removes the stored file if the row cannot be created, so a failure leaves no orphan.
/// A short-lived signed link is only created when the user opens a résumé.
class ResumesCubit extends Cubit<ResumesState> {
  ResumesCubit(this._repo, this.profileId) : super(const ResumesState());

  final ResumeRepository? _repo;
  final String profileId;

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
          items: await repo.list(profileId),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: LoadStatus.failure, failure: mapDataError(e)),
      );
    }
  }

  Future<bool> upload(Uint8List bytes) async {
    final repo = _repo;
    if (repo == null) {
      emit(state.copyWith(actionFailure: DataFailureKind.notConfigured));
      return false;
    }
    if (state.uploading) return false;
    try {
      validateResume(bytes);
    } catch (e) {
      emit(state.copyWith(actionFailure: mapDataError(e)));
      return false;
    }
    if (state.items.length >= ResumeRepository.maxFiles) {
      emit(state.copyWith(actionFailure: DataFailureKind.quotaExceeded));
      return false;
    }
    emit(state.copyWith(uploading: true));
    try {
      final f = await repo.upload(profileId, bytes);
      emit(state.copyWith(uploading: false, items: [f, ...state.items]));
      return true;
    } catch (e) {
      emit(state.copyWith(uploading: false, actionFailure: mapDataError(e)));
      return false;
    }
  }

  Future<void> delete(ResumeFile file) async {
    final repo = _repo;
    if (repo == null || state.busyId != null) return;
    emit(state.copyWith(busyId: file.id));
    try {
      await repo.delete(file);
      emit(
        state.copyWith(
          clearBusy: true,
          items: [
            for (final f in state.items)
              if (f.id != file.id) f,
          ],
        ),
      );
    } catch (e) {
      emit(state.copyWith(clearBusy: true, actionFailure: mapDataError(e)));
    }
  }

  /// A signed link valid for one minute, or null (with [ResumesState.actionFailure]) when it cannot be created.
  Future<String?> openLink(ResumeFile file) async {
    final repo = _repo;
    if (repo == null || state.busyId != null) return null;
    emit(state.copyWith(busyId: file.id));
    try {
      final url = await repo.signedUrl(file);
      emit(state.copyWith(clearBusy: true));
      return url;
    } catch (e) {
      emit(state.copyWith(clearBusy: true, actionFailure: mapDataError(e)));
      return null;
    }
  }
}
