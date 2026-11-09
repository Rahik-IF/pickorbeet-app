import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/network/api_client.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/features/auth/models/auth_session.dart';

final securityRepositoryProvider = Provider<SecurityRepository>(
  (ref) => SecurityRepository(ref.watch(apiClientProvider)),
);

/// An emailed code the customer still has to enter.
@immutable
class SecurityChallenge {
  const SecurityChallenge({required this.challenge, required this.emailHint, this.requiresCode = false});

  final String challenge;
  final String emailHint;
  final bool requiresCode;

  factory SecurityChallenge.fromMap(Json map) => SecurityChallenge(
        challenge: map.str('challenge'),
        emailHint: map.str('email_hint'),
        requiresCode: map.boolean('requires_code') || map.str('challenge').isNotEmpty,
      );
}

/// Turning 2FA off either finishes or asks for an email code.
@immutable
class DisableTwoFactorResult {
  const DisableTwoFactorResult({this.message, this.challenge});

  final String? message;
  final SecurityChallenge? challenge;

  bool get needsCode => challenge != null;

  factory DisableTwoFactorResult.fromMap(Json map) {
    if (map.str('challenge').isNotEmpty) {
      return DisableTwoFactorResult(challenge: SecurityChallenge.fromMap(map));
    }
    return DisableTwoFactorResult(message: map.str('message', 'Two-factor authentication is off.'));
  }
}

@immutable
class SignedInDevice {
  const SignedInDevice({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.current,
    this.ipAddress,
    this.lastSeen,
    this.createdAt,
  });

  final String id;
  final String deviceName;
  final String platform;
  final bool current;
  final String? ipAddress;
  final DateTime? lastSeen;
  final DateTime? createdAt;

  factory SignedInDevice.fromMap(Json map) => SignedInDevice(
        id: map.str('id'),
        deviceName: map.str('device_name', 'Unknown device'),
        platform: map.str('platform'),
        current: map.boolean('current'),
        ipAddress: map.strOrNull('ip_address'),
        lastSeen: map.date('last_seen'),
        createdAt: map.date('created_at'),
      );
}

@immutable
class LoginActivityEntry {
  const LoginActivityEntry({
    required this.id,
    required this.success,
    required this.method,
    required this.deviceName,
    required this.platform,
    this.ipAddress,
    this.createdAt,
  });

  final String id;
  final bool success;
  final String method;
  final String deviceName;
  final String platform;
  final String? ipAddress;
  final DateTime? createdAt;

  String get methodLabel => switch (method) {
        'google' => 'Google',
        'two_factor' => 'Email code',
        'verification' => 'Email verification',
        _ => 'Password',
      };

  factory LoginActivityEntry.fromMap(Json map) => LoginActivityEntry(
        id: map.str('id'),
        success: map.boolean('success'),
        method: map.str('method'),
        deviceName: map.str('device_name', 'Unknown device'),
        platform: map.str('platform'),
        ipAddress: map.strOrNull('ip_address'),
        createdAt: map.date('created_at'),
      );
}

class SecurityRepository {
  const SecurityRepository(this._api);

  final ApiClient _api;

  Future<Either<AppFailure, AuthSession>> verifyLogin({required String challenge, required String code}) {
    return guardRequest(
      () => _api.post(
        '/auth/2fa/verify/',
        authenticated: false,
        body: {'challenge': challenge, 'otp_code': code},
      ),
      (body) => AuthSession.fromMap(asJson(body)),
    );
  }

  Future<Either<AppFailure, String>> resend(String challenge) {
    return guardRequest(
      () => _api.post('/auth/2fa/resend/', authenticated: false, body: {'challenge': challenge}),
      (body) => asJson(body).str('message', 'A new code is on its way.'),
    );
  }

  Future<Either<AppFailure, SecurityChallenge>> enableTwoFactor() {
    return guardRequest(
      () => _api.post('/auth/2fa/enable/', body: const {}),
      (body) => SecurityChallenge.fromMap(asJson(body)),
    );
  }

  Future<Either<AppFailure, String>> confirmTwoFactor({required String challenge, required String code}) {
    return guardRequest(
      () => _api.post('/auth/2fa/enable/confirm/', body: {'challenge': challenge, 'otp_code': code}),
      (body) => asJson(body).str('message', 'Two-factor authentication is on.'),
    );
  }

  Future<Either<AppFailure, DisableTwoFactorResult>> disableTwoFactor({
    String? password,
    String? challenge,
    String? code,
  }) {
    return guardRequest(
      () => _api.post('/auth/2fa/disable/', body: {
        if (password != null && password.isNotEmpty) 'password': password,
        if (challenge != null && challenge.isNotEmpty) 'challenge': challenge,
        if (code != null && code.isNotEmpty) 'otp_code': code,
      }),
      (body) => DisableTwoFactorResult.fromMap(asJson(body)),
    );
  }

  Future<Either<AppFailure, List<SignedInDevice>>> sessions() {
    return guardRequest(
      () => _api.get('/auth/sessions/'),
      (body) => asJson(body).listOf('results', SignedInDevice.fromMap),
    );
  }

  Future<Either<AppFailure, String>> revokeSession(String id) {
    return guardRequest(
      () => _api.post('/auth/sessions/$id/revoke/', body: const {}),
      (body) => asJson(body).str('message', 'Signed out of that device.'),
    );
  }

  Future<Either<AppFailure, String>> revokeOtherSessions() {
    return guardRequest(
      () => _api.post('/auth/sessions/revoke-others/', body: const {}),
      (body) => asJson(body).str('message', 'Signed out of every other device.'),
    );
  }

  Future<Either<AppFailure, List<LoginActivityEntry>>> loginActivity() {
    return guardRequest(
      () => _api.get('/auth/login-activity/'),
      (body) => asJson(body).listOf('results', LoginActivityEntry.fromMap),
    );
  }

  Future<Either<AppFailure, SecurityChallenge>> startRecoveryEmail(String email) {
    return guardRequest(
      () => _api.post('/auth/recovery-email/', body: {'email': email.trim()}),
      (body) => SecurityChallenge.fromMap(asJson(body)),
    );
  }

  Future<Either<AppFailure, String>> confirmRecoveryEmail({required String challenge, required String code}) {
    return guardRequest(
      () => _api.post('/auth/recovery-email/confirm/', body: {'challenge': challenge, 'otp_code': code}),
      (body) => asJson(body).str('message', 'Recovery email saved.'),
    );
  }

  Future<Either<AppFailure, String>> removeRecoveryEmail() {
    return guardRequest(
      () => _api.delete('/auth/recovery-email/'),
      (body) => asJson(body).str('message', 'Recovery email removed.'),
    );
  }
}
