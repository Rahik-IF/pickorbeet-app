import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/auth/repositories/auth_remote_repository.dart';
import 'package:pickorbeet/features/auth/view/widgets/auth_scaffold.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.token.isEmpty) {
      showToast(context, 'This reset link is missing its token.', kind: ToastKind.error);
      return;
    }
    if (_password.text != _confirm.text) {
      showToast(context, 'Passwords do not match.', kind: ToastKind.error);
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(authRemoteRepositoryProvider).resetPassword(
          token: widget.token,
          password: _password.text,
          passwordConfirm: _confirm.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => showToast(context, failure.message, kind: ToastKind.error),
      (message) {
        showToast(context, message, kind: ToastKind.success);
        context.go(Routes.login);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Choose a new password',
      subtitle: 'Use at least 8 characters. You’ll sign in with it next.',
      child: Column(
        children: [
          AuthField(controller: _password, label: 'New password', obscure: true),
          const SizedBox(height: 12),
          AuthField(controller: _confirm, label: 'Confirm password', obscure: true),
          const SizedBox(height: 16),
          AppButton(label: 'Update password', loading: _busy, onPressed: _busy ? null : _submit),
        ],
      ),
    );
  }
}
