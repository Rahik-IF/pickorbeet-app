import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/providers/current_user_notifier.dart';
import 'package:pickorbeet/core/providers/preferences_notifier.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/security/security_chrome.dart';
import 'package:pickorbeet/features/account/security/security_repository.dart';
import 'package:pickorbeet/features/auth/biometric.dart';

class SecurityPasswordPage extends ConsumerStatefulWidget {
  const SecurityPasswordPage({super.key});

  @override
  ConsumerState<SecurityPasswordPage> createState() => _SecurityPasswordPageState();
}

class _SecurityPasswordPageState extends ConsumerState<SecurityPasswordPage> {
  var _busy = false;
  BiometricSupport _support = BiometricSupport.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(sessionNotifierProvider.notifier).refreshProfile();
      _loadBiometrics();
    });
  }

  Future<void> _loadBiometrics() async {
    final support = await ref.read(biometricLockProvider.notifier).support();
    if (mounted) setState(() => _support = support);
  }

  Future<void> _toggleTwoFactor(bool turnOn) async {
    if (_busy) return;
    final user = ref.read(currentUserNotifierProvider);
    final repo = ref.read(securityRepositoryProvider);
    final tone = SecurityTone.of(ref.read(preferencesProvider).darkMode);
    if (turnOn) {
      if (user == null || !user.isVerified) {
        showToast(context, 'Verify your email before turning on two-factor authentication.', kind: ToastKind.error);
        return;
      }
      setState(() => _busy = true);
      final started = await repo.enableTwoFactor();
      if (!mounted) return;
      setState(() => _busy = false);
      final challenge = started.fold((failure) {
        showToast(context, failure.message, kind: ToastKind.error);
        return null;
      }, (value) => value);
      if (challenge == null || !mounted) return;
      final ok = await showSecurityCodeSheet(
        context: context,
        tone: tone,
        title: 'Turn on two-factor authentication',
        emailHint: challenge.emailHint.isEmpty ? user.email : challenge.emailHint,
        challenge: challenge.challenge,
        repository: repo,
        onSubmit: (code) async {
          final confirmed = await repo.confirmTwoFactor(challenge: challenge.challenge, code: code);
          return confirmed.fold((failure) => failure.message, (_) => null);
        },
      );
      if (ok && mounted) {
        await ref.read(sessionNotifierProvider.notifier).refreshProfile();
        if (!mounted) return;
        showToast(context, 'Two-factor authentication is on.', kind: ToastKind.success);
      }
      return;
    }

    if (user?.hasPassword ?? true) {
      final password = await showPasswordPrompt(
        context: context,
        tone: tone,
        title: 'Turn off two-factor authentication',
        message: 'Enter your password to stop email codes at sign-in.',
      );
      if (password == null || password.isEmpty || !mounted) return;
      setState(() => _busy = true);
      final result = await repo.disableTwoFactor(password: password);
      if (!mounted) return;
      setState(() => _busy = false);
      result.fold(
        (failure) => showToast(context, failure.message, kind: ToastKind.error),
        (_) async {
          await ref.read(sessionNotifierProvider.notifier).refreshProfile();
          if (!mounted) return;
          showToast(context, 'Two-factor authentication is off.');
        },
      );
      return;
    }

    setState(() => _busy = true);
    final started = await repo.disableTwoFactor();
    if (!mounted) return;
    setState(() => _busy = false);
    await started.fold(
      (failure) async => showToast(context, failure.message, kind: ToastKind.error),
      (value) async {
        final challenge = value.challenge;
        if (challenge == null) {
          await ref.read(sessionNotifierProvider.notifier).refreshProfile();
          return;
        }
        final ok = await showSecurityCodeSheet(
          context: context,
          tone: tone,
          title: 'Turn off two-factor authentication',
          emailHint: challenge.emailHint.isEmpty ? (user?.email ?? '') : challenge.emailHint,
          challenge: challenge.challenge,
          repository: repo,
          onSubmit: (code) async {
            final confirmed = await repo.disableTwoFactor(challenge: challenge.challenge, code: code);
            return confirmed.fold(
              (failure) => failure.message,
              (done) => done.needsCode ? 'Enter the code from your email.' : null,
            );
          },
        );
        if (ok && mounted) {
          await ref.read(sessionNotifierProvider.notifier).refreshProfile();
          if (!mounted) return;
          showToast(context, 'Two-factor authentication is off.');
        }
      },
    );
  }

  Future<void> _toggleBiometric(bool turnOn) async {
    final lock = ref.read(biometricLockProvider.notifier);
    final current = ref.read(biometricLockProvider);
    if (!turnOn) {
      await lock.disable();
      return;
    }
    if (!_support.any) {
      showToast(context, 'Set up fingerprint or Face ID in your device settings first.', kind: ToastKind.error);
      return;
    }
    final preferred = current.usesFace && _support.face
        ? 'face'
        : (_support.fingerprint ? 'fingerprint' : 'face');
    final failure = await lock.enable(preferred);
    if (failure != null && mounted) {
      showToast(context, failure, kind: ToastKind.error);
    }
  }

  Future<void> _selectMethod(String method) async {
    final enabled = ref.read(biometricLockProvider).enabled;
    final available = method == 'face' ? _support.face : _support.fingerprint;
    if (!available) {
      showToast(
        context,
        method == 'face' ? 'Face ID is not available on this device.' : 'Fingerprint is not available on this device.',
        kind: ToastKind.error,
      );
      return;
    }
    if (!enabled) {
      final failure = await ref.read(biometricLockProvider.notifier).enable(method);
      if (failure != null && mounted) showToast(context, failure, kind: ToastKind.error);
      return;
    }
    await ref.read(biometricLockProvider.notifier).selectMethod(method);
  }

  void _explainEmail(String email, bool verified) {
    if (!verified) {
      context.push(Routes.verifyEmailFor(email));
      return;
    }
    final tone = SecurityTone.of(ref.read(preferencesProvider).darkMode);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tone.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email is your only second factor', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800, color: tone.ink)),
            const SizedBox(height: 8),
            Text(
              'Sign-in codes are sent to $email. PickOrbeet does not use an authenticator app or SMS.',
              style: AppTypography.bodySmall.copyWith(color: tone.meta, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = SecurityTone.of(ref.watch(preferencesProvider).darkMode);
    final user = ref.watch(currentUserNotifierProvider);
    final biometric = ref.watch(biometricLockProvider);
    final method = biometric.usesFace && _support.face
        ? 'face'
        : (_support.fingerprint ? 'fingerprint' : biometric.method);
    final high = user?.twoFactorEnabled ?? false;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: tone.page,
      body: Column(
        children: [
          const SecurityHeader(),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              children: [
                _ProtectionCard(tone: tone, high: high),
                const SizedBox(height: 18),
                SecuritySectionLabel(tone: tone, title: 'Login & Verification'),
                const SizedBox(height: 10),
                SecurityCard(
                  tone: tone,
                  child: SecurityTile(
                    tone: tone,
                    icon: PhosphorIconsFill.lockKey,
                    iconColor: const Color(0xFF3B6FE8),
                    iconBackground: const Color(0xFFEAF1FF),
                    title: (user?.hasPassword ?? true) ? 'Change Password' : 'Set a Password',
                    subtitle: (user?.hasPassword ?? true)
                        ? 'Update your account password regularly.'
                        : 'Add a password alongside Google sign-in.',
                    onTap: () => context.push(Routes.setPassword),
                  ),
                ),
                const SizedBox(height: 10),
                SecurityCard(
                  tone: tone,
                  child: SecurityTile(
                    tone: tone,
                    icon: PhosphorIconsFill.shieldCheck,
                    iconColor: const Color(0xFF7C6AE8),
                    iconBackground: const Color(0xFFF0EDFF),
                    title: 'Two-Factor Authentication (2FA)',
                    subtitle: 'Add an extra layer of security to your account using a verification code sent to your email.',
                    trailing: SecuritySwitch(
                      value: high,
                      dark: tone.dark,
                      onChanged: _busy ? null : _toggleTwoFactor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SecurityCard(
                  tone: tone,
                  child: SecurityTile(
                    tone: tone,
                    icon: PhosphorIconsFill.envelopeSimple,
                    iconColor: const Color(0xFF3B78F0),
                    iconBackground: const Color(0xFFEAF2FF),
                    title: 'OTP via Email',
                    subtitle: email.isEmpty ? 'Your sign-in email' : email,
                    onTap: email.isEmpty ? null : () => _explainEmail(email, user?.isVerified ?? false),
                    trailing: _VerifiedBadge(verified: user?.isVerified ?? false),
                  ),
                ),
                const SizedBox(height: 10),
                SecurityCard(
                  tone: tone,
                  child: Column(
                    children: [
                      SecurityTile(
                        tone: tone,
                        icon: PhosphorIconsFill.fingerprint,
                        iconColor: const Color(0xFF3B6FE8),
                        iconBackground: const Color(0xFFEAF1FF),
                        title: 'Biometric Verification',
                        subtitle: _support.any
                            ? "Sign in quickly and securely using your device's biometrics."
                            : 'Set up fingerprint or Face ID in your device settings.',
                        trailing: SecuritySwitch(
                          value: biometric.enabled,
                          dark: tone.dark,
                          onChanged: _toggleBiometric,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: _MethodChip(
                                tone: tone,
                                icon: PhosphorIconsFill.fingerprint,
                                label: 'Fingerprint',
                                selected: method != 'face',
                                enabled: _support.fingerprint,
                                onTap: () => _selectMethod('fingerprint'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MethodChip(
                                tone: tone,
                                icon: PhosphorIconsFill.scanSmiley,
                                label: 'Face ID',
                                selected: method == 'face',
                                enabled: _support.face,
                                onTap: () => _selectMethod('face'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SecurityCard(
                  tone: tone,
                  child: SecurityTile(
                    tone: tone,
                    icon: PhosphorIconsFill.monitor,
                    iconColor: const Color(0xFF8B6CF6),
                    iconBackground: const Color(0xFFF3EEFF),
                    title: 'Login Activity',
                    subtitle: 'See your recent logins and devices.',
                    onTap: () => context.push(Routes.loginActivity),
                  ),
                ),
                const SizedBox(height: 10),
                SecurityCard(
                  tone: tone,
                  child: SecurityTile(
                    tone: tone,
                    icon: PhosphorIconsFill.deviceMobile,
                    iconColor: const Color(0xFF22A35A),
                    iconBackground: const Color(0xFFE5F8EE),
                    title: 'Manage Devices',
                    subtitle: 'Control devices that are signed in to your account.',
                    onTap: () => context.push(Routes.manageDevices),
                  ),
                ),
                const SizedBox(height: 18),
                SecuritySectionLabel(tone: tone, title: 'Additional Security'),
                const SizedBox(height: 10),
                SecurityCard(
                  tone: tone,
                  child: SecurityTile(
                    tone: tone,
                    icon: PhosphorIconsFill.shieldCheck,
                    iconColor: const Color(0xFF22A35A),
                    iconBackground: const Color(0xFFE5F8EE),
                    title: 'Account Recovery',
                    subtitle: user?.recoveryEmail == null
                        ? "Set up a recovery email to regain access if you're locked out."
                        : user!.recoveryEmail!,
                    onTap: () => context.push(Routes.accountRecovery),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  const _ProtectionCard({required this.tone, required this.high});

  final SecurityTone tone;
  final bool high;

  @override
  Widget build(BuildContext context) {
    final badgeColor = high ? const Color(0xFF168A45) : const Color(0xFFB86A00);
    final badgeFill = high ? const Color(0xFFE8F8EE) : const Color(0xFFFFF4E5);
    return SecurityCard(
      tone: tone,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: Color(0xFFE5F8EE), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(PhosphorIconsFill.checkCircle, color: Color(0xFF22A35A), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Account is Protected',
                    style: AppTypography.titleSmall.copyWith(fontSize: 14, fontWeight: FontWeight.w800, color: tone.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    high ? 'Multiple security layers are active.' : 'Turn on email 2FA for high security.',
                    style: AppTypography.bodySmall.copyWith(fontSize: 12, color: tone.meta),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: badgeFill, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsFill.checkCircle, size: 14, color: badgeColor),
                  const SizedBox(width: 4),
                  Text(
                    high ? 'High Security' : 'Standard',
                    style: AppTypography.label.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: badgeColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? const Color(0xFF168A45) : const Color(0xFFB86A00);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(verified ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.warningCircle, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          verified ? 'Verified' : 'Unverified',
          style: AppTypography.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
        const SizedBox(width: 2),
        Icon(PhosphorIconsBold.caretRight, size: 12, color: color.withValues(alpha: 0.7)),
      ],
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.tone,
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final SecurityTone tone;
  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = selected && enabled;
    final border = active ? AppPallete.primary : tone.divider;
    final fill = active ? const Color(0xFFF3F7FF) : tone.card;
    final ink = enabled ? (active ? AppPallete.primary : tone.ink) : tone.hint;
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: active ? 1.4 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: ink),
              const SizedBox(width: 6),
              Text(label, style: AppTypography.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: ink)),
              if (active) ...[
                const SizedBox(width: 6),
                const Icon(PhosphorIconsFill.checkCircle, size: 14, color: AppPallete.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
