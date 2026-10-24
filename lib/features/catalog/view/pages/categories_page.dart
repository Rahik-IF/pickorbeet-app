import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/motion/entrance.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/router/tab_reselect.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/app_header.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/core/widgets/skeleton.dart';
import 'package:pickorbeet/core/widgets/state_views.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/viewmodel/catalog_providers.dart';
import 'package:pickorbeet/features/home/view/widgets/category_section_card.dart';
import 'package:pickorbeet/features/home/view/widgets/promo_banners.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Shop by Categories: a featured banner, every category with its real item count, and the wide
/// homepage promo.
class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  static const tabIndex = 1;
  static const margin = 12.2;

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  final _scroll = ScrollController();

  Future<void> _refresh() async {
    ref
      ..invalidate(categoriesProvider)
      ..invalidate(homeSectionsProvider);
    try {
      await Future.wait([ref.read(categoriesProvider.future), ref.read(homeSectionsProvider.future)]);
    } on Object {
      // The listener reports a refresh that failed while older data is still on screen.
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    listenForTabReselect(ref, context, CategoriesPage.tabIndex, _scroll);
    ref.listen(categoriesProvider, (previous, next) {
      if (next.hasError && next.hasValue && !next.isLoading) {
        showToast(context, "Couldn't refresh. Showing what we had.", kind: ToastKind.error);
      }
    });

    final categories = ref.watch(categoriesProvider);
    final value = categories.valueOrNull;
    final Widget body;
    if (value != null) {
      body = _CategoriesContent(categories: value, controller: _scroll);
    } else if (categories.hasError) {
      body = _Scrollable(
        controller: _scroll,
        child: Padding(
          padding: const EdgeInsets.only(top: 48),
          child: ErrorState(failure: categories.error!, onRetry: _refresh),
        ),
      );
    } else {
      body = _Scrollable(controller: _scroll, child: const _CategoriesSkeleton());
    }

    return Scaffold(
      backgroundColor: AppPallete.background,
      body: Column(
        children: [
          const TabHeader(showBell: false, heroTag: 'search-categories'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppPallete.primary,
              backgroundColor: AppPallete.surface,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: KeyedSubtree(key: ValueKey(body.runtimeType), child: body),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      child: child,
    );
  }
}

class _CategoriesContent extends ConsumerWidget {
  const _CategoriesContent({required this.categories, required this.controller});

  final List<CategoryModel> categories;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categories.isEmpty) {
      return _Scrollable(
        controller: controller,
        child: const Padding(
          padding: EdgeInsets.only(top: 48),
          child: EmptyState(
            icon: PhosphorIconsDuotone.squaresFour,
            title: 'No categories yet',
            message: 'Departments will show up here as the shop adds them.',
          ),
        ),
      );
    }

    final featured = _featuredWithBanner(categories);
    final promos = [
      for (final section in ref.watch(homeSectionsProvider).valueOrNull ?? const <HomeSection>[])
        if (section is PromoSection) ...section.banners.skip(2),
    ];

    final blocks = <Widget>[
      const _PageTitle().entrance(),
      const SizedBox(height: 12),
      if (featured != null) ...[
        _FeaturedBanner(category: featured).entrance(index: 1),
        const SizedBox(height: 14),
      ],
      _AllCategoriesHeader(
        onViewAll: () => context.push(Routes.products),
      ).entrance(index: 2),
      const SizedBox(height: 11),
    ];

    for (var i = 0; i < categories.length; i += 2) {
      final right = i + 1 < categories.length ? categories[i + 1] : null;
      blocks.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _CategoryTile(category: categories[i]).entrance(index: 3 + i ~/ 2, enabled: i < 6)),
            const SizedBox(width: _CategoryTile.gap),
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : _CategoryTile(category: right).entrance(index: 3 + i ~/ 2, enabled: i < 6),
            ),
          ],
        ),
      );
      blocks.add(const SizedBox(height: _CategoryTile.rowGap));
    }

    for (final banner in promos) {
      blocks
        ..add(const SizedBox(height: 2))
        ..add(PromoBanner(banner: banner, aspect: PromoBanner.wideAspect).entrance(enabled: false));
    }

    return SingleChildScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(CategoriesPage.margin, 11, CategoriesPage.margin, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocks),
    );
  }
}

/// The featured category the banner introduces, preferring one that actually has artwork.
CategoryModel? _featuredWithBanner(List<CategoryModel> categories) {
  final featured = categories.where((c) => c.isFeatured && (c.bannerImage?.isNotEmpty ?? false)).toList()
    ..sort((a, b) => a.featuredOrder.compareTo(b.featuredOrder));
  if (featured.isNotEmpty) return featured.first;
  for (final category in categories) {
    if (category.bannerImage?.isNotEmpty ?? false) return category;
  }
  return null;
}

class _PageTitle extends StatelessWidget {
  const _PageTitle();

  static final _title = AppTypography.titleLarge.copyWith(
    fontSize: 21.85,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.44,
    height: 1.12,
    color: AppPallete.ink,
  );

  static final _subtitle = AppTypography.bodyLarge.copyWith(
    fontSize: 11.4,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: const Color(0xFF5C6984),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shop by Categories', style: _title),
          const SizedBox(height: 5),
          Text('Explore our wide range of products', style: _subtitle),
        ],
      ),
    );
  }
}

/// Featured category artwork with its name, tagline and Explore action painted on top.
class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({required this.category});

  final CategoryModel category;

  static const height = 114.9;
  static const radius = 12.0;

  static final _name = AppTypography.titleLarge.copyWith(
    fontSize: 22.2,
    fontWeight: FontWeight.w700,
    height: 1.05,
    color: AppPallete.onDark,
  );

  static final _tagline = AppTypography.bodyLarge.copyWith(
    fontSize: 11.8,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppPallete.onDark,
  );

  @override
  Widget build(BuildContext context) {
    final tagline = _bannerTagline(category.tagline);
    final spoken = category.tagline.trim();
    return Pressable(
      pressedScale: 0.985,
      semanticLabel: spoken.isEmpty ? '${category.name}. Explore now' : '${category.name}. $spoken. Explore now',
      onTap: () => context.push(Routes.category(category.slug)),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: HomeCard.shadow),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: SizedBox(
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(url: category.bannerImage, background: AppPallete.headerMid),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(27, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: TextScaler.noScaling,
                          style: _name,
                        ),
                        if (tagline.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 150,
                            child: Text(
                              tagline,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textScaler: TextScaler.noScaling,
                              style: _tagline,
                            ),
                          ),
                        ],
                        const Spacer(),
                        const _ExploreChip(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Breaks a banner tagline before "for" when both sides are real phrases, matching the design's
/// two-line lockup ("Latest Gadgets" / "for Your Everyday Life").
String _bannerTagline(String raw) {
  final tagline = raw.trim();
  final at = tagline.toLowerCase().indexOf(' for ');
  if (at < 8 || at > tagline.length - 8) return tagline;
  return '${tagline.substring(0, at)}\n${tagline.substring(at + 1)}';
}

class _ExploreChip extends StatelessWidget {
  const _ExploreChip();

  static final _label = AppTypography.label.copyWith(
    fontSize: 10.4,
    fontWeight: FontWeight.w600,
    height: 1,
    color: AppPallete.onDark,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(color: AppPallete.accent, borderRadius: BorderRadius.circular(13)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Explore Now', textScaler: TextScaler.noScaling, style: _label),
          const SizedBox(width: 6),
          const Icon(PhosphorIconsBold.arrowRight, size: 11, color: AppPallete.onDark),
        ],
      ),
    );
  }
}

class _AllCategoriesHeader extends StatelessWidget {
  const _AllCategoriesHeader({required this.onViewAll});

  final VoidCallback onViewAll;

  static final _title = AppTypography.titleSmall.copyWith(
    fontSize: 14.45,
    fontWeight: FontWeight.w700,
    height: 1.15,
    color: AppPallete.ink,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3.2,
          height: 18.5,
          decoration: BoxDecoration(color: AppPallete.accent, borderRadius: BorderRadius.circular(1.6)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text('All Categories', maxLines: 1, overflow: TextOverflow.ellipsis, style: _title)),
        _ViewAllPill(onTap: onViewAll),
      ],
    );
  }
}

class _ViewAllPill extends StatelessWidget {
  const _ViewAllPill({required this.onTap});

  final VoidCallback onTap;

  static final _label = AppTypography.label.copyWith(
    fontSize: 10.2,
    fontWeight: FontWeight.w600,
    height: 1,
    color: AppPallete.viewAll,
  );

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'View all products',
      onTap: onTap,
      child: Container(
        height: 23.5,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD4DDF4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('View All', textScaler: TextScaler.noScaling, style: _label),
            const SizedBox(width: 3),
            const Icon(PhosphorIconsBold.caretRight, size: 10, color: AppPallete.viewAll),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final CategoryModel category;

  static const gap = 12.2;
  static const rowGap = 8.4;
  static const radius = 12.0;

  static final _name = AppTypography.titleSmall.copyWith(
    fontSize: 12.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.24,
    height: 1.15,
    color: AppPallete.ink,
  );

  static final _count = AppTypography.bodySmall.copyWith(
    fontSize: 8.5,
    fontWeight: FontWeight.w400,
    height: 1.2,
    color: const Color(0xFF657188),
  );

  @override
  Widget build(BuildContext context) {
    final count = category.productCount;
    final countLabel = count <= 0 ? 'No items yet' : Formatters.items(count);
    return Pressable(
      pressedScale: 0.98,
      semanticLabel: '${category.name}, $countLabel',
      onTap: () => context.push(
        Routes.productList(title: category.name, categorySlug: category.slug),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPallete.surface,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: HomeCard.shadow,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 48,
                  child: AppNetworkImage(
                    url: category.image,
                    borderRadius: BorderRadius.circular(9),
                    background: const Color(0xFFF4F7FC),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: _name),
                      const SizedBox(height: 2),
                      Text(countLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: _count),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(PhosphorIconsBold.caretRight, size: 13, color: Color(0xFFB0B8C8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoriesSkeleton extends StatelessWidget {
  const _CategoriesSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppSkeletonTheme(
      child: Skeletonizer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(CategoriesPage.margin, 11, CategoriesPage.margin, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(alignment: Alignment.centerLeft, child: SkeletonBox(width: 210, height: 22)),
              const SizedBox(height: 8),
              const Align(alignment: Alignment.centerLeft, child: SkeletonBox(width: 190, height: 12, radius: 4)),
              const SizedBox(height: 12),
              const SkeletonBox(height: _FeaturedBanner.height, radius: _FeaturedBanner.radius),
              const SizedBox(height: 14),
              const Align(alignment: Alignment.centerLeft, child: SkeletonBox(width: 140, height: 16, radius: 4)),
              const SizedBox(height: 11),
              for (var i = 0; i < 4; i++) ...[
                const Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 62, radius: 12)),
                    SizedBox(width: _CategoryTile.gap),
                    Expanded(child: SkeletonBox(height: 62, radius: 12)),
                  ],
                ),
                const SizedBox(height: _CategoryTile.rowGap),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
