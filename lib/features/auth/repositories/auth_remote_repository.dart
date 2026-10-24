import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/models/user_model.dart';
import 'package:pickorbeet/core/network/api_client.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/features/auth/models/auth_session.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_remote_repository.g.dart';

@riverpod
AuthRemoteRepository authRemoteRepository(Ref ref) => AuthRemoteRepository(ref.watch(apiClientProvider));

/// `/auth/` endpoints. Credential calls go out without a Bearer token: SimpleJWT would reject a
/// stale one before the view runs.
class AuthRemoteRepository {
  AuthRemoteRepository(this._api);

  final ApiClient _api;

  Future<Either<AppFailure, AuthSession>> login({required String email, required String password}) {
    return guardRequest(
      () => _api.post('/auth/login/', body: {'email': email.trim(), 'password': password}, authenticated: false),
      (body) => AuthSession.fromMap(asJson(body)),
      success: const {200},
    );
  }

  Future<Either<AppFailure, RegistrationResult>> register({
    required String email,
    required String firstName,
    required String lastName,
    required String password,
    required String passwordConfirm,
    String? phone,
  }) {
    return guardRequest(
      () => _api.post(
        '/auth/register/',
        authenticated: false,
        body: {
          'email': email.trim(),
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          'password': password,
          'password_confirm': passwordConfirm,
        },
      ),
      (body) {
        final map = asJson(body);
        return RegistrationResult(
          email: map.obj('user')?.str('email') ?? email.trim(),
          message: map.str('message', 'Check your email for the verification code.'),
          requiresVerification: map.boolean('requires_verification', true),
        );
      },
    );
  }

  Future<Either<AppFailure, AuthSession>> google(String credential) {
    return guardRequest(
      () => _api.post('/auth/google/', body: {'credential': credential}, authenticated: false),
      (body) => AuthSession.fromMap(asJson(body)),
      success: const {200},
    );
  }

  Future<Either<AppFailure, AuthSession>> verifyEmail({required String email, required String code}) {
    return guardRequest(
      () => _api.post('/auth/verify-email/', body: {'email': email.trim(), 'otp_code': code.trim()}, authenticated: false),
      (body) => AuthSession.fromMap(asJson(body)),
      success: const {200},
    );
  }

  Future<Either<AppFailure, String>> resendVerification(String email) {
    return guardRequest(
      () => _api.post('/auth/resend-verification/', body: {'email': email.trim()}, authenticated: false),
      (body) => body is Map ? asJson(body).str('message', 'A new code is on its way.') : 'A new code is on its way.',
    );
  }

  Future<Either<AppFailure, String>> forgotPassword(String email) {
    return guardRequest(
      () => _api.post('/auth/forgot-password/', body: {'email': email.trim()}, authenticated: false),
      (body) => body is Map
          ? asJson(body).str('message', 'If that email is registered, a reset link is on its way.')
          : 'If that email is registered, a reset link is on its way.',
    );
  }

  Future<Either<AppFailure, String>> resetPassword({
    required String token,
    required String password,
    required String passwordConfirm,
  }) {
    return guardRequest(
      () => _api.post(
        '/auth/reset-password/',
        authenticated: false,
        body: {'token': token.trim(), 'new_password': password, 'new_password_confirm': passwordConfirm},
      ),
      (body) => body is Map ? asJson(body).str('message', 'Password updated.') : 'Password updated.',
    );
  }

  Future<Either<AppFailure, UserModel>> profile() {
    return guardRequest(
      () => _api.get('/auth/profile/'),
      (body) => UserModel.fromMap(asJson(body)),
      success: const {200},
    );
  }

  Future<Either<AppFailure, UserModel>> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? address,
    String? city,
    String? postalCode,
    List<int>? avatarBytes,
    String? avatarFilename,
    bool clearAvatar = false,
  }) {
    final text = <String, Object?>{
      'first_name': ?firstName?.trim(),
      'last_name': ?lastName?.trim(),
      'phone': ?phone?.trim(),
      'address': ?address?.trim(),
      'city': ?city?.trim(),
      'postal_code': ?postalCode?.trim(),
    };
    if (avatarBytes != null) {
      return guardRequest(
        () => _api.patchFile(
          '/auth/profile/',
          fields: {for (final entry in text.entries) entry.key: '${entry.value}'},
          fileField: 'avatar',
          filename: avatarFilename ?? 'avatar.jpg',
          bytes: avatarBytes,
        ),
        (body) => UserModel.fromMap(asJson(body)),
        success: const {200},
      );
    }
    return guardRequest(
      () => _api.patch('/auth/profile/', body: {
        ...text,
        if (clearAvatar) 'clear_avatar': true,
      }),
      (body) => UserModel.fromMap(asJson(body)),
      success: const {200},
    );
  }

  Future<Either<AppFailure, String>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) {
    return guardRequest(
      () => _api.post('/auth/change-password/', body: {
        'old_password': oldPassword,
        'new_password': newPassword,
        'new_password_confirm': newPasswordConfirm,
      }),
      (body) => body is Map ? asJson(body).str('message', 'Password changed.') : 'Password changed.',
      success: const {200},
    );
  }

  /// Blacklists the refresh token. Callers clear local tokens whatever the result.
  Future<Either<AppFailure, Unit>> logout(String refresh) {
    return guardRequest(
      () => _api.post('/auth/logout/', body: {'refresh': refresh}),
      (_) => unit,
      success: const {200, 205},
    );
  }
}
