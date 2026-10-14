import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/data/data_failure.dart';
import '../domain/account_data_repository.dart';

/// Hands the finished ZIP to the system (save to Files / Drive / e-mail on a phone, a download in the browser). Injected so tests do not need
/// the platform channel.
typedef DataFileShare = Future<void> Function(DataExport export);

Future<void> shareExportWithSystem(DataExport e) => SharePlus.instance.share(
  ShareParams(
    files: [
      XFile.fromData(e.bytes, mimeType: 'application/zip', name: e.fileName),
    ],
    fileNameOverrides: [e.fileName],
  ),
);

enum ExportPhase { idle, working, done, failed }

class DataExportState extends Equatable {
  const DataExportState({
    this.phase = ExportPhase.idle,
    this.failure,
    this.resumeFiles = 0,
    this.resumeFilesMissing = 0,
  });
  final ExportPhase phase;
  final DataFailureKind? failure;
  final int resumeFiles;
  final int resumeFilesMissing;

  @override
  List<Object?> get props => [phase, failure, resumeFiles, resumeFilesMissing];
}

class DataExportCubit extends Cubit<DataExportState> {
  DataExportCubit(this._repo, {DataFileShare? share})
    : _share = share ?? shareExportWithSystem,
      super(const DataExportState());
  final AccountDataRepository? _repo;
  final DataFileShare _share;

  Future<void> start() async {
    if (state.phase == ExportPhase.working) return;
    final repo = _repo;
    if (repo == null) {
      emit(
        const DataExportState(
          phase: ExportPhase.failed,
          failure: DataFailureKind.notConfigured,
        ),
      );
      return;
    }
    emit(const DataExportState(phase: ExportPhase.working));
    try {
      final e = await repo.export();
      await _share(e);
      emit(
        DataExportState(
          phase: ExportPhase.done,
          resumeFiles: e.resumeFiles,
          resumeFilesMissing: e.resumeFilesMissing,
        ),
      );
    } catch (e) {
      emit(
        DataExportState(phase: ExportPhase.failed, failure: mapDataError(e)),
      );
    }
  }

  void reset() => emit(const DataExportState());
}
