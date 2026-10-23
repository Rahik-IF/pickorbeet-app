import 'package:flutter/material.dart';

import 'package:pickorbeet/core/theme/app_pallete.dart';

/// Spacing measured from the designs (1 dp is about 2.05 px at 411 dp).
abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 10.0;
  static const xl = 12.0;
  static const xxl = 16.0;
  static const xxxl = 20.0;
  static const huge = 24.0;

  /// Horizontal page margin: cards start 26 px from the screen edge.
  static const page = 12.5;
  static const sectionGap = 12.0;
  static const cardPadding = 12.0;
  static const gridGap = 10.0;

  static const pagePadding = EdgeInsets.symmetric(horizontal: page);

  /// Smallest comfortable touch target.
  static const minTouch = 44.0;
}

abstract final class AppRadii {
  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 7.0;
  static const card = 9.0;
  static const lg = 10.0;
  static const xl = 12.0;
  static const xxl = 16.0;
  static const sheet = 20.0;
  static const pill = 999.0;

  static const cardBorder = BorderRadius.all(Radius.circular(card));
  static const cardSmBorder = BorderRadius.all(Radius.circular(md));
  static const lgBorder = BorderRadius.all(Radius.circular(lg));
  static const xlBorder = BorderRadius.all(Radius.circular(xl));
  static const pillBorder = BorderRadius.all(Radius.circular(pill));
  static const sheetBorder = BorderRadius.vertical(top: Radius.circular(sheet));
}

abstract final class AppShadows {
  static final card = <BoxShadow>[
    BoxShadow(
      color: AppPallete.shadow.withValues(alpha: 0.055),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static final soft = <BoxShadow>[
    BoxShadow(
      color: AppPallete.shadow.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];

  static final floating = <BoxShadow>[
    BoxShadow(
      color: AppPallete.shadow.withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static final accentGlow = <BoxShadow>[
    BoxShadow(
      color: AppPallete.shadowAccent.withValues(alpha: 0.28),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static final primaryGlow = <BoxShadow>[
    BoxShadow(
      color: AppPallete.primary.withValues(alpha: 0.24),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static final navBar = <BoxShadow>[
    BoxShadow(
      color: AppPallete.shadow.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ];
}
