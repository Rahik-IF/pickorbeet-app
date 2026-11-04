import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
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

  void _applyDigits(String raw, {int start = 0}) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    for (var offset = 0; offset < digits.length && start + offset < 6; offset++) {
      _boxes[start + offset].text = digits[offset];
    }
    final filled = _code.length;
    final focusAt = filled >= 6 ? 5 : filled;
    _nodes[focusAt].requestFocus();
    if (filled >= 6) {
      _verify(_code);
    }
  }

  Future<void> _verify([String? code]) async {
    if (_busy) return;
    final value = (code ?? _code).trim();
    if (value.length != 6 || widget.email.isEmpty) {
      if (value.length != 6) {
        showToast(context, 'Enter the 6-digit code from your email.', kind: ToastKind.error);
      }
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(authRemoteRepositoryProvider).verifyEmail(
          email: widget.email,
          code: value,
        );
    if (!mounted) return;

    await result.fold(
      (failure) async {
        setState(() => _busy = false);
        showToast(context, failure.message, kind: ToastKind.error);
        for (final box in _boxes) {
          box.clear();
        }
        _nodes.first.requestFocus();
      },
      (session) async {
        try {
          await completeSignIn(ref, session);
        } on Object {
          // Tokens may already be saved; still leave this screen.
        }
        if (!mounted) return;
        showToast(context, 'Email verified. Welcome!', kind: ToastKind.success);
        context.go(Routes.account);
      },
    );
  }

  Future<void> _resend() async {
    if (_seconds > 0 || _busy) return;
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
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final boxWidth = ((constraints.maxWidth - gap * 5) / 6).clamp(40.0, 52.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 6; i++)
                    SizedBox(
                      width: boxWidth,
                      height: 56,
                      child: TextField(
                        controller: _boxes[i],
                        focusNode: _nodes[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        textInputAction: i == 5 ? TextInputAction.done : TextInputAction.next,
                        style: AppTypography.titleLarge.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          color: AppPallete.ink,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          // Allow a full paste into the first box; distribute in onChanged.
                          LengthLimitingTextInputFormatter(i == 0 ? 6 : 1),
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF7F9FD),
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE3E8F4)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppPallete.primary, width: 1.6),
                          ),
                        ),
                        onChanged: (value) {
                          if (i == 0 && value.length > 1) {
                            _applyDigits(value);
                            return;
                          }
                          if (value.isEmpty) {
                            if (i > 0) _nodes[i - 1].requestFocus();
                            return;
                          }
                          if (i < 5) {
                            _nodes[i + 1].requestFocus();
                          }
                          if (_code.length == 6) {
                            _verify(_code);
                          }
                        },
                        onSubmitted: (_) {
                          if (_code.length == 6) _verify(_code);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          AppButton(label: 'Verify email', loading: _busy, onPressed: _busy ? null : _verify),
          TextButton(
            onPressed: _seconds > 0 || _busy ? null : _resend,
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
