import 'package:connectivity_plus/connectivity_plus.dart';

/// What kind of connection the device has right now (decides whether language data may be downloaded by itself).
enum NetworkKind {
  /// No connection at all.
  none,

  /// Wi-Fi, Ethernet or similar: unmetered in practice.
  unmetered,

  /// Mobile data (or anything that may be metered).
  mobile,
}

abstract class NetworkProbe {
  Future<NetworkKind> kind();
}

/// The device's own report (connectivity_plus). It says which interface is up, not whether the internet answers: a failed download is
/// handled by the caller.
class DeviceNetworkProbe implements NetworkProbe {
  DeviceNetworkProbe([Connectivity? connectivity])
    : _c = connectivity ?? Connectivity();
  final Connectivity _c;

  @override
  Future<NetworkKind> kind() async {
    try {
      final r = await _c.checkConnectivity();
      if (r.contains(ConnectivityResult.wifi) ||
          r.contains(ConnectivityResult.ethernet)) {
        return NetworkKind.unmetered;
      }
      if (r.contains(ConnectivityResult.mobile)) return NetworkKind.mobile;
      if (r.isEmpty || r.contains(ConnectivityResult.none)) {
        return NetworkKind.none;
      }
      return NetworkKind
          .mobile; // vpn, bluetooth, other: treat as possibly metered
    } catch (_) {
      return NetworkKind.mobile;
    }
  }
}
