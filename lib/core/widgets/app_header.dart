import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/widgets/brand_lockup.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';
import 'package:pickorbeet/core/widgets/header_background.dart';
import 'package:pickorbeet/core/widgets/search_pill.dart';

/// Home header: logo, search pill, and menu, on a square-cornered gradient.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.onMenu});

  final VoidCallback onMenu;

  /// Height below the status bar.
  static const contentHeight = 48.9;

  static double heightOf(BuildContext context) => MediaQuery.paddingOf(context).top + contentHeight;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnDark,
      child: HeaderBackground(
        child: SizedBox(
          height: top + contentHeight,
          child: Padding(
            padding: EdgeInsets.only(top: top + 3, left: 16.1, right: 11.6),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 34.2,
                child: Row(
                  children: [
                    Pressable(
                      pressedScale: 0.97,
                      semanticLabel: 'PickOrbeet home',
                      onTap: () => context.go(Routes.home),
                      child: const BrandLockup.compact(),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 188.2,
                      child: SearchPill.compact(onTap: () => context.push(Routes.search)),
                    ),
                    const SizedBox(width: 10),
                    _MenuButton(onTap: onMenu),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'Menu',
      onTap: onTap,
      child: Container(
        width: 34.2,
        height: 34.2,
        decoration: const BoxDecoration(color: AppPallete.headerButton, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const CustomPaint(size: Size(11.73, 9.77), painter: _MenuGlyphPainter()),
      ),
    );
  }
}

/// Three rounded bars; the middle one starts with a short dash, as in the design.
class _MenuGlyphPainter extends CustomPainter {
  const _MenuGlyphPainter();

  static const _stroke = 1.71;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppPallete.onDark
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    const half = _stroke / 2;
    final right = size.width - half;
    final middle = size.height / 2;
    canvas
      ..drawLine(const Offset(half, half), Offset(right, half), paint)
      ..drawLine(const Offset(half, 0) + Offset(0, middle), Offset(half + 0.2, middle), paint)
      ..drawLine(Offset(half + 2.69, middle), Offset(right, middle), paint)
      ..drawLine(Offset(half, size.height - half), Offset(right, size.height - half), paint);
  }

  @override
  bool shouldRepaint(_MenuGlyphPainter oldDelegate) => false;
}

/// Tab header: logo with bell and cart, then a full-width search bar, on a gradient with rounded
/// lower corners.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, this.showBell = true, this.showSearch = true});

  final bool showBell;
  final bool showSearch;

  static const contentHeight = 81.6;
  static const compactHeight = 41.2;

  /// The logo row is a full touch target tall, so it starts above the status bar's lower edge to
  /// keep the wordmark where the design puts it.
  static const _rowHeight = 44.0;
  static const _rowRise = 5.15;

  static double heightOf(BuildContext context, {bool showSearch = true}) =>
      MediaQuery.paddingOf(context).top + (showSearch ? contentHeight : compactHeight);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnDark,
      child: HeaderBackground(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
        child: SizedBox(
          height: top + (showSearch ? contentHeight : compactHeight),
          child: Padding(
            padding: EdgeInsets.only(top: top - _rowRise),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _rowHeight,
                  child: Row(
                    children: [
                      const SizedBox(width: 15.2),
                      Pressable(
                        pressedScale: 0.97,
                        semanticLabel: 'PickOrbeet home',
                        onTap: () => context.go(Routes.home),
                        child: const BrandLockup(),
                      ),
                      const Spacer(),
                      if (showBell) ...const [
                        HeaderBellButton(),
                        SizedBox(width: 0.7),
                        HeaderDivider(),
                        SizedBox(width: 1.9),
                      ],
                      const HeaderCartButton(),
                      const SizedBox(width: 12.9),
                    ],
                  ),
                ),
                if (showSearch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15.6, 0.15, 15.6, 0),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SearchPill(onTap: () => context.push(Routes.search)),
                        const Positioned(top: -3.8, left: 0, right: 0, child: _RimLight()),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The short streak of light catching the search pill's top edge.
class _RimLight extends StatelessWidget {
  const _RimLight();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(-0.05, 0),
        child: Container(
          width: 31,
          height: 1.4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            gradient: LinearGradient(
              colors: [
                AppPallete.headerRimLight.withValues(alpha: 0),
                AppPallete.headerRimLight.withValues(alpha: 0.85),
                AppPallete.headerRimLight.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Detail header: back, centred logo, and cart.
class DetailHeader extends StatelessWidget {
  const DetailHeader({super.key, this.onBack, this.trailing});

  final VoidCallback? onBack;
  final Widget? trailing;

  static const contentHeight = 50.0;

  static double heightOf(BuildContext context) => MediaQuery.paddingOf(context).top + contentHeight;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnDark,
      child: HeaderBackground(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: SizedBox(
          height: top + contentHeight,
          child: Padding(
            padding: EdgeInsets.only(top: top, left: 6, right: 8),
            child: Row(
              children: [
                HeaderBackButton(onPressed: onBack),
                const Spacer(),
                const BrandLockup(markSize: Size(31, 32), wordmarkSize: 20),
                const Spacer(),
                trailing ?? const HeaderCartButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
