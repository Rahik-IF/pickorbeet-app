import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
      final hardware = await _auth.canCheckBiometrics;
      final types = await _enrolledTypes();
      final face = types.contains(BiometricType.face);
      // Android reports strong or weak, never Face ID. A sensor with nothing
      // enrolled still counts, so the switch can open the system prompt.
      final fingerprint = types.contains(BiometricType.fingerprint) ||
          types.contains(BiometricType.strong) ||
          types.contains(BiometricType.weak) ||
          (hardware && !face);
      return BiometricSupport(fingerprint: fingerprint, face: face);
    } on Object {
      return BiometricSupport.none;
    }
  }

  Future<List<BiometricType>> _enrolledTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on Object {
      return const [];
    }
  }

  /// Null when the person confirmed. Otherwise a message safe to show.
  Future<String?> confirm(String reason) async {
    try {
      final hardware = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      if (!hardware && !supported) {
        return 'This phone has no fingerprint or face unlock.';
      }
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      return ok ? null : 'Biometric verification was cancelled.';
    } on PlatformException catch (error) {
      return switch (error.code) {
        'NotEnrolled' => 'Add a fingerprint or face in your device settings, then turn this on.',
        'NotAvailable' => 'This phone has no fingerprint or face unlock set up.',
        'LockedOut' || 'PermanentlyLockedOut' => 'Biometrics are locked. Unlock the phone with your PIN, then try again.',
        'no_fragment_activity' => 'Reinstall the latest build, then try fingerprint again.',
        _ => 'Biometric verification could not start.',
      };
    } on Object {
      return 'Biometric verification could not start.';
    }
  }

  Future<bool> prompt(String reason) async => (await confirm(reason)) == null;

  /// Null when biometric unlock is now on.
  Future<String?> enable(String method) async {
    final failure = await confirm(
      method == 'face'
          ? 'Confirm Face ID to unlock PickOrbeet'
          : 'Confirm your fingerprint to unlock PickOrbeet',
    );
    if (failure != null) return failure;
    final next = BiometricPreference(enabled: true, method: method);
    await _store.write(next);
    state = next;
    return null;
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
