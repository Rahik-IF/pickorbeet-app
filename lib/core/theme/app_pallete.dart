import 'package:flutter/material.dart';

/// Colors sampled from the designs in `design-template/`.
abstract final class AppPallete {
  // Brand
  static const primary = Color(0xFF0040EE);
  static const primaryText = Color(0xFF0233E6);
  static const primaryStrong = Color(0xFF0A52DC);
  static const primarySoft = Color(0xFFEDF3FE);
  static const accent = Color(0xFFFE7818);
  static const accentDeep = Color(0xFFF26A00);
  static const accentSoft = Color(0xFFFEF2E6);
  static const wordmarkOrange = Color(0xFFFF7D16);

  // Header gradient (top-left to bottom-right, with a glow bottom-right)
  static const headerStart = Color(0xFF0035A9);
  static const headerMid = Color(0xFF012783);
  static const headerEnd = Color(0xFF01226F);
  static const headerGlow = Color(0xFF0636A0);
  static const headerButton = Color(0xFF1B40A7);
  static const headerDivider = Color(0x2E286EFF);
  static const headerRimLight = Color(0xFF1E63E6);

  // Surfaces
  static const background = Color(0xFFF3F7FE);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF2F6FE);
  static const searchFill = Color(0xFFECF1FB);
  static const searchIcon = Color(0xFF001162);
  static const searchHint = Color(0xFF7781AB);
  static const divider = Color(0xFFE8ECF5);
  static const border = Color(0xFFE2E8F4);
  static const skeleton = Color(0xFFE6EBF5);

  // Home and catalog
  static const productTile = Color(0xFFF3F5FB);
  static const heartIdle = Color(0xFF424D63);
  static const viewAll = Color(0xFF0022CC);
  static const dotInactive = Color(0xFFD6DCEC);
  static const carouselArrow = Color(0xFF010F77);
  static const benefitIcon = Color(0xFF002EE8);
  static const benefitCircle = Color(0xFFEAF0FE);
  static const benefitSubtitle = Color(0xFF536072);

  // Text
  static const ink = Color(0xFF051340);
  static const inkSoft = Color(0xFF1C2448);
  static const textSecondary = Color(0xFF6A7390);
  static const textTertiary = Color(0xFF7880A1);
  static const textHint = Color(0xFF8C93AD);
  static const navInactive = Color(0xFF666D7E);
  static const onDark = Color(0xFFFFFFFF);

  // Feedback
  static const sale = Color(0xFFFC3D55);
  static const saleSoft = Color(0xFFFC586C);
  static const danger = Color(0xFFF0142C);
  static const dangerSoft = Color(0xFFFDEFF5);
  static const success = Color(0xFF06892E);
  static const successSoft = Color(0xFFE6F6EC);
  static const star = Color(0xFFF99B05);
  static const warning = Color(0xFFEA6C04);

  // Shadows
  static const shadow = Color(0xFF14289A);
  static const shadowAccent = Color(0xFFFE7818);
}

/// Foreground, background and border for one courier status group.
@immutable
class StatusPalette {
  const StatusPalette({
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
  });

  final Color foreground;
  final Color background;
  final Color border;
  final Color icon;
}

/// The courier status palettes shown on the order screen.
abstract final class CourierPalette {
  static const inReview = StatusPalette(
    foreground: Color(0xFFEA6C04),
    background: Color(0xFFFEF0E1),
    border: Color(0xFFFCD8B6),
    icon: Color(0xFFF07A10),
  );
  static const pending = StatusPalette(
    foreground: Color(0xFF2F6AE6),
    background: Color(0xFFEDF3FE),
    border: Color(0xFFD5E3FC),
    icon: Color(0xFF4886F4),
  );
  static const hold = StatusPalette(
    foreground: Color(0xFF7A5FD6),
    background: Color(0xFFEFEDFE),
    border: Color(0xFFDCD5FA),
    icon: Color(0xFF8F77DE),
  );
  static const delivered = StatusPalette(
    foreground: Color(0xFF0E9A55),
    background: Color(0xFFE9F8F1),
    border: Color(0xFFC9EEDC),
    icon: Color(0xFF14A961),
  );
  static const partialDelivered = StatusPalette(
    foreground: Color(0xFF0B8C99),
    background: Color(0xFFE6F7F8),
    border: Color(0xFFC4ECEF),
    icon: Color(0xFF12A3B1),
  );
  static const cancelled = StatusPalette(
    foreground: Color(0xFFD92D42),
    background: Color(0xFFFDECEF),
    border: Color(0xFFF9CED5),
    icon: Color(0xFFE5384B),
  );
  static const unknown = StatusPalette(
    foreground: Color(0xFF5C647E),
    background: Color(0xFFF1F3F8),
    border: Color(0xFFDDE1EB),
    icon: Color(0xFF79809A),
  );
}

/// Tints for the account dashboard tiles and order stats.
@immutable
class TileTint {
  const TileTint(this.background, this.icon);

  final Color background;
  final Color icon;
}

abstract final class DashboardPalette {
  static const orders = TileTint(Color(0xFFFEF4EC), Color(0xFFFC6A00));
  static const wishlist = TileTint(Color(0xFFFEEEF4), Color(0xFFF2384F));
  static const addresses = TileTint(Color(0xFFE6F2FE), Color(0xFF0038FC));
  static const payment = TileTint(Color(0xFFEEECFE), Color(0xFF3D3BE0));
  static const vouchers = TileTint(Color(0xFFE4F8F2), Color(0xFF04982A));
  static const notifications = TileTint(Color(0xFFFEF6E8), Color(0xFFFE7E00));
  static const help = TileTint(Color(0xFFEEECFE), Color(0xFF1A1FE0));
  static const settings = TileTint(Color(0xFFEAFAFE), Color(0xFF004A68));

  static const statPending = TileTint(Color(0xFFF6E8DC), Color(0xFFFC7000));
  static const statDelivered = TileTint(Color(0xFFD0E2FE), Color(0xFF0036F8));
  static const statCancelled = TileTint(Color(0xFFF6DEEA), Color(0xFFEC2A36));
  static const statReturned = TileTint(Color(0xFFCEF0EC), Color(0xFF028860));
}
