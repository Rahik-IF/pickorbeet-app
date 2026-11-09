import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// On-device unlock. The server never sees this choice.
@immutable
class BiometricPreference {
  const BiometricPreference({required this.enabled, required this.method});

  final bool enabled;

  /// `fingerprint` or `face`.
  final String method;

  static const off = BiometricPreference(enabled: false, method: 'fingerprint');

  bool get usesFace => method == 'face';

  BiometricPreference copyWith({bool? enabled, String? method}) => BiometricPreference(
        enabled: enabled ?? this.enabled,
        method: method ?? this.method,
      );
}

@immutable
class BiometricSupport {
  const BiometricSupport({required this.fingerprint, required this.face});

  final bool fingerprint;
  final bool face;

  bool get any => fingerprint || face;

  static const none = BiometricSupport(fingerprint: false, face: false);
}

class BiometricStore {
  const BiometricStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  static const enabledKey = 'biometric_enabled';
  static const methodKey = 'biometric_method';

  final FlutterSecureStorage _storage;

  Future<BiometricPreference> read() async {
    try {
      final enabled = await _storage.read(key: enabledKey) == '1';
      final method = await _storage.read(key: methodKey);
      return BiometricPreference(
        enabled: enabled,
        method: method == 'face' ? 'face' : 'fingerprint',
      );
    } on Object {
      return BiometricPreference.off;
    }
  }

  Future<void> write(BiometricPreference preference) async {
    await _storage.write(key: enabledKey, value: preference.enabled ? '1' : '0');
    await _storage.write(key: methodKey, value: preference.method);
  }
}

class BiometricLock extends Notifier<BiometricPreference> {
  BiometricLock([this._seed]);

  final BiometricPreference? _seed;
  final _store = const BiometricStore();
  final _auth = LocalAuthentication();

  @override
  BiometricPreference build() => _seed ?? BiometricPreference.off;

  Future<BiometricSupport> support() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return BiometricSupport.none;
      final types = await _auth.getAvailableBiometrics();
      final face = types.contains(BiometricType.face);
      final fingerprint = types.contains(BiometricType.fingerprint) ||
          types.contains(BiometricType.strong) ||
          types.contains(BiometricType.weak);
      if (face && !types.contains(BiometricType.fingerprint) && types.length == 1) {
        return const BiometricSupport(fingerprint: false, face: true);
      }
      return BiometricSupport(fingerprint: fingerprint, face: face);
    } on Object {
      return BiometricSupport.none;
    }
  }

  Future<bool> prompt(String reason) async {
    try {
      final supported = await _auth.isDeviceSupported();
      final enrolled = await _auth.canCheckBiometrics;
      if (!supported && !enrolled) return false;
      return _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } on Object {
      return false;
    }
  }

  Future<bool> enable(String method) async {
    final ok = await prompt(
      method == 'face'
          ? 'Confirm Face ID to unlock PickOrbeet'
          : 'Confirm your fingerprint to unlock PickOrbeet',
    );
    if (!ok) return false;
    final next = BiometricPreference(enabled: true, method: method);
    await _store.write(next);
    state = next;
    return true;
  }

  Future<void> selectMethod(String method) async {
    final next = state.copyWith(method: method);
    await _store.write(next);
    state = next;
  }

  Future<void> disable() async {
    final next = state.copyWith(enabled: false);
    await _store.write(next);
    state = next;
  }
}

final biometricLockProvider = NotifierProvider<BiometricLock, BiometricPreference>(BiometricLock.new);
