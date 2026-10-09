import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/core/data/load_status.dart';
import 'package:orbijob/features/profile/domain/resume_repository.dart';
import 'package:orbijob/features/profile/presentation/resumes_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers/fakes.dart';

void main() {
  late FakeResumes repo;
  late ResumesCubit c;
  setUp(() {
    repo = FakeResumes();
    c = ResumesCubit(repo, 'p-1');
  });

  test('without a backend: not configured, no upload attempted', () async {
    final n = ResumesCubit(null, 'p');
    await n.load();
    expect(n.state.failure, DataFailureKind.notConfigured);
    expect(await n.upload(tinyPdf()), isFalse);
  });

  test('uploads a PDF and lists it', () async {
    await c.load();
    expect(c.state.status, LoadStatus.ready);
    expect(await c.upload(tinyPdf()), isTrue);
    expect(c.state.items, hasLength(1));
    expect(repo.rows.single.profileId, 'p-1');
    expect(c.state.uploading, isFalse);
  });

  test('rejects non-PDF, empty and oversized files on the device, before any request', () async {
    await c.load();
    expect(
      await c.upload(Uint8List.fromList('hello world'.codeUnits)),
      isFalse,
    );
    expect(c.state.actionFailure, DataFailureKind.notPdf);
    expect(await c.upload(Uint8List(0)), isFalse);
    expect(c.state.actionFailure, DataFailureKind.emptyFile);
    expect(await c.upload(tinyPdf(ResumeRepository.maxBytes)), isFalse);
    expect(c.state.actionFailure, DataFailureKind.tooLarge);
    expect(repo.rows, isEmpty);
  });

  test('exactly 5 MiB is accepted', () async {
    await c.load();
    final bytes = tinyPdf(ResumeRepository.maxBytes - tinyPdf().length);
    expect(bytes.length, ResumeRepository.maxBytes);
    expect(await c.upload(bytes), isTrue);
  });

  test('stops at the 10-file limit without uploading', () async {
    await c.load();
    for (var i = 0; i < ResumeRepository.maxFiles; i++) {
      expect(await c.upload(tinyPdf()), isTrue);
    }
    expect(await c.upload(tinyPdf()), isFalse);
    expect(c.state.actionFailure, DataFailureKind.quotaExceeded);
    expect(repo.rows, hasLength(ResumeRepository.maxFiles));
  });

  test(
    'a failed upload adds nothing to the list and reports the cause',
    () async {
      await c.load();
      repo.error = const sb.StorageException('policy', statusCode: '403');
      expect(await c.upload(tinyPdf()), isFalse);
      expect(c.state.items, isEmpty);
      expect(c.state.actionFailure, DataFailureKind.denied);
      expect(c.state.uploading, isFalse);
    },
  );

  test('delete removes the row (and file) and failure keeps it', () async {
    await c.load();
    await c.upload(tinyPdf());
    final f = c.state.items.single;
    repo.error = const sb.StorageException('x', statusCode: '503');
    await c.delete(f);
    expect(c.state.items, hasLength(1));
    expect(c.state.actionFailure, DataFailureKind.unavailable);
    repo.error = null;
    await c.delete(f);
    expect(c.state.items, isEmpty);
    expect(repo.deleted, 1);
  });

  test('a signed link is created only when the user opens a résumé', () async {
    await c.load();
    await c.upload(tinyPdf());
    expect(await c.openLink(c.state.items.single), startsWith('https://'));
    repo.error = const sb.StorageException('jwt expired', statusCode: '401');
    expect(await c.openLink(c.state.items.single), isNull);
    expect(c.state.actionFailure, DataFailureKind.sessionExpired);
  });
}
