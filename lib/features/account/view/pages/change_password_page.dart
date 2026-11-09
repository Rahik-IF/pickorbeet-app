import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pickorbeet/core/providers/current_user_notifier.dart';
import 'package:pickorbeet/core/providers/preferences_notifier.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/security/security_chrome.dart';
import 'package:pickorbeet/features/auth/repositories/auth_remote_repository.dart';
import 'package:pickorbeet/features/auth/view/widgets/auth_scaffold.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _obscure = true;
  var _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(currentUserNotifierProvider);
    final needsCurrent = user?.hasPassword ?? true;
    if (needsCurrent && _current.text.isEmpty) {
      showToast(context, 'Enter your current password.', kind: ToastKind.error);
      return;
    }
    if (_next.text.length < 8) {
      showToast(context, 'Use at least 8 characters.', kind: ToastKind.error);
      return;
    }
    if (_next.text != _confirm.text) {
      showToast(context, "Those passwords don't match.", kind: ToastKind.error);
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(authRemoteRepositoryProvider).changePassword(
          oldPassword: needsCurrent ? _current.text : null,
          newPassword: _next.text,
          newPasswordConfirm: _confirm.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => showToast(context, failure.message, kind: ToastKind.error),
      (message) {
        showToast(context, message, kind: ToastKind.success);
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = SecurityTone.of(ref.watch(preferencesProvider).darkMode);
    final hasPassword = ref.watch(currentUserNotifierProvider)?.hasPassword ?? true;
    return SecuritySubpage(
      tone: tone,
      title: hasPassword ? 'Change Password' : 'Set a Password',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hasPassword
                ? 'Other signed-in devices will be signed out. This device stays signed in.'
                : 'You signed in with Google. A password lets you sign in with email as well.',
            style: AppTypography.bodySmall.copyWith(color: tone.meta, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (hasPassword) ...[
            AuthField(
              controller: _current,
              label: 'Current password',
              obscure: _obscure,
              suffix: _visibility(),
            ),
            const SizedBox(height: 12),
          ],
          AuthField(
            controller: _next,
            label: 'New password',
            obscure: _obscure,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AuthField(
            controller: _confirm,
            label: 'Confirm new password',
            obscure: _obscure,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 18),
          AppButton(label: hasPassword ? 'Update password' : 'Save password', loading: _busy, onPressed: _busy ? null : _save),
        ],
      ),
    );
  }

  Widget _visibility() {
    return IconButton(
      onPressed: () => setState(() => _obscure = !_obscure),
      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
    );
  }
}
