import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';

/// Icon, title, message and an optional action, for empty lists and coming-soon features.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.tint = AppPallete.primary,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color tint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: compact ? 64 : 84,
      height: compact ? 64 : 84,
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.09), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: compact ? 28 : 36, color: tint),
    );
    final animatedBadge = Motion.reduced(context)
        ? badge
        : badge
            .animate()
            .scaleXY(begin: 0.7, end: 1, duration: Motion.long, curve: Curves.easeOutBack)
            .fadeIn(duration: Motion.medium);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 16 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            animatedBadge,
            SizedBox(height: compact ? 12 : 18),
            Text(title, style: AppTypography.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                style: AppTypography.bodyLarge.copyWith(color: AppPallete.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              AppButton(label: actionLabel!, onPressed: onAction, expand: false, height: 40),
            ],
          ],
        ),
      ),
    );
  }
}

/// Failure message with a retry button. Connectivity failures get their own icon and wording.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.failure, this.onRetry, this.compact = false});

  final Object failure;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final appFailure = failure is AppFailure ? failure as AppFailure : AppFailure.fromException(failure);
    final offline = appFailure.isConnectivity;
    return EmptyState(
      icon: offline ? PhosphorIconsRegular.wifiSlash : PhosphorIconsRegular.warningCircle,
      title: offline ? 'You\u2019re offline' : 'Something went wrong',
      message: appFailure.message,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
      tint: offline ? AppPallete.textSecondary : AppPallete.danger,
      compact: compact,
    );
  }
}
