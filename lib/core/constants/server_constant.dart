import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Where the Django API lives.
///
/// Release builds call the live API. Debug builds use the local Django server: Android emulators
/// use the host alias `10.0.2.2`, and everything else uses `127.0.0.1`.
/// Pass `--dart-define=API_ORIGIN=http://192.168.0.10:8000` to point any build somewhere else.
abstract final class ServerConstant {
  static const liveOrigin = 'https://admin.pickorbeet.com';
  static const _originOverride = String.fromEnvironment('API_ORIGIN');

  static final String origin = _resolveOrigin();

  static String get apiBase => '$origin/api/v1';

  static String _resolveOrigin() {
    final value = _originOverride.trim();
    if (value.isNotEmpty) {
      return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
    }
    if (kReleaseMode) return liveOrigin;
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
