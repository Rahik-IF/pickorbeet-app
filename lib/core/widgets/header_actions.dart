import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/cart_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';

/// Number of units in the cart, or 0 while it loads.
final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartNotifierProvider.select((cart) => cart.valueOrNull?.totalItems ?? 0)),
);

/// Orange count badge that pops whenever the number changes.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, this.size = 13.2, this.borderColor});

  final int count;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    final badge = Container(
      constraints: BoxConstraints(minWidth: size, minHeight: size, maxHeight: size),
      padding: EdgeInsets.symmetric(horizontal: label.length > 1 ? size * 0.22 : 0),
      decoration: BoxDecoration(
        color: AppPallete.accent,
        borderRadius: BorderRadius.circular(size),
        border: borderColor == null ? null : Border.all(color: borderColor!, width: 1.2),
      ),
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            fontSize: size * 0.57,
            fontWeight: FontWeight.w500,
            color: AppPallete.onDark,
            height: 1,
          ),
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
    if (Motion.reduced(context)) return badge;
    return badge
        .animate(key: ValueKey(count))
        .scaleXY(begin: 0.6, end: 1, duration: Motion.long, curve: Curves.elasticOut);
  }
}

/// Header cart button with a badge; wiggles when an item is added.
class HeaderCartButton extends ConsumerWidget {
  const HeaderCartButton({super.key, this.color = AppPallete.onDark});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    return Pressable(
      semanticLabel: count == 0 ? 'Cart' : 'Cart, $count items',
      onTap: () => context.go(Routes.cart),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Transform.translate(
          offset: const Offset(0, 0.35),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _Wiggle(
                count: count,
                child: Icon(PhosphorIconsBold.shoppingCartSimple, size: 22.4, color: color),
              ),
              if (count > 0)
                Transform.translate(
                  offset: const Offset(14.4, -9.3),
                  child: CountBadge(count: count, size: 16.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hairline between the bell and the cart.
class HeaderDivider extends StatelessWidget {
  const HeaderDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 0.6,
      height: 15.2,
      child: ColoredBox(color: AppPallete.headerDivider),
    );
  }
}

/// Shakes its child when [count] goes up, not when it first appears or goes down.
class _Wiggle extends StatefulWidget {
  const _Wiggle({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  State<_Wiggle> createState() => _WiggleState();
}

class _WiggleState extends State<_Wiggle> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(_Wiggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count && !Motion.reduced(context)) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child
        .animate(controller: _controller, autoPlay: false)
        .shake(hz: 5, rotation: 0.09, offset: Offset.zero);
  }
}

/// Header bell. There is no notifications API yet, so it opens the empty notifications page.
class HeaderBellButton extends StatelessWidget {
  const HeaderBellButton({super.key, this.color = AppPallete.onDark});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'Notifications',
      onTap: () => context.push(Routes.notifications),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Transform.translate(
          offset: const Offset(0, -0.65),
          child: Icon(PhosphorIconsBold.bell, size: 21.6, color: color),
        ),
      ),
    );
  }
}

/// Circular back button for detail headers.
class HeaderBackButton extends StatelessWidget {
  const HeaderBackButton({super.key, this.onPressed, this.color = AppPallete.onDark});

  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'Back',
      onTap: onPressed ?? () => context.canPop() ? context.pop() : context.go(Routes.home),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(PhosphorIconsRegular.arrowLeft, size: 24, color: color),
      ),
    );
  }
}
