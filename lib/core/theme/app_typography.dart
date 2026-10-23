import 'package:flutter/material.dart';

import 'package:pickorbeet/core/theme/app_pallete.dart';

/// Type ramp measured from the designs at the 411 dp reference width.
///
/// Every style is Inter. Inter has no `৳`, so Noto Sans Bengali is the fallback.
abstract final class AppTypography {
  static const family = 'Inter';
  static const displayFamily = 'InterDisplay';
  static const fallback = <String>['NotoSansBengali'];

  static const _base = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    color: AppPallete.ink,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The "PickOrbeet" wordmark: Inter Display Bold tracked in by 4%, fitted to the designs.
  static TextStyle wordmarkOf(double size) => TextStyle(
        fontFamily: displayFamily,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: size * -0.04,
        height: 1,
        leadingDistribution: TextLeadingDistribution.even,
      );

  static final wordmark = wordmarkOf(19.65);

  static final display = _base.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.35,
    height: 1.2,
  );

  static final titleLarge = _base.copyWith(
    fontSize: 19.5,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static final titleMedium = _base.copyWith(
    fontSize: 14.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.15,
    height: 1.25,
  );

  static final titleSmall = _base.copyWith(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.3,
  );

  static final bodyLarge = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static final bodyMedium = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static final bodySmall = _base.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AppPallete.textSecondary,
  );

  static final label = _base.copyWith(
    fontSize: 10.75,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static final labelSmall = _base.copyWith(
    fontSize: 9.4,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static final caption = _base.copyWith(
    fontSize: 8.75,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppPallete.textSecondary,
  );

  static final button = _base.copyWith(
    fontSize: 12.75,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppPallete.onDark,
  );

  static final price = _base.copyWith(
    fontSize: 15.5,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1.1,
    color: AppPallete.primaryText,
  );

  static final priceSmall = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    height: 1.1,
    color: AppPallete.primaryText,
  );

  static final strike = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.1,
    color: AppPallete.textTertiary,
    decoration: TextDecoration.lineThrough,
    decorationColor: AppPallete.textTertiary,
  );

  static TextTheme textTheme() => TextTheme(
        displaySmall: display,
        headlineSmall: titleLarge,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: button,
        labelMedium: label,
        labelSmall: caption,
      );
}
