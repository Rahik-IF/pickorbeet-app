import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/wishlist_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/view/widgets/product_card.dart';
import 'package:pickorbeet/features/search/view/search_palette.dart';
import 'package:pickorbeet/features/search/viewmodel/search_controller.dart';

/// One suggested product: image, name, price, wishlist, and quick add.
class SearchProductTile extends ConsumerWidget {
  const SearchProductTile({super.key, required this.product, required this.query});

  final ProductSummary product;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = SearchPalette.of(context);
    final saved = ref.watch(isWishlistedProvider(product.id));
    final meta = _meta(product);
    final rating = _ratingLabel(product);
    final percent = _percent(product);
    final soldOut = product.isOutOfStock;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.line),
        ),
        child: Pressable(
          onTap: () => context.push(Routes.product(product.slug)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      children: [
                        Positioned.fill(child: AppNetworkImage(url: product.primaryImage)),
                        if (product.isOfficial)
                          OfficialMark(
                            style: officialBadgeStyleOf(ref),
                            inset: 3,
                            scale: officialBadgeStyleOf(ref).scaleFor(0.62),
                            maxWidth: 66,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Name(name: product.name, query: query, colors: colors),
                      if (meta != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge.copyWith(color: colors.muted, fontSize: 12),
                        ),
                      ],
                      if (rating != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(PhosphorIconsFill.star, size: 13, color: SearchPalette.star),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                rating,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyMedium.copyWith(color: colors.ink, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            Formatters.money(product.price),
                            style: AppTypography.price.copyWith(color: colors.ink, fontSize: 15),
                          ),
                          if (product.hasDiscount)
                            Text(
                              Formatters.money(product.comparePrice),
                              style: AppTypography.strike.copyWith(
                                color: colors.muted,
                                decorationColor: colors.muted,
                              ),
                            ),
                          if (soldOut)
                            Text(
                              'Out of stock',
                              style: AppTypography.label.copyWith(color: AppPallete.danger, fontSize: 11),
                            )
                          else if (percent > 0)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.soft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                child: Text(
                                  Formatters.discount(percent),
                                  style: AppTypography.labelSmall.copyWith(
                                    color: colors.softText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  children: [
                    Pressable(
                      semanticLabel: saved ? 'Remove ${product.name} from wishlist' : 'Add ${product.name} to wishlist',
                      onTap: () => toggleWishlist(context, ref, product),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: DecoratedBox(
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.line)),
                          child: Icon(
                            saved ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                            size: 18,
                            color: saved ? AppPallete.sale : colors.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Pressable(
                      semanticLabel: soldOut ? '${product.name} is out of stock' : 'Add ${product.name} to cart',
                      onTap: soldOut ? null : () => unawaited(quickAddToCart(context, ref, product)),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: soldOut ? colors.line : SearchPalette.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            PhosphorIconsFill.shoppingCartSimple,
                            size: 18,
                            color: soldOut ? colors.muted : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Name extends StatelessWidget {
  const _Name({required this.name, required this.query, required this.colors});

  final String name;
  final String query;
  final SearchPalette colors;

  @override
  Widget build(BuildContext context) {
    final base = AppTypography.titleMedium.copyWith(color: colors.ink, fontSize: 14.5, height: 1.25);
    final match = base.copyWith(color: colors.highlight, fontWeight: FontWeight.w800);
    return Text.rich(
      TextSpan(children: _highlight(name, query, base, match)),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

List<TextSpan> _highlight(String text, String query, TextStyle base, TextStyle match) {
  final needle = query.trim();
  if (needle.isEmpty) return [TextSpan(text: text, style: base)];
  final lower = text.toLowerCase();
  final target = needle.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (start < text.length) {
    final index = lower.indexOf(target, start);
    if (index < 0) {
      spans.add(TextSpan(text: text.substring(start), style: base));
      break;
    }
    if (index > start) spans.add(TextSpan(text: text.substring(start, index), style: base));
    final end = index + target.length;
    spans.add(TextSpan(text: text.substring(index, end), style: match));
    start = end;
  }
  return spans;
}

String? _meta(ProductSummary product) {
  final brand = brandLabel(product.name);
  if (brand.isEmpty || product.sku.isEmpty) return null;
  return '$brand | ${product.sku}';
}

String? _ratingLabel(ProductSummary product) {
  final rating = product.rating;
  if (rating == null) return null;
  final score = rating.toStringAsFixed(1);
  final count = product.reviewCount;
  if (count == null) return score;
  final compact = count >= 1000 ? Formatters.compact(count) : '$count';
  final noun = count == 1 ? 'review' : 'reviews';
  return '$score ($compact $noun)';
}

int _percent(ProductSummary product) {
  if (product.discountPercentage > 0) return product.discountPercentage;
  if (!product.hasDiscount) return 0;
  final was = Formatters.decimal(product.comparePrice).toDouble();
  final now = Formatters.decimal(product.price).toDouble();
  if (was <= 0 || now >= was) return 0;
  return ((was - now) / was * 100).round();
}
