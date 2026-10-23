import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/auth/repositories/auth_remote_repository.dart';
import 'package:pickorbeet/features/auth/view/widgets/auth_scaffold.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  final _boxes = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());
  var _busy = false;
  var _seconds = 0;

  @override
  void dispose() {
    for (final box in _boxes) {
      box.dispose();
    }
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _code => _boxes.map((box) => box.text).join();

  Future<void> _verify([String? code]) async {
    final value = code ?? _code;
    if (value.length != 6 || widget.email.isEmpty) return;
    setState(() => _busy = true);
    final result = await ref.read(authRemoteRepositoryProvider).verifyEmail(email: widget.email, code: value);
    if (!mounted) return;
    setState(() => _busy = false);
    await result.fold(
      (failure) async {
        showToast(context, failure.message, kind: ToastKind.error);
        for (final box in _boxes) {
          box.clear();
        }
        _nodes.first.requestFocus();
      },
      (session) async {
        await ref.read(sessionNotifierProvider.notifier).signIn(session);
        if (!mounted) return;
        context.go(Routes.account);
      },
    );
  }

  Future<void> _resend() async {
    if (_seconds > 0) return;
    final result = await ref.read(authRemoteRepositoryProvider).resendVerification(widget.email);
    if (!mounted) return;
    result.fold(
      (failure) => showToast(context, failure.message, kind: ToastKind.error),
      (message) {
        showToast(context, message, kind: ToastKind.success);
        setState(() => _seconds = 60);
        _tick();
      },
    );
  }

  Future<void> _tick() async {
    while (mounted && _seconds > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _seconds -= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Check your email',
      subtitle: widget.email.isEmpty
          ? 'Open the verification link from your email.'
          : 'Enter the 6-digit code sent to ${widget.email}.',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 6; i++)
                SizedBox(
                  width: 46,
                  child: TextField(
                    controller: _boxes[i],
                    focusNode: _nodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF7F9FD),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && i < 5) _nodes[i + 1].requestFocus();
                      if (_code.length == 6) _verify(_code);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          AppButton(label: 'Verify email', loading: _busy, onPressed: _busy ? null : _verify),
          TextButton(
            onPressed: _seconds > 0 ? null : _resend,
            child: Text(_seconds > 0 ? 'Resend in ${_seconds}s' : 'Resend code'),
          ),
          if (widget.email.isEmpty)
            const Text(
              'The code email can only arrive after outbound mail is open.',
              style: TextStyle(color: AppPallete.textSecondary, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
