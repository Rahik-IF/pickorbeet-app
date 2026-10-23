import 'package:flutter/material.dart';

import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_spacing.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';

enum AppButtonVariant { accent, primary, outline, soft, ghost, danger }

/// Spring-pressed button. While [loading], the label cross-fades to a spinner and taps are ignored.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.accent,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
    this.height = 44,
    this.radius = AppRadii.lg,
    this.textStyle,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expand;
  final double height;
  final double radius;
  final TextStyle? textStyle;

  bool get _enabled => onPressed != null && !loading;

  ({Color background, Color foreground, Color? border, List<BoxShadow>? shadow}) get _colors => switch (variant) {
        AppButtonVariant.accent => (
            background: AppPallete.accent,
            foreground: AppPallete.onDark,
            border: null,
            shadow: AppShadows.accentGlow,
          ),
        AppButtonVariant.primary => (
            background: AppPallete.primary,
            foreground: AppPallete.onDark,
            border: null,
            shadow: AppShadows.primaryGlow,
          ),
        AppButtonVariant.outline => (
            background: AppPallete.surface,
            foreground: AppPallete.primaryText,
            border: AppPallete.primary.withValues(alpha: 0.35),
            shadow: null,
          ),
        AppButtonVariant.soft => (
            background: AppPallete.primarySoft,
            foreground: AppPallete.primaryText,
            border: null,
            shadow: null,
          ),
        AppButtonVariant.ghost => (
            background: Colors.transparent,
            foreground: AppPallete.primaryText,
            border: null,
            shadow: null,
          ),
        AppButtonVariant.danger => (
            background: AppPallete.dangerSoft,
            foreground: AppPallete.danger,
            border: null,
            shadow: null,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    final style = (textStyle ?? AppTypography.button).copyWith(color: colors.foreground);
    final duration = Motion.of(context, Motion.short);

    final content = AnimatedSwitcher(
      duration: duration,
      switchInCurve: Motion.emphasizedDecelerate,
      switchOutCurve: Motion.emphasizedAccelerate,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(animation), child: child),
      ),
      child: loading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: colors.foreground),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 17, color: colors.foreground), const SizedBox(width: 7)],
                Flexible(
                  child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 7),
                  Icon(trailingIcon, size: 16, color: colors.foreground),
                ],
              ],
            ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: loading ? '$label, loading' : label,
      excludeSemantics: true,
      child: Pressable(
        enabled: _enabled,
        pressedScale: 0.97,
        onTap: onPressed,
        child: AnimatedOpacity(
          duration: duration,
          opacity: onPressed == null ? 0.5 : 1,
          child: AnimatedContainer(
            duration: duration,
            height: height,
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(radius),
              border: colors.border == null ? null : Border.all(color: colors.border!),
              boxShadow: _enabled ? colors.shadow : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Small square icon button with a tinted background.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 36,
    this.iconSize = 18,
    this.color = AppPallete.ink,
    this.background = AppPallete.surface,
    this.radius = AppRadii.lg,
    this.border,
    this.shadow,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final double iconSize;
  final Color color;
  final Color background;
  final double radius;
  final Color? border;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: semanticLabel,
      enabled: onPressed != null,
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius),
          border: border == null ? null : Border.all(color: border!),
          boxShadow: shadow,
        ),
        child: Icon(icon, size: iconSize, color: color),
      ),
    );
  }
}
