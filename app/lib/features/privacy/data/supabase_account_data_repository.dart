import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/data_failure.dart';
import '../../../core/data/user_scope.dart';
import '../domain/account_data_repository.dart';

/// Reads the person's data through the Edge Function `account-export` (which only ever runs as the caller) and packs it with the
/// resume PDFs into one ZIP. The PDFs come from the short-lived signed links of the answer; one that fails does not stop the export.
class SupabaseAccountDataRepository implements AccountDataRepository {
  SupabaseAccountDataRepository(
    this._client, {
    http.Client? http,
    DateTime Function()? clock,
  }) : _http = http ?? _defaultClient(),
       _clock = clock ?? DateTime.now;
  final SupabaseClient _client;
  final http.Client _http;
  final DateTime Function() _clock;

  static http.Client _defaultClient() => http.Client();

  @override
  Future<DataExport> export() async {
    requireUserId(_client);
    final Map<String, dynamic> doc;
    try {
      final r = await _client.functions.invoke(
        'account-export',
        method: HttpMethod.post,
      );
      final d = r.data;
      doc = d is Map<String, dynamic>
          ? d
          : jsonDecode(d as String) as Map<String, dynamic>;
    } on FunctionException catch (e) {
      throw DataFailure(
        e.status == 401
            ? DataFailureKind.sessionExpired
            : e.status >= 500
            ? DataFailureKind.unavailable
            : DataFailureKind.unknown,
      );
    } catch (e) {
      throw DataFailure(mapDataError(e));
    }
    return packExport(doc, fetch: _fetchPdf, now: _clock());
  }

  Future<Uint8List?> _fetchPdf(String url) async {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'https') return null;
      final r = await _http.get(uri).timeout(const Duration(seconds: 30));
      if (r.statusCode != 200 || r.bodyBytes.length < 5) return null;
      return r.bodyBytes;
    } catch (_) {
      return null;
    }
  }
}

/// Builds the ZIP from the server's answer. Pure (the download is injected) and tested. The signed links are replaced by the file name inside
/// the ZIP, so the saved JSON does not keep working links to private files.
Future<DataExport> packExport(
  Map<String, dynamic> doc, {
  required Future<Uint8List?> Function(String url) fetch,
  required DateTime now,
}) async {
  final archive = Archive();
  final files = (doc['resume_files'] as List? ?? const [])
      .whereType<Map>()
      .toList();
  var included = 0;
  var missing = 0;
  final cleaned = <Map<String, dynamic>>[];
  for (var i = 0; i < files.length; i++) {
    final f = Map<String, dynamic>.from(files[i]);
    final url = f.remove('download_url') as String?;
    f.remove('download_url_valid_seconds');
    final bytes = url == null ? null : await fetch(url);
    if (bytes == null) {
      missing++;
      f['included_in_zip'] = false;
    } else {
      final name = 'resumes/${i + 1}-${_safeName(f['file'] as String?)}';
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
      f['included_in_zip'] = true;
      f['zip_path'] = name;
      included++;
    }
    cleaned.add(f);
  }
  final out = Map<String, dynamic>.from(doc)..['resume_files'] = cleaned;
  final json = const JsonEncoder.withIndent('  ').convert(out);
  final jsonBytes = Uint8List.fromList(utf8.encode(json));
  archive.addFile(
    ArchiveFile('orbijob-data.json', jsonBytes.length, jsonBytes),
  );
  final zip = ZipEncoder().encode(archive);
  final d = now.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return DataExport(
    bytes: Uint8List.fromList(zip),
    fileName: 'orbijob-data-${d.year}${two(d.month)}${two(d.day)}.zip',
    resumeFiles: included,
    resumeFilesMissing: missing,
  );
}

String _safeName(String? name) {
  final n = (name ?? 'resume.pdf').replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return n.isEmpty ? 'resume.pdf' : n;
}
