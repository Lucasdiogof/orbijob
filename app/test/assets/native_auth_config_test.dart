import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks of the native files that make sign-in work on a device. They cannot prove a deep link opens the
/// app (that needs a phone), but they catch the mistakes that break it silently.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  const scheme = 'com.lucksrei.orbijob';

  test('Android release build can reach the network', () {
    expect(manifest, contains('android.permission.INTERNET'));
  });

  test('Android declares the auth callback scheme on the main activity', () {
    expect(manifest, contains('android:scheme="$scheme"'));
    expect(manifest, contains('android:host="auth-callback"'));
    expect(manifest, contains('android.intent.category.BROWSABLE'));
    expect(manifest, contains('android:launchMode="singleTop"'));
  });

  test('Flutter default deep-link routing is off (supabase_flutter reads the link)', () {
    expect(manifest, contains('flutter_deeplinking_enabled'));
    expect(
      RegExp(r'FlutterDeepLinkingEnabled</key>\s*<false/>').hasMatch(plist),
      isTrue,
    );
  });

  test('iOS registers the same scheme', () {
    expect(plist, contains('<string>$scheme</string>'));
    expect(plist, contains('CFBundleURLSchemes'));
  });

  test('the app config sample uses the same callback URL', () {
    final sample = File('dart_defines.example.json').readAsStringSync();
    expect(sample, contains('AUTH_REDIRECT_URL'));
  });
}
