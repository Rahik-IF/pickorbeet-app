import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/motion/entrance.dart';
import 'package:pickorbeet/core/router/tab_reselect.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/widgets/app_header.dart';
import 'package:pickorbeet/core/widgets/skeleton.dart';
import 'package:pickorbeet/core/widgets/state_views.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/view/widgets/product_card.dart';
import 'package:pickorbeet/features/catalog/viewmodel/catalog_providers.dart';
import 'package:pickorbeet/features/home/view/widgets/category_section_card.dart';
import 'package:pickorbeet/features/home/view/widgets/hero_carousel.dart';
import 'package:pickorbeet/features/home/view/widgets/home_menu_sheet.dart';
import 'package:pickorbeet/features/home/view/widgets/product_rail.dart';
import 'package:pickorbeet/features/home/view/widgets/promo_banners.dart';
import 'package:pickorbeet/features/home/view/widgets/trust_strip.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Product-first storefront: short hero, dense product collections, then light chrome.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  static const tabIndex = 0;

  /// Side margin of every home block (design: 25 px of 841).
  static const margin = 12.2;

  static const _maxHeroBanners = 3;
  static const _maxFeaturedCategories = 1;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();

  Future<void> _refresh() async {
    ref
      ..invalidate(homeSectionsProvider)
      ..invalidate(categoriesProvider);
    try {
      await Future.wait([ref.read(homeSectionsProvider.future), ref.read(categoriesProvider.future)]);
    } on Object {
      // The listener below reports the failure; the old content stays on screen.
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    listenForTabReselect(ref, context, HomePage.tabIndex, _scroll);
    ref.listen(homeSectionsProvider, (previous, next) {
      if (next.hasError && next.hasValue && !next.isLoading) {
        showToast(context, "Couldn't refresh. Showing what we had.", kind: ToastKind.error);
      }
    });

    final sections = ref.watch(homeSectionsProvider);
    final value = sections.valueOrNull;
    final Widget body;
    if (value != null) {
      body = _HomeContent(sections: value, controller: _scroll);
    } else if (sections.hasError) {
      body = _Scrollable(
        controller: _scroll,
        child: Padding(
          padding: const EdgeInsets.only(top: 48),
          child: ErrorState(failure: sections.error!, onRetry: _refresh),
        ),
      );
    } else {
      body = _Scrollable(controller: _scroll, child: const _HomeSkeleton());
    }

    return Scaffold(
      backgroundColor: AppPallete.background,
      body: Column(
        children: [
          HomeHeader(onMenu: () => showHomeMenu(context)),
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

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.sections, required this.controller});

  final List<HomeSection> sections;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredCategoriesProvider);
    final blocks = <Widget>[];

    var order = 0;
    void add(Widget block, {double gapBefore = 10.3}) {
      if (blocks.isNotEmpty) blocks.add(SizedBox(height: gapBefore));
      // Only the first screenful staggers; blocks further down are already in place.
      blocks.add(block.entrance(index: order++, enabled: order <= 5));
    }

    // Product-first order (not raw CMS order): hero → products → trust → 1 category → promos.
    HeroSection? hero;
    BenefitsSection? benefits;
    PromoSection? promos;
    final productSections = <ProductsSection>[];
    var hasCategories = false;

    for (final section in sections) {
      switch (section) {
        case final HeroSection row when row.banners.isNotEmpty:
          hero ??= row;
        case final ProductsSection row when row.products.isNotEmpty:
          productSections.add(row);
        case final BenefitsSection row when row.items.isNotEmpty:
          benefits ??= row;
        case CategoriesSection():
          hasCategories = true;
        case final PromoSection row when row.banners.isNotEmpty:
          promos ??= row;
        default:
          break;
      }
    }

    if (hero != null) {
      final banners = hero.banners.take(HomePage._maxHeroBanners).toList();
      add(HeroCarousel(banners: banners), gapBefore: 0);
    }

    for (final section in productSections) {
      add(ProductRail(section: section), gapBefore: blocks.isEmpty ? 0 : 10.3);
    }

    if (benefits != null) {
      add(TrustStrip(items: benefits.items));
    }

    if (hasCategories) {
      final cards = featured.valueOrNull ?? const <CategoryModel>[];
      if (featured.isLoading && cards.isEmpty) {
        add(const _CategoryCardSkeleton());
      } else if (cards.isNotEmpty) {
        // One featured category card max — product collections keep the vertical space.
        add(CategorySectionCard(category: cards.take(HomePage._maxFeaturedCategories).first));
      }
    }

    if (promos != null) {
      add(PromoRow(banners: promos.banners), gapBefore: 13.7);
    }

    if (blocks.isEmpty) {
      return _Scrollable(
        controller: controller,
        child: const Padding(
          padding: EdgeInsets.only(top: 48),
          child: EmptyState(
            icon: PhosphorIconsDuotone.storefront,
            title: 'The shop is getting ready',
            message: 'New products are on their way. Pull down to check again.',
          ),
        ),
      );
    }

    // A handful of blocks: a Column keeps them alive, so entrances never replay on scroll.
    return SingleChildScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(HomePage.margin, 3.9, HomePage.margin, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocks),
    );
  }
}

/// Loading layout with the same shapes as the real page.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final cardWidth = (MediaQuery.sizeOf(context).width - HomePage.margin * 2 - 6.84 * 2 - 8.3) / 2;
    final cardHeight = ProductCard.heightFor(cardWidth.clamp(100, 200), scaler);

    return AppSkeletonTheme(
      child: Skeletonizer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(HomePage.margin, 3.9, HomePage.margin, 20),
          child: Column(
            children: [
              const AspectRatio(aspectRatio: HeroCarousel.aspect, child: SkeletonBox(radius: HeroCarousel.radius)),
              const SizedBox(height: 10.3),
              HomeCard(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6.84, 12, 6.84, 10),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: SkeletonBox(width: 120, height: 14, radius: 4),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: SizedBox(height: cardHeight, child: const SkeletonBox(radius: 10))),
                          const SizedBox(width: 8.3),
                          Expanded(child: SizedBox(height: cardHeight, child: const SkeletonBox(radius: 10))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10.3),
              const SizedBox(height: 70, child: SkeletonBox(radius: 11)),
              const SizedBox(height: 10.3),
              const _CategoryCardSkeleton(),
              const SizedBox(height: 13.7),
              const Row(
                children: [
                  Expanded(
                    child: AspectRatio(aspectRatio: PromoBanner.halfAspect, child: SkeletonBox(radius: 11.2)),
                  ),
                  SizedBox(width: 10.3),
                  Expanded(
                    child: AspectRatio(aspectRatio: PromoBanner.halfAspect, child: SkeletonBox(radius: 11.2)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCardSkeleton extends StatelessWidget {
  const _CategoryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const HomeCard(
      child: Padding(
        padding: EdgeInsets.fromLTRB(11.7, 12, 11.7, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 110, height: 15, radius: 4),
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _TileSkeleton()),
                SizedBox(width: 9.7),
                Expanded(child: _TileSkeleton()),
                SizedBox(width: 9.7),
                Expanded(child: _TileSkeleton()),
                SizedBox(width: 9.7),
                Expanded(child: _TileSkeleton()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        AspectRatio(aspectRatio: 1, child: SkeletonBox(radius: 10.75)),
        SizedBox(height: 8),
        SkeletonBox(width: 48, height: 9, radius: 3),
      ],
    );
  }
}
