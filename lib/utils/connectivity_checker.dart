import 'package:connectivity_plus/connectivity_plus.dart';

/// Lightweight connectivity pre-flight guard.
///
/// Used by [DatabaseService] before write operations to surface a
/// [NetworkException] immediately — without waiting for a TCP timeout —
/// when the device has no active network interface.
///
/// Note: A positive result is a hint, not a guarantee (e.g. a connected Wi-Fi
/// with no actual internet still returns true). The existing [SocketException]
/// catch in [DatabaseService._mapError] remains as the authoritative fallback.
abstract final class ConnectivityChecker {
  /// Returns `true` if the device reports at least one active network interface.
  static Future<bool> isConnected() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
