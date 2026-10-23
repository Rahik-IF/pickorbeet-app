import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';

enum ToastKind { info, success, error }

/// Floating snackbar with an icon. Replaces any toast that is already showing.
void showToast(
  BuildContext context,
  String message, {
  ToastKind kind = ToastKind.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final (icon, color) = switch (kind) {
    ToastKind.info => (PhosphorIconsFill.info, AppPallete.onDark),
    ToastKind.success => (PhosphorIconsFill.checkCircle, const Color(0xFF4ADE80)),
    ToastKind.error => (PhosphorIconsFill.warningCircle, const Color(0xFFFF7A8A)),
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        content: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMedium.copyWith(color: AppPallete.onDark, fontSize: 12),
              ),
            ),
          ],
        ),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, textColor: AppPallete.accent, onPressed: onAction ?? () {}),
      ),
    );
}
