import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/cart_notifier.dart';
import 'package:pickorbeet/core/providers/wishlist_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';

/// Adds one unit to the cart, or opens the product when a size or colour must be picked first.
Future<bool> quickAddToCart(BuildContext context, WidgetRef ref, ProductSummary product) async {
  if (product.isOutOfStock) return false;
  if (product.needsVariantChoice) {
    await context.push(Routes.product(product.slug));
    return false;
  }
  unawaited(HapticFeedback.lightImpact());
  final result = await ref.read(cartNotifierProvider.notifier).add(CartLine(productId: product.id, quantity: 1));
  if (!context.mounted) return result.isRight();
  return result.fold(
    (failure) {
      showToast(context, failure.message, kind: ToastKind.error);
      return false;
    },
    (_) {
      showToast(
        context,
        'Added to cart',
        kind: ToastKind.success,
        actionLabel: 'View cart',
        onAction: () => context.go(Routes.cart),
      );
      return true;
    },
  );
}

/// Toggles the wishlist with feedback. Shared by cards and the product page.
void toggleWishlist(BuildContext context, WidgetRef ref, ProductSummary product) {
  final added = ref.read(wishlistNotifierProvider.notifier).toggle(product.id);
  HapticFeedback.selectionClick();
  if (added == null) {
    showToast(context, 'Your wishlist is full. Remove an item to add another.', kind: ToastKind.error);
  }
}

/// Hero tag for a product image, scoped so two rails showing one product don't collide.
String productHeroTag(String scope, String productId) => 'product-image-$scope-$productId';

/// The product card from the home rails. Every size derives from the 121.7 dp design width.
class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product, this.width = designWidth, this.heroScope = 'card'});

  static const designWidth = 121.7;

  /// Total height for a card of [width], so rails can size themselves without measuring.
  static double heightFor(double width, TextScaler scaler) {
    final s = width / designWidth;
    final nameLines = scaler.scale(10.4 * s) * 1.3 * 2;
    return width * 0.86 + 7 * s + nameLines + 6 * s + 25 * s + 8 * s;
  }

  final ProductSummary product;
  final double width;
  final String heroScope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = width / designWidth;
    final soldOut = product.isOutOfStock;
    final heroTag = productHeroTag(heroScope, product.id);

    return Pressable(
      pressedScale: 0.97,
      semanticLabel: '${product.name}, ${Formatters.money(product.price)}${soldOut ? ', out of stock' : ''}',
      onTap: () => context.push(Routes.product(product.slug), extra: heroTag),
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppPallete.productTile,
            borderRadius: BorderRadius.circular(10 * s),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: width * 0.86,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(10 * s, 20 * s, 10 * s, 4 * s),
                        child: Hero(
                          tag: heroTag,
                          child: _ProductImage(url: product.primaryImage, soldOut: soldOut),
                        ),
                      ),
                    ),
                    Positioned(left: 5.4 * s, top: 5.9 * s, child: ProductBadge(product: product, scale: s)),
                    Positioned(
                      right: 5.4 * s - WishlistHeart.hitSlop,
                      top: 5.4 * s - WishlistHeart.hitSlop,
                      child: WishlistHeart(product: product, diameter: 20.5 * s, iconSize: 10.5 * s),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(8 * s, 7 * s, 6 * s, 8 * s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Two lines tall even for short names, so prices line up across a rail.
                    SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(10.4 * s) * 1.3 * 2,
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 10.4 * s,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.02 * 10.4 * s,
                          height: 1.3,
                          color: AppPallete.ink,
                        ),
                      ),
                    ),
                    SizedBox(height: 6 * s),
                    SizedBox(
                      height: 25 * s,
                      child: Row(
                        children: [
                          Expanded(child: _PriceBlock(product: product, scale: s)),
                          SizedBox(width: 4 * s),
                          CardCartButton(product: product, size: 25 * s),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url, required this.soldOut});

  final String? url;
  final bool soldOut;

  @override
  Widget build(BuildContext context) {
    final image = AppNetworkImage(url: url, fit: BoxFit.contain, background: Colors.transparent);
    if (!soldOut) return image;
    return Opacity(
      opacity: 0.55,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.33, 0.59, 0.11, 0, 0, //
          0.33, 0.59, 0.11, 0, 0, //
          0.33, 0.59, 0.11, 0, 0, //
          0, 0, 0, 1, 0,
        ]),
        child: image,
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.product, required this.scale});

  final ProductSummary product;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    // Scales down as one block, so large text sizes shrink the prices instead of overflowing.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Formatters.money(product.price),
            maxLines: 1,
            style: AppTypography.price.copyWith(
              fontSize: 12 * s,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.02 * 12 * s,
              height: 1.1,
              color: AppPallete.primaryText,
            ),
          ),
          if (product.hasDiscount)
            Text(
              Formatters.money(product.comparePrice),
              maxLines: 1,
              style: AppTypography.strike.copyWith(fontSize: 8.6 * s, height: 1.1),
            ),
        ],
      ),
    );
  }
}

/// "20% OFF" in red for discounts, otherwise "Featured" in orange for featured products.
class ProductBadge extends StatelessWidget {
  const ProductBadge({super.key, required this.product, this.scale = 1});

  final ProductSummary product;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final (label, color) = switch (product) {
      ProductSummary(isOutOfStock: true) => ('Sold out', AppPallete.inkSoft),
      ProductSummary(hasDiscount: true, discountPercentage: > 0) =>
        (Formatters.discount(product.discountPercentage), AppPallete.sale),
      ProductSummary(isFeatured: true) => ('Featured', AppPallete.accent),
      _ => (null, null),
    };
    if (label == null || color == null) return const SizedBox.shrink();
    return Container(
      height: 16.6 * s,
      padding: EdgeInsets.symmetric(horizontal: 4.7 * s),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8.3 * s)),
      child: Text(
        label,
        textScaler: TextScaler.noScaling,
        style: AppTypography.labelSmall.copyWith(
          fontSize: 7.8 * s,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.02 * 7.8 * s,
          height: 1,
          color: AppPallete.onDark,
        ),
      ),
    );
  }
}

/// White circle with a heart that fills and pops when wishlisted.
class WishlistHeart extends ConsumerWidget {
  const WishlistHeart({super.key, required this.product, this.diameter = 20.5, this.iconSize = 10.5, this.shadow = false});

  final ProductSummary product;
  final double diameter;
  final double iconSize;
  final bool shadow;

  /// Invisible margin around the circle that still takes taps. Callers positioning the circle
  /// subtract it.
  static const hitSlop = 4.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(isWishlistedProvider(product.id));
    final reduced = Motion.reduced(context);
    Widget icon = Icon(
      saved ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
      key: ValueKey(saved),
      size: iconSize,
      color: saved ? AppPallete.sale : AppPallete.heartIdle,
    );
    if (saved && !reduced) {
      icon = icon
          .animate(key: ValueKey('pop-$saved'))
          .scaleXY(begin: 0.4, end: 1, duration: Motion.long, curve: Curves.elasticOut);
    }
    return Semantics(
      toggled: saved,
      child: Pressable(
        pressedScale: 0.85,
        semanticLabel: saved ? 'Remove ${product.name} from wishlist' : 'Add ${product.name} to wishlist',
        onTap: () => toggleWishlist(context, ref, product),
        child: Padding(
          padding: const EdgeInsets.all(hitSlop),
          child: Container(
            width: diameter,
            height: diameter,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppPallete.surface,
              shape: BoxShape.circle,
              boxShadow: shadow
                  ? [BoxShadow(color: AppPallete.shadow.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Padding(padding: EdgeInsets.only(top: iconSize * 0.08), child: icon),
          ),
        ),
      ),
    );
  }
}

/// The orange square cart button. Shows progress, then a check when the item lands in the cart.
class CardCartButton extends ConsumerStatefulWidget {
  const CardCartButton({super.key, required this.product, this.size = 25});

  final ProductSummary product;
  final double size;

  @override
  ConsumerState<CardCartButton> createState() => _CardCartButtonState();
}

class _CardCartButtonState extends ConsumerState<CardCartButton> {
  _AddState _state = _AddState.idle;

  Future<void> _add() async {
    if (_state != _AddState.idle) return;
    setState(() => _state = _AddState.adding);
    final added = await quickAddToCart(context, ref, widget.product);
    if (!mounted) return;
    setState(() => _state = added ? _AddState.added : _AddState.idle);
    if (added) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) setState(() => _state = _AddState.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final soldOut = widget.product.isOutOfStock;
    final Widget child = switch (_state) {
      _AddState.adding => SizedBox(
          key: const ValueKey('adding'),
          width: size * 0.48,
          height: size * 0.48,
          child: const CircularProgressIndicator(strokeWidth: 1.8, color: AppPallete.onDark),
        ),
      _AddState.added => Icon(PhosphorIconsBold.check, key: const ValueKey('added'), size: size * 0.56, color: AppPallete.onDark),
      _AddState.idle => Icon(
          PhosphorIconsBold.shoppingCartSimple,
          key: const ValueKey('idle'),
          size: size * 0.6,
          color: AppPallete.onDark,
        ),
    };
    return Pressable(
      pressedScale: 0.88,
      enabled: !soldOut,
      semanticLabel: widget.product.needsVariantChoice
          ? 'Choose options for ${widget.product.name}'
          : 'Add ${widget.product.name} to cart',
      onTap: _add,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: soldOut
              ? AppPallete.skeleton
              : _state == _AddState.added
                  ? AppPallete.success
                  : AppPallete.accent,
          borderRadius: BorderRadius.circular(size * 0.26),
          boxShadow: soldOut
              ? null
              : [BoxShadow(color: AppPallete.shadowAccent.withValues(alpha: 0.28), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.short),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: child,
        ),
      ),
    );
  }
}

enum _AddState { idle, adding, added }
