import 'package:flutter/foundation.dart';

import 'package:pickorbeet/core/models/user_model.dart';
import 'package:pickorbeet/core/network/json.dart';

/// Tokens and the user returned by login, verify-email, and Google sign-in.
@immutable
class AuthSession {
  const AuthSession({required this.access, required this.refresh, required this.user});

  final String access;
  final String refresh;
  final UserModel user;

  factory AuthSession.fromMap(Json map) => AuthSession(
        access: map.str('access'),
        refresh: map.str('refresh'),
        user: UserModel.fromMap(map.obj('user') ?? const {}),
      );
}

/// Registration does not sign in; it asks for the emailed code.
@immutable
class RegistrationResult {
  const RegistrationResult({required this.email, required this.message, required this.requiresVerification});

  final String email;
  final String message;
  final bool requiresVerification;
}
