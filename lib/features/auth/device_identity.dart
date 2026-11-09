import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable id and display name sent with every API call so the server can name this device.
@immutable
class DeviceIdentity {
  const DeviceIdentity({required this.id, required this.name});

  final String id;
  final String name;

  static const empty = DeviceIdentity(id: '', name: '');

  /// Same key the notification registrar uses, so push and sign-in share one device id.
  static const deviceKey = 'notification_device_id';

  static Future<DeviceIdentity> load(SharedPreferences prefs) async {
    var id = prefs.getString(deviceKey);
    if (id == null || id.isEmpty) {
      id = _randomId();
      await prefs.setString(deviceKey, id);
    }
    return DeviceIdentity(id: id, name: await _deviceName());
  }

  static Future<String> _deviceName() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final name = info.name.trim();
        if (name.isNotEmpty) return name;
        final machine = info.utsname.machine.trim();
        return machine.isEmpty ? 'iPhone' : machine;
      }
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final name = '${info.manufacturer} ${info.model}'.trim();
        return name.isEmpty ? 'Android' : name;
      }
    } on Object {
      // A missing plugin still lets the request through with a generic name.
    }
    return 'PickOrbeet app';
  }
}

final deviceIdentityProvider = Provider<DeviceIdentity>((ref) => DeviceIdentity.empty);

String _randomId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
