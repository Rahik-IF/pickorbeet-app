import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/providers/cart_notifier.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/core/providers/current_user_notifier.dart';
import 'package:pickorbeet/features/auth/models/auth_session.dart';
import 'package:pickorbeet/features/auth/repositories/auth_remote_repository.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:pickorbeet/features/notifications/notification_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_notifier.g.dart';

enum SessionStatus { guest, signedIn }

/// Whether a customer is signed in. Tokens decide it synchronously at launch; the profile loads
/// in the background into `CurrentUserNotifier`.
@Riverpod(keepAlive: true)
class SessionNotifier extends _$SessionNotifier {
  @override
  SessionStatus build() {
    ref.read(apiClientProvider).onSessionExpired = _expire;
    if (ref.read(authLocalRepositoryProvider).hasSession) {
      Future.microtask(refreshProfile);
      return SessionStatus.signedIn;
    }
    return SessionStatus.guest;
  }

  Future<void> refreshProfile() async {
    if (state != SessionStatus.signedIn) return;
    final result = await ref.read(authRemoteRepositoryProvider).profile();
    switch (result) {
      case Right(value: final user):
        ref.read(currentUserNotifierProvider.notifier).setUser(user);
      case Left(value: final failure) when failure.kind == FailureKind.unauthorized:
        await ref.read(authLocalRepositoryProvider).clear();
        _expire();
      case Left():
        break;
    }
  }

  /// Saves the session, moves the guest's cart onto the account, and loads the full profile.
  Future<void> signIn(AuthSession session) async {
    final guestLines = state == SessionStatus.guest
        ? (ref.read(cartNotifierProvider).valueOrNull?.items.map(CartLine.of).toList() ?? const <CartLine>[])
        : const <CartLine>[];
    await ref.read(authLocalRepositoryProvider).saveSession(session.access, session.refresh);
    ref.read(currentUserNotifierProvider.notifier).setUser(session.user);
    state = SessionStatus.signedIn;
    await ref.read(cartNotifierProvider.notifier).mergeGuestLines(guestLines);
    unawaited(refreshProfile());
  }

  Future<void> signOut() async {
    await ref.read(notificationRepositoryProvider).unregisterThisDevice();
    final tokens = ref.read(authLocalRepositoryProvider);
    final refresh = tokens.getRefreshToken();
    if (refresh != null) {
      // Best effort: the refresh token is blacklisted server-side when this succeeds.
      await ref.read(authRemoteRepositoryProvider).logout(refresh).timeout(
            const Duration(seconds: 4),
            onTimeout: () => const Left(AppFailure.of(FailureKind.timeout, AppFailure.timeoutMessage)),
          );
    }
    await tokens.clear();
    _expire();
  }

  void _expire() {
    ref.read(currentUserNotifierProvider.notifier).clear();
    state = SessionStatus.guest;
  }
}
