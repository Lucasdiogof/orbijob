import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/core/data/user_scope.dart';
import 'package:orbijob/features/profile/domain/resume_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  DataFailureKind k(Object e) => mapDataError(e);

  group('mapDataError', () {
    test('Postgres / PostgREST codes', () {
      expect(
        k(const sb.PostgrestException(message: 'x', code: '42501')),
        DataFailureKind.denied,
      );
      expect(
        k(const sb.PostgrestException(message: 'x', code: 'PGRST301')),
        DataFailureKind.sessionExpired,
      );
      expect(
        k(
          const sb.PostgrestException(message: 'JWT expired', code: 'PGRST303'),
        ),
        DataFailureKind.sessionExpired,
      );
      expect(
        k(
          const sb.PostgrestException(message: 'quota exceeded', code: '53400'),
        ),
        DataFailureKind.quotaExceeded,
      );
      expect(
        k(const sb.PostgrestException(message: 'saved_jobs quota exceeded')),
        DataFailureKind.quotaExceeded,
      );
      expect(
        k(const sb.PostgrestException(message: 'x', code: '23505')),
        DataFailureKind.duplicate,
      );
      expect(
        k(const sb.PostgrestException(message: 'x', code: 'PGRST116')),
        DataFailureKind.notFound,
      );
      expect(
        k(const sb.PostgrestException(message: 'x', code: '23514')),
        DataFailureKind.invalidInput,
      );
      expect(
        k(const sb.PostgrestException(message: 'x', code: 'PGRST000')),
        DataFailureKind.unavailable,
      );
      expect(
        k(const sb.PostgrestException(message: 'x', code: 'XX000')),
        DataFailureKind.unknown,
      );
    });

    test('Storage statuses', () {
      expect(
        k(const sb.StorageException('x', statusCode: '413')),
        DataFailureKind.tooLarge,
      );
      expect(
        k(
          const sb.StorageException(
            'mime type text/plain is not supported',
            statusCode: '415',
          ),
        ),
        DataFailureKind.notPdf,
      );
      expect(
        k(
          const sb.StorageException(
            'new row violates row-level security policy',
            statusCode: '403',
          ),
        ),
        DataFailureKind.denied,
      );
      expect(
        k(const sb.StorageException('jwt expired', statusCode: '401')),
        DataFailureKind.sessionExpired,
      );
      expect(
        k(const sb.StorageException('x', statusCode: '404')),
        DataFailureKind.notFound,
      );
      expect(
        k(const sb.StorageException('x', statusCode: '503')),
        DataFailureKind.unavailable,
      );
    });

    test('network, timeouts and session errors', () {
      expect(k(http.ClientException('offline')), DataFailureKind.network);
      expect(k(TimeoutException('slow')), DataFailureKind.network);
      expect(
        k(sb.AuthRetryableFetchException(message: 'x')),
        DataFailureKind.network,
      );
      expect(
        k(const sb.AuthApiException('x', statusCode: '401')),
        DataFailureKind.sessionExpired,
      );
      expect(k(NotSignedInException()), DataFailureKind.signedOut);
    });

    test('résumé rejections and anything else', () {
      expect(
        k(const ResumeRejected(ResumeRejection.notPdf)),
        DataFailureKind.notPdf,
      );
      expect(
        k(const ResumeRejected(ResumeRejection.tooLarge)),
        DataFailureKind.tooLarge,
      );
      expect(
        k(const ResumeRejected(ResumeRejection.empty)),
        DataFailureKind.emptyFile,
      );
      expect(k(StateError('boom')), DataFailureKind.unknown);
    });

    test('only signedOut / sessionExpired ask for a sign-in', () {
      for (final kind in DataFailureKind.values) {
        expect(
          needsSignIn(kind),
          kind == DataFailureKind.signedOut ||
              kind == DataFailureKind.sessionExpired,
        );
      }
    });
  });
}
