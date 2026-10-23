import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/auth/google_auth_config.dart';
import 'package:pickorbeet/features/auth/repositories/auth_remote_repository.dart';

/// Starts Google sign-in and stores the session the API returns.
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key, this.label = 'Continue with Google', this.next = Routes.account});

  final String label;
  final String next;

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  var _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      final google = GoogleSignIn(scopes: const ['email'], serverClientId: GoogleAuthConfig.clientId);
      final account = await google.signIn();
      final token = (await account?.authentication)?.idToken;
      if (!mounted) return;
      if (token == null) {
        showToast(context, 'Google sign-in was cancelled.', kind: ToastKind.error);
        return;
      }
      final result = await ref.read(authRemoteRepositoryProvider).google(token);
      if (!mounted) return;
      await result.fold(
        (failure) async => showToast(context, failure.message, kind: ToastKind.error),
        (session) async {
          await ref.read(sessionNotifierProvider.notifier).signIn(session);
          if (!mounted) return;
          context.go(widget.next);
        },
      );
    } on Object catch (error) {
      if (mounted) showToast(context, 'Google sign-in failed. $error', kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _busy ? null : _signIn,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6ECF6)),
            boxShadow: const [BoxShadow(color: Color(0x1214289A), blurRadius: 14, offset: Offset(0, 6))],
          ),
          child: Center(
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppPallete.primary),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _GoogleMark(),
                      const SizedBox(width: 10),
                      Text(
                        widget.label,
                        style: AppTypography.label.copyWith(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF10204A)),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas
      ..drawArc(rect, -0.4, 1.9, false, paint..color = const Color(0xFF4285F4))
      ..drawArc(rect, 1.5, 1.15, false, paint..color = const Color(0xFF34A853))
      ..drawArc(rect, 2.65, 1.05, false, paint..color = const Color(0xFFFBBC05))
      ..drawArc(rect, 3.7, 1.2, false, paint..color = const Color(0xFFEA4335));
    final bar = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset(size.width * 0.52, size.height / 2), Offset(size.width - stroke / 2, size.height / 2), bar);
  }

  @override
  bool shouldRepaint(covariant _GoogleMarkPainter oldDelegate) => false;
}
