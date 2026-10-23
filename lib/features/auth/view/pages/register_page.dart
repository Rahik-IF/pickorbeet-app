import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/auth/repositories/auth_remote_repository.dart';
import 'package:pickorbeet/features/auth/view/widgets/auth_scaffold.dart';
import 'package:pickorbeet/features/auth/view/widgets/google_sign_in_button.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _agree = false;
  var _busy = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_agree) {
      showToast(context, 'Please agree to the Terms and Privacy Policy.', kind: ToastKind.error);
      return;
    }
    if (_password.text != _confirm.text) {
      showToast(context, 'Passwords do not match.', kind: ToastKind.error);
      return;
    }
    if (_password.text.length < 8) {
      showToast(context, 'Use at least 8 characters.', kind: ToastKind.error);
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(authRemoteRepositoryProvider).register(
          email: _email.text,
          firstName: _first.text,
          lastName: _last.text,
          password: _password.text,
          passwordConfirm: _confirm.text,
          phone: _phone.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => showToast(context, failure.message, kind: ToastKind.error),
      (created) => context.push(Routes.verifyEmailFor(created.email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'We’ll email a 6-digit code so we know the address is yours.',
      footer: TextButton(onPressed: () => context.go(Routes.login), child: const Text('Already have an account? Sign in')),
      child: Column(
        children: [
          const GoogleSignInButton(label: 'Sign up with Google'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: AuthField(controller: _first, label: 'First name')),
              const SizedBox(width: 10),
              Expanded(child: AuthField(controller: _last, label: 'Last name')),
            ],
          ),
          const SizedBox(height: 12),
          AuthField(controller: _email, label: 'Email', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          AuthField(controller: _phone, label: 'Phone (optional)', keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          AuthField(controller: _password, label: 'Password', obscure: true),
          const SizedBox(height: 12),
          AuthField(controller: _confirm, label: 'Confirm password', obscure: true),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _agree,
            onChanged: (value) => setState(() => _agree = value ?? false),
            title: const Text('I agree to the Terms and Privacy Policy'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          AppButton(label: 'Create account', loading: _busy, onPressed: _busy ? null : _submit),
        ],
      ),
    );
  }
}
