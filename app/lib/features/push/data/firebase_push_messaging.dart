import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../domain/push_messaging.dart';

/// Firebase Cloud Messaging on Android and iOS. Nothing here runs on the web or desktop ([platform] is null there).
///
/// Configuration stays out of the repository (it is public): Android reads `android/app/google-services.json` through the Google services
/// Gradle plugin, applied only when that file exists; iOS takes its values from `--dart-define` (FIREBASE_IOS_API_KEY, FIREBASE_IOS_APP_ID,
/// FIREBASE_SENDER_ID, FIREBASE_PROJECT_ID). A build without them starts without push, exactly like [NoPushMessaging].
class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging();

  static const _iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  final _opened = StreamController<String>.broadcast();
  bool? _ready;

  @override
  String? get platform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  Future<bool> _init() async {
    if (_ready != null) return _ready!;
    try {
      if (Firebase.apps.isEmpty) {
        if (platform == 'ios') {
          if (_iosApiKey.isEmpty || _iosAppId.isEmpty || _senderId.isEmpty) {
            return _ready = false;
          }
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: _iosApiKey,
              appId: _iosAppId,
              messagingSenderId: _senderId,
              projectId: _projectId,
              iosBundleId: 'com.lucksrei.orbijob',
            ),
          );
        } else {
          await Firebase.initializeApp(); // google-services.json resources
        }
      }
      FirebaseMessaging.onMessageOpenedApp.listen(_emitOpened);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) scheduleMicrotask(() => _emitOpened(initial));
      return _ready = true;
    } catch (_) {
      return _ready = false;
    }
  }

  void _emitOpened(RemoteMessage m) {
    final id = m.data['notification_id'];
    if (id is String && id.isNotEmpty) _opened.add(id);
  }

  @override
  Future<bool> start() async {
    if (platform == null || !await _init()) return false;
    final s = await FirebaseMessaging.instance.requestPermission();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    if (!(_ready ?? false)) return null;
    if (platform == 'ios') {
      // without an APNs token (no push capability / simulator) FCM has no token to give
      final apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns == null) return null;
    }
    return FirebaseMessaging.instance.getToken();
  }

  @override
  Stream<String> get tokenRefresh => (_ready ?? false)
      ? FirebaseMessaging.instance.onTokenRefresh
      : const Stream.empty();

  @override
  Stream<String> get opened => _opened.stream;

  @override
  Future<void> deleteToken() async {
    if (_ready ?? false) await FirebaseMessaging.instance.deleteToken();
  }
}
