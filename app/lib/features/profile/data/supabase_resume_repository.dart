import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/user_scope.dart';
import '../domain/resume_repository.dart';

const resumesBucket = 'resumes';

/// Checks size and the `%PDF-` signature. Throws [ResumeRejected].
void validateResume(Uint8List bytes) {
  if (bytes.isEmpty) throw const ResumeRejected(ResumeRejection.empty);
  if (bytes.length > ResumeRepository.maxBytes) {
    throw const ResumeRejected(ResumeRejection.tooLarge);
  }
  const sig = [0x25, 0x50, 0x44, 0x46, 0x2d]; // %PDF-
  if (bytes.length < sig.length ||
      !List.generate(sig.length, (i) => bytes[i] == sig[i]).every((b) => b)) {
    throw const ResumeRejected(ResumeRejection.notPdf);
  }
}

String _randomName() {
  final r = Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class SupabaseResumeRepository implements ResumeRepository {
  SupabaseResumeRepository(this._client);
  final SupabaseClient _client;

  ResumeFile _file(Map<String, dynamic> r) => ResumeFile(
    id: r['id'] as String,
    profileId: r['profile_id'] as String,
    path: r['storage_path'] as String,
    createdAt: DateTime.parse(r['created_at'] as String),
  );

  @override
  Future<List<ResumeFile>> list(String profileId) async {
    requireUserId(_client);
    final rows = await _client
        .from('resumes')
        .select()
        .eq('profile_id', profileId)
        .order('created_at', ascending: false);
    return [for (final r in rows) _file(r)];
  }

  @override
  Future<ResumeFile> upload(String profileId, Uint8List pdfBytes) async {
    final uid = requireUserId(_client);
    validateResume(pdfBytes);
    final path = '$uid/${_randomName()}.pdf';
    await _client.storage
        .from(resumesBucket)
        .uploadBinary(
          path,
          pdfBytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: false,
          ),
        );
    try {
      final row = await _client
          .from('resumes')
          .insert({
            'profile_id': profileId,
            'user_id': uid,
            'storage_path': path,
          })
          .select()
          .single();
      return _file(row);
    } catch (_) {
      // Do not leave an orphan object if the row could not be created.
      await _client.storage.from(resumesBucket).remove([path]);
      rethrow;
    }
  }

  @override
  Future<String> signedUrl(
    ResumeFile file, {
    Duration validFor = const Duration(seconds: 60),
  }) {
    requireUserId(_client);
    final secs = validFor.inSeconds.clamp(10, 300);
    return _client.storage.from(resumesBucket).createSignedUrl(file.path, secs);
  }

  @override
  Future<void> delete(ResumeFile file) async {
    requireUserId(_client);
    await _client.storage.from(resumesBucket).remove([file.path]);
    await _client.from('resumes').delete().eq('id', file.id);
  }
}
