import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/auth/repositories/auth_remote_repository.dart';
import 'package:pickorbeet/features/auth/view/widgets/auth_scaffold.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _email = TextEditingController();
  var _busy = false;
  var _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final result = await ref.read(authRemoteRepositoryProvider).forgotPassword(_email.text);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => showToast(context, failure.message, kind: ToastKind.error),
      (message) => setState(() => _sent = true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _sent ? 'Check your email' : 'Reset your password',
      subtitle: _sent
          ? 'If an account exists for ${_email.text.trim()}, a reset link is on its way.'
          : 'We’ll email you a link to choose a new password.',
      footer: TextButton(onPressed: () => context.go(Routes.login), child: const Text('Back to sign in')),
      child: _sent
          ? const Text(
              'Open the link on this phone. It returns you here to set a new password.',
              style: TextStyle(color: AppPallete.textSecondary, height: 1.4),
            )
          : Column(
              children: [
                AuthField(controller: _email, label: 'Email', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                AppButton(label: 'Send reset link', loading: _busy, onPressed: _busy ? null : _submit),
              ],
            ),
    );
  }
}
