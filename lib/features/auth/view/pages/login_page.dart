import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/auth/repositories/auth_remote_repository.dart';
import 'package:pickorbeet/features/auth/view/widgets/auth_scaffold.dart';
import 'package:pickorbeet/features/auth/view/widgets/google_sign_in_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.from});

  final String? from;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;
  var _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _next => (widget.from != null && widget.from!.startsWith('/')) ? widget.from! : Routes.account;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final result = await ref.read(authRemoteRepositoryProvider).login(email: _email.text, password: _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    await result.fold(
      (failure) async => showToast(context, failure.message, kind: ToastKind.error),
      (session) async {
        await ref.read(sessionNotifierProvider.notifier).signIn(session);
        if (!mounted) return;
        context.go(_next);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to track orders, save addresses, and check out faster.',
      footer: TextButton(
        onPressed: () => context.push(Routes.register),
        child: const Text('New here? Create an account'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GoogleSignInButton(next: _next),
          const SizedBox(height: 16),
          const _OrDivider(),
          const SizedBox(height: 16),
          AuthField(controller: _email, label: 'Email', keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email]),
          const SizedBox(height: 12),
          AuthField(
            controller: _password,
            label: 'Password',
            obscure: _obscure,
            autofillHints: const [AutofillHints.password],
            suffix: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => context.push(Routes.forgotPassword), child: const Text('Forgot password?')),
          ),
          AppButton(label: 'Sign in', loading: _busy, onPressed: _busy ? null : _signIn),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('or email', style: TextStyle(color: AppPallete.textHint, fontSize: 12))),
        Expanded(child: Divider()),
      ],
    );
  }
}
