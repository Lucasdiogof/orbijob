/// The device side of push notifications, independent of the provider so the registrar can be tested without Firebase.
///
/// Push is a COPY of the in-app notification centre: everything still works when push is unavailable (web, a build without the Firebase
/// configuration, permission denied). [start] then simply answers false.
abstract class PushMessaging {
  /// `android` / `ios` (the values `push_devices.platform` accepts), or null where push is not offered (web, desktop).
  String? get platform;

  /// Initialises the provider and asks the person for permission (once; the system remembers the answer). False = no push on this device.
  Future<bool> start();

  /// The current device token, or null.
  Future<String?> token();

  /// A new token issued by the provider (rotation, app data cleared).
  Stream<String> get tokenRefresh;

  /// The person tapped a push: emits the notification id it carries (opens the notification centre).
  Stream<String> get opened;

  /// Forgets this device's token at the provider (sign-out), so a later account gets a fresh one.
  Future<void> deleteToken();
}

/// No push at all (web, tests, builds without the Firebase configuration).
class NoPushMessaging implements PushMessaging {
  const NoPushMessaging();
  @override
  String? get platform => null;
  @override
  Future<bool> start() async => false;
  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<String> get opened => const Stream.empty();
  @override
  Future<void> deleteToken() async {}
}

/// Where the device tokens of the signed-in person are kept (`public.push_devices`, owner-only).
abstract class PushDevicesRepository {
  Future<void> register({
    required String token,
    required String platform,
    String? locale,
  });
  Future<void> remove(String token);
}
