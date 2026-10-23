import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/core/widgets/section.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';

/// A featured category: its name, "View All", and up to four subcategory tiles.
class CategorySectionCard extends StatelessWidget {
  const CategorySectionCard({super.key, required this.category});

  final CategoryModel category;

  static const radius = 11.7;
  static const _tileGap = 9.6;
  static const _tileInset = 12.0;

  /// Inter SemiBold 9.7 at -0.03 em.
  static final labelStyle = AppTypography.label.copyWith(
    fontSize: 9.7,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.29,
    height: 1.2,
    color: AppPallete.ink,
  );

  @override
  Widget build(BuildContext context) {
    final tiles = category.subcategories.take(4).toList();
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13.7, 8, 10.5, 0),
            child: SectionHeader(
              title: category.name,
              onViewAll: () => context.push(Routes.category(category.slug)),
            ),
          ),
          const SizedBox(height: 6.85),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _tileInset),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: _tileGap),
                  Expanded(
                    child: i < tiles.length
                        ? _SubcategoryTile(category: category, subcategory: tiles[i])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 11.6),
        ],
      ),
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({required this.category, required this.subcategory});

  final CategoryModel category;
  final SubcategoryModel subcategory;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.95,
      semanticLabel: subcategory.name,
      onTap: () => context.push(
        Routes.productList(title: subcategory.name, categorySlug: category.slug, subcategorySlug: subcategory.slug),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: AppNetworkImage(
              url: subcategory.image ?? category.image,
              borderRadius: BorderRadius.circular(10.75),
              placeholderIcon: PhosphorIconsRegular.squaresFour,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subcategory.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: CategorySectionCard.labelStyle,
          ),
        ],
      ),
    );
  }
}

/// The white rounded card used by every home section.
class HomeCard extends StatelessWidget {
  const HomeCard({super.key, required this.child, this.clip = false});

  final Widget child;

  /// Clips children to the rounded corners, for rails that scroll under the card's edge.
  final bool clip;

  static final shadow = <BoxShadow>[
    BoxShadow(color: AppPallete.shadow.withValues(alpha: 0.065), blurRadius: 12, offset: const Offset(0, 3)),
  ];

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(CategorySectionCard.radius);
    return DecoratedBox(
      decoration: BoxDecoration(color: AppPallete.surface, borderRadius: borderRadius, boxShadow: shadow),
      child: clip ? ClipRRect(borderRadius: borderRadius, child: child) : child,
    );
  }
}
