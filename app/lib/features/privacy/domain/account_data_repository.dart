import 'dart:typed_data';

/// "Export my data": one ZIP the person can keep. It holds `orbijob-data.json` (account, profile, experiences, education, skills, preferences,
/// saved searches, favourites, hidden jobs, applications and notes, reminders, notifications, device list without push tokens) and the PDF
/// resumes the person uploaded. Never contains credentials.
class DataExport {
  const DataExport({
    required this.bytes,
    required this.fileName,
    required this.resumeFiles,
    required this.resumeFilesMissing,
  });
  final Uint8List bytes;
  final String fileName;

  /// PDFs included in the ZIP.
  final int resumeFiles;

  /// PDFs that were listed but could not be downloaded (their metadata is still in the JSON).
  final int resumeFilesMissing;
}

abstract class AccountDataRepository {
  Future<DataExport> export();
}
