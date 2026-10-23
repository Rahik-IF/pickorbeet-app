import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';
import 'package:pickorbeet/core/widgets/nav_glyphs.dart';

/// One tab. [dx] and [dy] put each glyph's ink centre where the designs draw it, since glyphs
/// don't all sit centred in their em box.
class _Tab {
  const _Tab(this.label, this.glyph, {this.dx = 0, this.dy = 0});

  final String label;
  final Widget Function(bool active, Color color) glyph;
  final double dx;
  final double dy;
}

Widget _phosphor(IconData outline, IconData filled, double size, bool active, Color color) =>
    Icon(active ? filled : outline, size: size, color: color);

final _tabs = <_Tab>[
  _Tab(
    'Home',
    (active, color) => active
        ? HomeActiveGlyph(color: color)
        : Icon(PhosphorIconsRegular.house, size: 21.3, color: color),
    dy: 0.15,
  ),
  _Tab(
    'Categories',
    (active, color) => active
        ? CategoriesActiveGlyph(color: color)
        : Icon(PhosphorIconsRegular.squaresFour, size: 23.5, color: color),
    dy: 0.3,
  ),
  _Tab(
    'Wishlist',
    (active, color) => _phosphor(PhosphorIconsRegular.heart, PhosphorIconsFill.heart, 20.8, active, color),
    dy: -0.55,
  ),
  _Tab('Account', (active, color) => AccountGlyph(color: color, filled: active), dy: -0.2),
  _Tab(
    'Cart',
    (active, color) => _phosphor(
      PhosphorIconsRegular.shoppingCartSimple,
      PhosphorIconsFill.shoppingCartSimple,
      20.4,
      active,
      color,
    ),
    dx: 1,
    dy: 0.1,
  ),
];

/// Five-tab bar: outline glyphs fill in when active, and an indicator slides under the label.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex, required this.onSelect, required this.cartCount});

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final int cartCount;

  /// From the bar's top edge to the bottom of the indicator.
  static const contentHeight = 46.0;
  static const _sidePadding = 4.4;
  static const _indicatorTop = 44.0;
  static const _indicatorSize = Size(17.6, 2.2);

  static double heightOf(BuildContext context) =>
      math.max(42 + MediaQuery.paddingOf(context).bottom, contentHeight + 8);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPallete.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: AppPallete.shadow.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, -6)),
        ],
      ),
      child: SizedBox(
        height: heightOf(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / _tabs.length;
              return Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < _tabs.length; i++)
                        SizedBox(
                          width: tabWidth,
                          child: _NavItem(
                            tab: _tabs[i],
                            active: i == currentIndex,
                            badge: i == _tabs.length - 1 ? cartCount : 0,
                            onTap: () {
                              if (i != currentIndex) HapticFeedback.selectionClick();
                              onSelect(i);
                            },
                          ),
                        ),
                    ],
                  ),
                  AnimatedPositioned(
                    duration: Motion.of(context, Motion.medium),
                    curve: Motion.emphasized,
                    top: _indicatorTop,
                    left: tabWidth * currentIndex + (tabWidth - _indicatorSize.width) / 2,
                    child: IgnorePointer(
                      child: Container(
                        width: _indicatorSize.width,
                        height: _indicatorSize.height,
                        decoration: const BoxDecoration(
                          color: AppPallete.primary,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.active, required this.badge, required this.onTap});

  final _Tab tab;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  static const _iconCenter = 16.8;
  static const _labelTop = 29.4;
  static const _badgeCenter = Offset(13.9, 10.3);
  static const _badgeSize = 13.2;

  static final _label = AppTypography.labelSmall.copyWith(
    fontSize: 8.1,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    final color = active ? AppPallete.primary : AppPallete.navInactive;
    final duration = Motion.of(context, Motion.short);
    return Semantics(
      selected: active,
      button: true,
      label: badge > 0 ? '${tab.label}, $badge items' : tab.label,
      excludeSemantics: true,
      child: Pressable(
        pressedScale: 0.9,
        onTap: onTap,
        child: SizedBox(
          height: AppBottomNav.contentHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final center = constraints.maxWidth / 2;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: tab.dx,
                    right: -tab.dx,
                    top: _iconCenter + tab.dy - 15,
                    height: 30,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: duration,
                        switchInCurve: Curves.easeOutBack,
                        transitionBuilder: (child, animation) => ScaleTransition(
                          scale: Tween(begin: 0.7, end: 1.0).animate(animation),
                          child: FadeTransition(opacity: animation, child: child),
                        ),
                        child: KeyedSubtree(key: ValueKey(active), child: tab.glyph(active, color)),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _labelTop,
                    child: AnimatedDefaultTextStyle(
                      duration: duration,
                      style: _label.copyWith(
                        color: color,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        fontSize: active ? 7.9 : 8.1,
                      ),
                      child: Text(tab.label, maxLines: 1, textAlign: TextAlign.center, textScaler: TextScaler.noScaling),
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      left: center + _badgeCenter.dx - _badgeSize / 2,
                      top: _badgeCenter.dy - _badgeSize / 2,
                      child: CountBadge(count: badge),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
