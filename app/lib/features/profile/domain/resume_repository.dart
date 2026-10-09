import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class ResumeFile extends Equatable {
  const ResumeFile({
    required this.id,
    required this.profileId,
    required this.path,
    required this.createdAt,
  });
  final String id;
  final String profileId;
  final String
  path; // '<user_id>/<random>.pdf' inside the private 'resumes' bucket
  final DateTime createdAt;
  @override
  List<Object?> get props => [id, profileId, path, createdAt];
}

enum ResumeRejection { notPdf, tooLarge, empty }

class ResumeRejected implements Exception {
  const ResumeRejected(this.reason);
  final ResumeRejection reason;
  @override
  String toString() => 'ResumeRejected($reason)';
}

/// Private résumé storage. Files are validated on the device (PDF signature, 5 MiB) before upload; the
/// bucket enforces the same limits on the server. Reading is only through short-lived signed URLs.
abstract class ResumeRepository {
  static const maxBytes = 5 * 1024 * 1024;
  Future<List<ResumeFile>> list(String profileId);
  Future<ResumeFile> upload(String profileId, Uint8List pdfBytes);
  Future<String> signedUrl(
    ResumeFile file, {
    Duration validFor = const Duration(seconds: 60),
  });
  Future<void> delete(ResumeFile file);
}
