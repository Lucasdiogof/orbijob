import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../features/profile/domain/resume_repository.dart';
import 'user_scope.dart';

/// Why a data operation failed, independent of the backend. The UI maps each kind to a localised message and
/// to the right action (sign in, retry, nothing). Raw server text is never shown: it can leak internals.
enum DataFailureKind {
  /// This build has no Supabase configuration: the feature cannot work here.
  notConfigured,

  /// No signed-in user.
  signedOut,

  /// The session ended or the token was rejected: sign in again.
  sessionExpired,
  network,

  /// Row Level Security or a Storage policy refused the operation.
  denied,

  /// A per-user limit (résumés, favourites, searches, applications) was reached.
  quotaExceeded,
  duplicate,
  invalidInput,
  tooLarge,
  notPdf,
  emptyFile,
  notFound,
  unavailable,
  unknown,
}

class DataFailure implements Exception {
  const DataFailure(this.kind);
  final DataFailureKind kind;
  @override
  String toString() => 'DataFailure($kind)';
}

/// Maps any error thrown by a repository or the Supabase client to a [DataFailureKind]. Pure and tested.
DataFailureKind mapDataError(Object error) {
  if (error is DataFailure) return error.kind;
  if (error is NotSignedInException) return DataFailureKind.signedOut;
  if (error is ResumeRejected) {
    return switch (error.reason) {
      ResumeRejection.notPdf => DataFailureKind.notPdf,
      ResumeRejection.tooLarge => DataFailureKind.tooLarge,
      ResumeRejection.empty => DataFailureKind.emptyFile,
    };
  }
  if (error is sb.PostgrestException) {
    final code = error.code ?? '';
    final msg = error.message.toLowerCase();
    if (code == '42501') return DataFailureKind.denied;
    if (code == 'PGRST301' || code == 'PGRST303' || msg.contains('jwt')) {
      return DataFailureKind.sessionExpired;
    }
    if (code == '53400' || msg.contains('quota exceeded')) {
      return DataFailureKind.quotaExceeded;
    }
    if (code == '23505') return DataFailureKind.duplicate;
    if (code == 'PGRST116') return DataFailureKind.notFound;
    if (const {
      '23502',
      '23503',
      '23514',
      '22001',
      '22P02',
      '22007',
      '22008',
    }.contains(code)) {
      return DataFailureKind.invalidInput;
    }
    if (code.startsWith('PGRST') || code.startsWith('08')) {
      return DataFailureKind.unavailable;
    }
    return DataFailureKind.unknown;
  }
  if (error is sb.StorageException) {
    final status = int.tryParse(error.statusCode ?? '');
    final msg = error.message.toLowerCase();
    if (status == 413 || msg.contains('exceeded the maximum allowed size')) {
      return DataFailureKind.tooLarge;
    }
    if (msg.contains('mime type')) return DataFailureKind.notPdf;
    if (status == 401 || status == 403) {
      return msg.contains('jwt') || msg.contains('expired')
          ? DataFailureKind.sessionExpired
          : DataFailureKind.denied;
    }
    if (status == 404) return DataFailureKind.notFound;
    if (status == 409) return DataFailureKind.duplicate;
    if (status != null && status >= 500) return DataFailureKind.unavailable;
    return DataFailureKind.unknown;
  }
  if (error is sb.AuthRetryableFetchException) return DataFailureKind.network;
  if (error is sb.AuthException) {
    final status = int.tryParse(error.statusCode ?? '');
    if (status == 401 || status == 403 || error.code == 'session_expired') {
      return DataFailureKind.sessionExpired;
    }
    return DataFailureKind.unknown;
  }
  if (error is TimeoutException || error is http.ClientException) {
    return DataFailureKind.network;
  }
  // dart:io's SocketException cannot be named on the web build; match it by type name instead.
  final type = error.runtimeType.toString();
  if (type == 'SocketException' ||
      type == 'HandshakeException' ||
      type == '_ClientSocketException') {
    return DataFailureKind.network;
  }
  return DataFailureKind.unknown;
}

/// Whether the failure means "the user has to authenticate" (the UI offers the sign-in screen).
bool needsSignIn(DataFailureKind k) =>
    k == DataFailureKind.signedOut || k == DataFailureKind.sessionExpired;
