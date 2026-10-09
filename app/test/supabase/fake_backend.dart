import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const testUserA = '00000000-0000-0000-0000-00000000000a';
const testPublishableKey = 'sb_publishable_test_key';

class Recorded {
  Recorded(this.request, this.body);
  final http.BaseRequest request;
  final String body;
  String get method => request.method;
  String get path => request.url.path;
  Map<String, String> get query => request.url.queryParameters;
  Object? get json => body.isEmpty ? null : jsonDecode(body);
}

/// A Supabase client wired to an in-memory HTTP handler: nothing leaves the process. Every request is recorded
/// so tests can assert paths, filters, headers and bodies.
class FakeBackend {
  FakeBackend({this.signedIn = true, this.respond}) {
    client = SupabaseClient(
      'https://example-project.supabase.co',
      testPublishableKey,
      authOptions: AuthClientOptions(pkceAsyncStorage: _MemoryPkceStorage()),
      httpClient: MockClient((req) async {
        final body = req.body;
        requests.add(Recorded(req, body));
        final r = respond?.call(req.method, req.url, body);
        return http.Response(
          r == null || r.$2 == null ? '[]' : jsonEncode(r.$2),
          r?.$1 ?? 200,
          request: req,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    if (signedIn) {
      final exp =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      client.auth.setInitialSession(
        jsonEncode({
          'access_token': _fakeJwt(exp),
          'refresh_token': 'refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'expires_at': exp,
          'user': {
            'id': testUserA,
            'aud': 'authenticated',
            'email': 'a@example.com',
            'app_metadata': <String, Object?>{},
            'user_metadata': <String, Object?>{},
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
    }
  }

  final bool signedIn;
  late final SupabaseClient client;
  final requests = <Recorded>[];

  /// (method, url, body) -> (status, json body)
  final (int, Object?) Function(String method, Uri url, String body)? respond;

  Recorded get last => requests.last;
}

String _fakeJwt(int exp) {
  String b64(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': testUserA, 'role': 'authenticated', 'exp': exp})}.sig';
}

class _MemoryPkceStorage extends GotrueAsyncStorage {
  final _m = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _m[key];
  @override
  Future<void> setItem({required String key, required String value}) async =>
      _m[key] = value;
  @override
  Future<void> removeItem({required String key}) async => _m.remove(key);
}
