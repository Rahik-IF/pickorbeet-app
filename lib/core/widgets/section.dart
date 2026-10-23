import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_spacing.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';

/// White rounded card with the soft blue shadow used across the designs.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.margin = EdgeInsets.zero,
    this.radius = AppRadii.card,
    this.color = AppPallete.surface,
    this.border,
    this.shadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color color;
  final Color? border;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: border == null ? null : Border.all(color: border!),
          boxShadow: shadow ?? AppShadows.card,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Section title with the short orange bar on its left and an optional "View All →" link.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onViewAll,
    this.viewAllLabel = 'View All',
    this.style,
    this.viewAllStyle,
    this.barHeight = 15.64,
    this.barWidth = 2.93,
    this.gap = 7.82,
    this.height = 24,
    this.trailing,
  });

  /// Inter Bold 14.3 at -0.02 em, measured on the home section cards.
  static final titleStyle = AppTypography.titleSmall.copyWith(
    fontSize: 14.3,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.286,
    height: 1.2,
    color: AppPallete.ink,
  );

  final String title;
  final VoidCallback? onViewAll;
  final String viewAllLabel;
  final TextStyle? style;
  final TextStyle? viewAllStyle;
  final double barHeight;
  final double barWidth;
  final double gap;
  final double height;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Container(
            width: barWidth,
            height: barHeight,
            decoration: BoxDecoration(color: AppPallete.accent, borderRadius: BorderRadius.circular(barWidth)),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: style ?? titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          if (trailing != null) trailing!,
          if (onViewAll != null) ViewAllLink(label: viewAllLabel, onTap: onViewAll!, style: viewAllStyle),
        ],
      ),
    );
  }
}

/// Blue "View All →" link.
class ViewAllLink extends StatelessWidget {
  const ViewAllLink({super.key, required this.onTap, this.label = 'View All', this.style});

  /// Inter SemiBold 10.2 at +0.01 em.
  static final textStyle = AppTypography.label.copyWith(
    color: AppPallete.viewAll,
    fontSize: 10.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );

  final VoidCallback onTap;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = style ?? textStyle;
    return Pressable(
      pressedScale: 0.94,
      semanticLabel: label,
      onTap: onTap,
      // Widens the tap target; the vertical padding fits the 24 dp section header row.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5.5, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: resolved, textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15)),
            const SizedBox(width: 5.4),
            Icon(PhosphorIconsBold.arrowRight, size: (resolved.fontSize ?? 10.2) * 0.98, color: resolved.color),
          ],
        ),
      ),
    );
  }
}
