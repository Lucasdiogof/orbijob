import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/config/app_config.dart';

String jwt(Map<String, Object?> payload) {
  String b64(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.${b64(payload)}.sig';
}

void main() {
  group('AppConfig', () {
    test('unconfigured is valid and reports no Supabase', () {
      const c = AppConfig();
      expect(c.hasSupabase, isFalse);
      expect(c.validate(), isNull);
    });

    test('accepts https URL with a publishable key and a legacy anon JWT', () {
      for (final key in [
        'sb_publishable_abc123',
        jwt({'role': 'anon'}),
      ]) {
        expect(
          AppConfig(
            supabaseUrl: 'https://x.supabase.co',
            supabasePublishableKey: key,
          ).validate(),
          isNull,
        );
      }
    });

    test(
      'auth redirect: optional, https / localhost / custom app scheme only',
      () {
        AppConfig c(String r) => AppConfig(
          supabaseUrl: 'https://x.supabase.co',
          supabasePublishableKey: 'sb_publishable_abc',
          authRedirectUrl: r,
        );
        expect(c('').redirectTo, isNull);
        expect(c('  ').redirectTo, isNull);
        for (final ok in [
          'https://app.example.com',
          'http://localhost:3000',
          'com.lucksrei.orbijob://auth-callback',
        ]) {
          expect(c(ok).validate(), isNull, reason: ok);
          expect(c(ok).redirectTo, ok);
        }
        for (final bad in [
          'http://app.example.com',
          'javascript:alert(1)',
          'data:text/html,x',
          'file:///etc/passwd',
          'not a url',
        ]) {
          expect(c(bad).validate(), isNotNull, reason: bad);
        }
      },
    );

    test('rejects secret and service_role keys', () {
      for (final key in [
        'sb_secret_abc123',
        jwt({'role': 'service_role'}),
      ]) {
        final p = AppConfig(
          supabaseUrl: 'https://x.supabase.co',
          supabasePublishableKey: key,
        ).validate();
        expect(p, contains('secret'), reason: key);
      }
      expect(AppConfig.isSecretKey('not.a.jwt'), isFalse);
      expect(AppConfig.isSecretKey(''), isFalse);
    });

    test('rejects plain http except localhost', () {
      expect(
        const AppConfig(
          supabaseUrl: 'http://x.supabase.co',
          supabasePublishableKey: 'sb_publishable_k',
        ).validate(),
        isNotNull,
      );
      expect(
        const AppConfig(
          supabaseUrl: 'http://localhost:54321',
          supabasePublishableKey: 'sb_publishable_k',
        ).validate(),
        isNull,
      );
      expect(
        const AppConfig(
          supabaseUrl: 'not a url',
          supabasePublishableKey: 'sb_publishable_k',
        ).validate(),
        isNotNull,
      );
    });
  });

  test('no service_role / secret key handling anywhere in app sources', () {
    final offenders = <String>[];
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      // Mentions are allowed only in the guard that REJECTS such keys.
      if (RegExp(
            'service_role|SERVICE_ROLE',
            caseSensitive: false,
          ).hasMatch(text) &&
          !f.path.endsWith('core/config/app_config.dart')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
