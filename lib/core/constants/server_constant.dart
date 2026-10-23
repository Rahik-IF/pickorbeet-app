import 'dart:io' show Platform;

/// Where the Django API lives.
///
/// Pass `--dart-define=API_ORIGIN=http://192.168.0.10:8000` for a physical device or a deployed
/// server. Without it, Android emulators use the host alias `10.0.2.2` and everything else uses
/// `127.0.0.1`.
abstract final class ServerConstant {
  static const _originOverride = String.fromEnvironment('API_ORIGIN');

  static final String origin = _resolveOrigin();

  static String get apiBase => '$origin/api/v1';

  static String _resolveOrigin() {
    final value = _originOverride.trim();
    if (value.isNotEmpty) {
      return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
    }
    return Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';
  }

  /// Resolves a media path from the API. Catalog payloads use `/media/...`, cart and order
  /// payloads are already absolute.
  static String mediaUrl(String? path) {
    if (path == null) return '';
    final value = path.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    return value.startsWith('/') ? '$origin$value' : '$origin/$value';
  }
}
