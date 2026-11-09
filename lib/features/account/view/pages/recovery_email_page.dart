import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pickorbeet/core/providers/current_user_notifier.dart';
import 'package:pickorbeet/core/providers/preferences_notifier.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/security/security_chrome.dart';
import 'package:pickorbeet/features/account/security/security_repository.dart';
import 'package:pickorbeet/features/auth/view/widgets/auth_scaffold.dart';

class RecoveryEmailPage extends ConsumerStatefulWidget {
  const RecoveryEmailPage({super.key});

  @override
  ConsumerState<RecoveryEmailPage> createState() => _RecoveryEmailPageState();
}

class _RecoveryEmailPageState extends ConsumerState<RecoveryEmailPage> {
  final _email = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final address = _email.text.trim();
    if (!address.contains('@') || !address.contains('.')) {
      showToast(context, 'Enter a valid email address.', kind: ToastKind.error);
      return;
    }
    final tone = SecurityTone.of(ref.read(preferencesProvider).darkMode);
    final repo = ref.read(securityRepositoryProvider);
    setState(() => _busy = true);
    final started = await repo.startRecoveryEmail(address);
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
      title: 'Confirm recovery email',
      emailHint: challenge.emailHint.isEmpty ? address : challenge.emailHint,
      challenge: challenge.challenge,
      repository: repo,
      onSubmit: (code) async {
        final confirmed = await repo.confirmRecoveryEmail(challenge: challenge.challenge, code: code);
        return confirmed.fold((failure) => failure.message, (_) => null);
      },
    );
    if (!ok || !mounted) return;
    await ref.read(sessionNotifierProvider.notifier).refreshProfile();
    if (!mounted) return;
    _email.clear();
    showToast(context, 'Recovery email saved.', kind: ToastKind.success);
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    final result = await ref.read(securityRepositoryProvider).removeRecoveryEmail();
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => showToast(context, failure.message, kind: ToastKind.error),
      (message) async {
        await ref.read(sessionNotifierProvider.notifier).refreshProfile();
        if (!mounted) return;
        showToast(context, message, kind: ToastKind.success);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = SecurityTone.of(ref.watch(preferencesProvider).darkMode);
    final recovery = ref.watch(currentUserNotifierProvider)?.recoveryEmail;
    final verified = ref.watch(currentUserNotifierProvider)?.recoveryEmailVerified ?? false;
    return SecuritySubpage(
      tone: tone,
      title: 'Account Recovery',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'If you get locked out, a password reset can be sent to this address as well as your sign-in email.',
            style: AppTypography.bodySmall.copyWith(color: tone.meta, height: 1.4),
          ),
          const SizedBox(height: 16),
          SecurityCard(
            tone: tone,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recovery ?? 'No recovery email yet',
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800, color: tone.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recovery == null
                        ? 'Use an inbox you can open even if you lose this one.'
                        : (verified ? 'Verified. Reset links can be sent here.' : 'Not verified yet.'),
                    style: AppTypography.bodySmall.copyWith(color: tone.meta, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AuthField(
            controller: _email,
            label: recovery == null ? 'Recovery email' : 'New recovery email',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 16),
          AppButton(
            label: recovery == null ? 'Save recovery email' : 'Change recovery email',
            loading: _busy,
            onPressed: _busy ? null : _save,
          ),
          if (recovery != null) ...[
            const SizedBox(height: 8),
            AppButton(
              label: 'Remove recovery email',
              variant: AppButtonVariant.outline,
              onPressed: _busy ? null : _remove,
            ),
          ],
        ],
      ),
    );
  }
}
