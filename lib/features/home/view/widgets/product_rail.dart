import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/router/web_link.dart';
import 'package:pickorbeet/core/widgets/section.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/view/widgets/product_card.dart';
import 'package:pickorbeet/features/home/view/widgets/category_section_card.dart';

/// Home product collections: Trending uses a dense 2-column grid; New Arrivals stays a
/// horizontal scroll rail (same UX as before).
class ProductRail extends StatelessWidget {
  const ProductRail({super.key, required this.section});

  final ProductsSection section;

  static const _inset = 6.84;
  static const _gap = 8.3;
  static const _columns = 2;

  /// The rails' header is a size down from the category cards' in the design.
  static final _titleStyle = SectionHeader.titleStyle.copyWith(fontSize: 13.6, letterSpacing: -0.272);
  static final _viewAllStyle = ViewAllLink.textStyle.copyWith(fontSize: 8.7, letterSpacing: 0);

  bool get _useGrid => section.key == 'trending';

  @override
  Widget build(BuildContext context) {
    final products = section.products;
    if (products.isEmpty) return const SizedBox.shrink();
    final scaler = MediaQuery.textScalerOf(context);
    final reduced = Motion.reduced(context);
    final viewAll = WebLink.resolve(section.viewAllUrl, title: section.title) ??
        Routes.productList(title: section.title);

    return HomeCard(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(_inset, 7.3, 7.1, 0),
            child: SectionHeader(
              title: section.title,
              style: _titleStyle,
              viewAllStyle: _viewAllStyle,
              viewAllLabel: section.viewAllLabel,
              onViewAll: () => context.push(viewAll, extra: section.bannerImage),
            ),
          ),
          const SizedBox(height: 7.3),
          if (_useGrid)
            _grid(products, scaler, reduced)
          else
            _horizontalRail(products, scaler, reduced),
        ],
      ),
    );
  }

  Widget _horizontalRail(List<ProductSummary> products, TextScaler scaler, bool reduced) {
    const width = ProductCard.designWidth;
    return Column(
      children: [
        SizedBox(
          height: ProductCard.heightFor(width, scaler),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _inset),
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (context, index) {
              final card = ProductCard(product: products[index], heroScope: section.key);
              if (reduced || index > 4) return card;
              return card
                  .animate(delay: Motion.staggerDelay(index) + const Duration(milliseconds: 120))
                  .fadeIn(duration: Motion.entrance, curve: Motion.emphasizedDecelerate)
                  .moveX(begin: 24, end: 0, duration: Motion.entrance, curve: Motion.emphasizedDecelerate);
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _grid(List<ProductSummary> products, TextScaler scaler, bool reduced) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_inset, 0, _inset, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - _gap * (_columns - 1)) / _columns;
          final cardHeight = ProductCard.heightFor(cardWidth, scaler);
          return Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (var index = 0; index < products.length; index++)
                SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: _animateGrid(
                    reduced: reduced,
                    index: index,
                    child: ProductCard(
                      product: products[index],
                      width: cardWidth,
                      heroScope: section.key,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _animateGrid({
    required bool reduced,
    required int index,
    required Widget child,
  }) {
    if (reduced || index > 5) return child;
    return child
        .animate(delay: Motion.staggerDelay(index) + const Duration(milliseconds: 120))
        .fadeIn(duration: Motion.entrance, curve: Motion.emphasizedDecelerate)
        .moveY(begin: 16, end: 0, duration: Motion.entrance, curve: Motion.emphasizedDecelerate);
  }
}
