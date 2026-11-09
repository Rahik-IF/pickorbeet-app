import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/core/widgets/app_header.dart';
import 'package:pickorbeet/core/widgets/brand_lockup.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';
import 'package:pickorbeet/core/widgets/header_background.dart';
import 'package:pickorbeet/features/account/security/security_repository.dart';
import 'package:pickorbeet/features/auth/models/auth_session.dart';

class SecurityTone {
  const SecurityTone({
    required this.dark,
    required this.page,
    required this.card,
    required this.ink,
    required this.hint,
    required this.meta,
    required this.divider,
    required this.chevron,
  });

  final bool dark;
  final Color page;
  final Color card;
  final Color ink;
  final Color hint;
  final Color meta;
  final Color divider;
  final Color chevron;

  factory SecurityTone.of(bool dark) => dark ? _dark : _light;

  static const _light = SecurityTone(
    dark: false,
    page: Color(0xFFF4F7FE),
    card: Colors.white,
    ink: Color(0xFF0C1440),
    hint: Color(0xFF9AA3B8),
    meta: Color(0xFF8B93A6),
    divider: Color(0xFFEEF1F6),
    chevron: Color(0xFFC5CDD8),
  );

  static const _dark = SecurityTone(
    dark: true,
    page: Color(0xFF0E1628),
    card: Color(0xFF172238),
    ink: Color(0xFFF4F7FF),
    hint: Color(0xFF8E99B3),
    meta: Color(0xFFA3AEC6),
    divider: Color(0xFF2C3850),
    chevron: Color(0xFF8B97B0),
  );
}

class SecurityHeader extends StatelessWidget {
  const SecurityHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnDark,
      child: HeaderBackground(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        child: Padding(
          padding: EdgeInsets.only(top: top, bottom: 18),
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    HeaderBackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/account/settings')),
                    const BrandLockup(markSize: Size(28, 30), wordmarkSize: 18.2, gap: 5.5, markLift: 0.4),
                    const Spacer(),
                    const HeaderBellButton(),
                    const SizedBox(width: 1),
                    const HeaderDivider(),
                    const SizedBox(width: 1),
                    const HeaderCartButton(),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 2, 12, 0),
                child: Row(
                  children: [
                    Expanded(child: _HeaderCopy()),
                    SizedBox(width: 8),
                    SecurityShield(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security & Password',
          style: AppTypography.titleLarge.copyWith(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Keep your account safe and secure\nwith modern protection.',
          style: AppTypography.bodySmall.copyWith(
            color: Colors.white.withValues(alpha: 0.86),
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class SecurityShield extends StatelessWidget {
  const SecurityShield({super.key, this.size = 92});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShieldPainter(),
        child: Center(
          child: Icon(PhosphorIconsFill.lockKey, color: Colors.white, size: size * 0.28),
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shield = Path()
      ..moveTo(size.width * 0.50, size.height * 0.08)
      ..lineTo(size.width * 0.86, size.height * 0.22)
      ..lineTo(size.width * 0.80, size.height * 0.58)
      ..quadraticBezierTo(size.width * 0.72, size.height * 0.86, size.width * 0.50, size.height * 0.96)
      ..quadraticBezierTo(size.width * 0.28, size.height * 0.86, size.width * 0.20, size.height * 0.58)
      ..lineTo(size.width * 0.14, size.height * 0.22)
      ..close();
    canvas.drawPath(
      shield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7EB6FF), Color(0xFF1B4ED8)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    final ring = Rect.fromCircle(center: Offset(size.width * 0.62, size.height * 0.42), radius: size.width * 0.42);
    canvas.drawArc(
      ring,
      -0.8,
      2.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF8A1A),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SecuritySectionLabel extends StatelessWidget {
  const SecuritySectionLabel({super.key, required this.tone, required this.title});

  final SecurityTone tone;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(color: AppPallete.accent, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.titleSmall.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
            color: tone.ink,
          ),
        ),
      ],
    );
  }
}

class SecurityCard extends StatelessWidget {
  const SecurityCard({super.key, required this.tone, required this.child});

  final SecurityTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (tone.dark ? Colors.black : const Color(0xFF14289A)).withValues(alpha: tone.dark ? 0.28 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SecurityTile extends StatelessWidget {
  const SecurityTile({
    super.key,
    required this.tone,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final SecurityTone tone;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: onTap == null ? 1 : 0.985,
      semanticLabel: title,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tone.dark ? iconColor.withValues(alpha: 0.16) : iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.15,
                      color: tone.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(fontSize: 12, height: 1.3, color: tone.meta),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ?? Icon(PhosphorIconsBold.caretRight, size: 14, color: tone.chevron),
          ],
        ),
      ),
    );
  }
}

class SecuritySwitch extends StatelessWidget {
  const SecuritySwitch({super.key, required this.value, required this.dark, this.onChanged});

  final bool value;
  final bool dark;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, const Duration(milliseconds: 240));
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: duration,
          curve: Motion.emphasized,
          width: 46,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? const Color(0xFFFF7E14) : (dark ? const Color(0xFF3A445C) : const Color(0xFFE3E6EE)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedAlign(
            duration: duration,
            curve: Motion.emphasizedDecelerate,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}

class OtpBoxes extends StatefulWidget {
  const OtpBoxes({super.key, required this.onChanged, required this.onCompleted});

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;

  @override
  State<OtpBoxes> createState() => OtpBoxesState();
}

class OtpBoxesState extends State<OtpBoxes> {
  final _boxes = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());

  String get code => _boxes.map((box) => box.text).join();

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

  void clear() {
    for (final box in _boxes) {
      box.clear();
    }
    _nodes.first.requestFocus();
    widget.onChanged('');
  }

  void _apply(String raw, {int start = 0}) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    for (var offset = 0; offset < digits.length && start + offset < 6; offset++) {
      _boxes[start + offset].text = digits[offset];
    }
    final filled = code.length;
    _nodes[filled >= 6 ? 5 : filled].requestFocus();
    widget.onChanged(code);
    if (filled >= 6) widget.onCompleted(code);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 6; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _boxes[i],
              focusNode: _nodes[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: i == 5 ? TextInputAction.done : TextInputAction.next,
              maxLength: 1,
              style: AppTypography.titleMedium.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF7F9FE),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE3E8F4))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE3E8F4))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppPallete.primary, width: 1.4)),
              ),
              onChanged: (value) {
                if (value.length > 1) {
                  _apply(value, start: i);
                  return;
                }
                if (value.isEmpty && i > 0) _nodes[i - 1].requestFocus();
                if (value.isNotEmpty && i < 5) _nodes[i + 1].requestFocus();
                widget.onChanged(code);
                if (code.length == 6) widget.onCompleted(code);
              },
            ),
          ),
        ],
      ],
    );
  }
}

Future<bool> showSecurityCodeSheet({
  required BuildContext context,
  required SecurityTone tone,
  required String title,
  required String emailHint,
  required String challenge,
  required Future<String?> Function(String code) onSubmit,
  required SecurityRepository repository,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tone.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (context) => _CodeSheet(
      tone: tone,
      title: title,
      emailHint: emailHint,
      challenge: challenge,
      onSubmit: onSubmit,
      repository: repository,
    ),
  ).then((value) => value == true);
}

class _CodeSheet extends StatefulWidget {
  const _CodeSheet({
    required this.tone,
    required this.title,
    required this.emailHint,
    required this.challenge,
    required this.onSubmit,
    required this.repository,
  });

  final SecurityTone tone;
  final String title;
  final String emailHint;
  final String challenge;
  final Future<String?> Function(String code) onSubmit;
  final SecurityRepository repository;

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final _boxes = GlobalKey<OtpBoxesState>();
  var _code = '';
  var _busy = false;
  var _error = '';
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

  Future<void> _submit(String code) async {
    if (_busy || code.length != 6) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final error = await widget.onSubmit(code);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
    _boxes.currentState?.clear();
  }

  Future<void> _resend() async {
    if (_seconds > 0 || _busy) return;
    setState(() => _busy = true);
    final result = await widget.repository.resend(widget.challenge);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => setState(() => _error = failure.message),
      (_) => setState(() {
        _seconds = 60;
        _error = '';
      }),
    );
    if (_seconds == 60) unawaited(_tick());
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: widget.tone.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.title, style: AppTypography.titleMedium.copyWith(fontSize: 18, fontWeight: FontWeight.w800, color: widget.tone.ink)),
          const SizedBox(height: 6),
          Text(
            'Enter the 6-digit code sent to ${widget.emailHint}.',
            style: AppTypography.bodySmall.copyWith(color: widget.tone.meta, height: 1.35),
          ),
          const SizedBox(height: 16),
          OtpBoxes(
            key: _boxes,
            onChanged: (value) => _code = value,
            onCompleted: _submit,
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_error, style: AppTypography.bodySmall.copyWith(color: const Color(0xFFE23B35))),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _seconds == 0 && !_busy ? _resend : null,
              child: Text(_seconds == 0 ? 'Resend code' : 'Resend code in ${_seconds}s'),
            ),
          ),
          const SizedBox(height: 4),
          AppButton(label: 'Confirm', loading: _busy, onPressed: _busy ? null : () => _submit(_code)),
        ],
      ),
    );
  }
}

Future<String?> showPasswordPrompt({
  required BuildContext context,
  required SecurityTone tone,
  required String title,
  required String message,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tone.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (context) => _PasswordSheet(tone: tone, title: title, message: message),
  );
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({required this.tone, required this.title, required this.message});

  final SecurityTone tone;
  final String title;
  final String message;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _password = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: widget.tone.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.title, style: AppTypography.titleMedium.copyWith(fontSize: 18, fontWeight: FontWeight.w800, color: widget.tone.ink)),
          const SizedBox(height: 6),
          Text(widget.message, style: AppTypography.bodySmall.copyWith(color: widget.tone.meta, height: 1.35)),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Continue',
            onPressed: () => Navigator.pop(context, _password.text),
          ),
        ],
      ),
    );
  }
}

class SecuritySubpage extends StatelessWidget {
  const SecuritySubpage({super.key, required this.tone, required this.title, required this.child});

  final SecurityTone tone;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: tone.page,
      child: Column(
        children: [
          const DetailHeader(),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.fromLTRB(16, 18, 16, 28 + MediaQuery.viewInsetsOf(context).bottom),
              children: [
                Text(
                  title,
                  style: AppTypography.titleLarge.copyWith(fontSize: 22, fontWeight: FontWeight.w800, color: tone.ink, letterSpacing: -0.3),
                ),
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared by the login challenge and the security sheets.
Future<void> finishCredentialSignIn(
  WidgetRef ref,
  BuildContext context,
  CredentialResult result, {
  required String next,
}) async {
  switch (result) {
    case SignedIn(:final session):
      await completeSignIn(ref, session);
      if (!context.mounted) return;
      context.go(next);
    case TwoFactorChallenge(:final challenge, :final emailHint):
      if (!context.mounted) return;
      unawaited(
        context.push(
          Routes.twoFactor,
          extra: TwoFactorLoginArgs(challenge: challenge, emailHint: emailHint, next: next),
        ),
      );
  }
}

@immutable
class TwoFactorLoginArgs {
  const TwoFactorLoginArgs({required this.challenge, required this.emailHint, required this.next});

  final String challenge;
  final String emailHint;
  final String next;
}
