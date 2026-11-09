import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pickorbeet/core/providers/preferences_notifier.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/security/security_chrome.dart';
import 'package:pickorbeet/features/account/security/security_repository.dart';

class TwoFactorLoginPage extends ConsumerStatefulWidget {
  const TwoFactorLoginPage({super.key, required this.args});

  final TwoFactorLoginArgs? args;

  @override
  ConsumerState<TwoFactorLoginPage> createState() => _TwoFactorLoginPageState();
}

class _TwoFactorLoginPageState extends ConsumerState<TwoFactorLoginPage> {
  var _code = '';
  var _busy = false;
  var _seconds = 60;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    while (mounted && _seconds > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _seconds -= 1);
    }
  }

  Future<void> _verify(String code) async {
    final args = widget.args;
    if (args == null || _busy || code.length != 6) return;
    setState(() => _busy = true);
    final result = await ref.read(securityRepositoryProvider).verifyLogin(challenge: args.challenge, code: code);
    if (!mounted) return;
    await result.fold(
      (failure) async {
        setState(() => _busy = false);
        showToast(context, failure.message, kind: ToastKind.error);
      },
      (session) async {
        await completeSignIn(ref, session);
        if (!mounted) return;
        context.go(args.next);
      },
    );
  }

  Future<void> _resend() async {
    final args = widget.args;
    if (args == null || _seconds > 0 || _busy) return;
    setState(() => _busy = true);
    final result = await ref.read(securityRepositoryProvider).resend(args.challenge);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => showToast(context, failure.message, kind: ToastKind.error),
      (message) {
        showToast(context, message);
        setState(() => _seconds = 60);
        _tick();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = SecurityTone.of(ref.watch(preferencesProvider).darkMode);
    final args = widget.args;
    return SecuritySubpage(
      tone: tone,
      title: 'Check your email',
      child: args == null
          ? Text(
              'This sign-in code is no longer available. Go back and sign in again.',
              style: AppTypography.bodySmall.copyWith(color: tone.meta, height: 1.4),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter the 6-digit code sent to ${args.emailHint}.',
                  style: AppTypography.bodySmall.copyWith(color: tone.meta, height: 1.4),
                ),
                const SizedBox(height: 18),
                OtpBoxes(onChanged: (value) => _code = value, onCompleted: _verify),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _seconds == 0 && !_busy ? _resend : null,
                    child: Text(_seconds == 0 ? 'Resend code' : 'Resend code in ${_seconds}s'),
                  ),
                ),
                const SizedBox(height: 8),
                AppButton(label: 'Verify and sign in', loading: _busy, onPressed: _busy ? null : () => _verify(_code)),
              ],
            ),
    );
  }
}
