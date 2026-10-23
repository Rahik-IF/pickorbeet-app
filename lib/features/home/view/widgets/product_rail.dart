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

/// "Trending Products" and "New Arrivals": a titled card with a horizontal row of products.
class ProductRail extends StatelessWidget {
  const ProductRail({super.key, required this.section});

  final ProductsSection section;

  static const _inset = 6.84;
  static const _gap = 8.3;

  /// The rails' header is a size down from the category cards' in the design.
  static final _titleStyle = SectionHeader.titleStyle.copyWith(fontSize: 13.6, letterSpacing: -0.272);
  static final _viewAllStyle = ViewAllLink.textStyle.copyWith(fontSize: 8.7, letterSpacing: 0);

  @override
  Widget build(BuildContext context) {
    final products = section.products;
    if (products.isEmpty) return const SizedBox.shrink();
    final scaler = MediaQuery.textScalerOf(context);
    const width = ProductCard.designWidth;
    final reduced = Motion.reduced(context);
    final viewAll = WebLink.resolve(section.viewAllUrl, title: section.title) ?? Routes.productList(title: section.title);

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
              onViewAll: () => context.push(viewAll),
            ),
          ),
          const SizedBox(height: 7.3),
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
      ),
    );
  }
}
