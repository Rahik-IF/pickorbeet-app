import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/models/paginated.dart';
import 'package:pickorbeet/core/motion/entrance.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/wishlist_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/core/widgets/bottom_nav.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';
import 'package:pickorbeet/core/widgets/state_views.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/view/widgets/product_card.dart';
import 'package:pickorbeet/features/catalog/viewmodel/catalog_providers.dart';

/// A category or subcategory catalogue: hero, sibling chips, and the store's product cards.
class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key, required this.query, this.title});

  final ProductQuery query;
  final String? title;

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  late ProductQuery _query = widget.query;
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(ProductListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _query = widget.query;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _sort(String? ordering) {
    setState(() {
      _query = ProductQuery(
        categorySlug: _query.categorySlug,
        subcategorySlug: _query.subcategorySlug,
        search: _query.search,
        ordering: ordering,
        featured: _query.featured,
        onSale: _query.onSale,
        minPrice: _query.minPrice,
        maxPrice: _query.maxPrice,
      );
    });
  }

  Future<void> _filter() async {
    final sale = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppPallete.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => _FilterSheet(onSale: _query.onSale),
    );
    if (sale == null || !mounted) return;
    setState(() {
      _query = ProductQuery(
        categorySlug: _query.categorySlug,
        subcategorySlug: _query.subcategorySlug,
        search: _query.search,
        ordering: _query.ordering,
        featured: _query.featured,
        onSale: sale,
      );
    });
  }

  void _openTab(int index) {
    const tabs = [Routes.home, Routes.categories, Routes.wishlist, Routes.account, Routes.cart];
    context.go(tabs[index]);
  }

  bool _nearEnd(ScrollNotification notice) {
    if (notice.metrics.pixels < notice.metrics.maxScrollExtent - 480) return false;
    final list = ref.read(productListProvider(_query));
    if (list.valueOrNull?.hasMore ?? false) {
      ref.read(productListProvider(_query).notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <CategoryModel>[];
    final category = _find(categories, _query.categorySlug);
    final subcategory = _findSub(category, _query.subcategorySlug);
    final list = ref.watch(productListProvider(_query));
    final title = subcategory?.name ?? category?.name ?? widget.title ?? 'Products';

    return Scaffold(
      backgroundColor: AppPallete.background,
      bottomNavigationBar: AppBottomNav(
        currentIndex: 1,
        onSelect: _openTab,
        cartCount: ref.watch(cartCountProvider),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _nearEnd,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(productListProvider(_query));
            await ref.read(productListProvider(_query).future);
          },
          color: AppPallete.primary,
          backgroundColor: AppPallete.surface,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(
                  title: title,
                  subtitle: subcategory?.description ?? category?.tagline ?? '',
                  image: subcategory?.image ?? category?.bannerImage ?? category?.image,
                  categoryName: category?.name,
                  onHome: () => context.go(Routes.home),
                  onCategory: category == null
                      ? null
                      : () => context.push(Routes.productList(title: category.name, categorySlug: category.slug)),
                ),
              ),
              if (category != null && category.subcategories.isNotEmpty)
                SliverToBoxAdapter(
                  child: _ChipRow(
                    category: category,
                    selectedSlug: subcategory?.slug,
                  ),
                ),
              SliverToBoxAdapter(
                child: _ListHeader(
                  title: title,
                  count: list.valueOrNull?.count,
                  filtered: _query.onSale,
                  onFilter: _filter,
                  onSort: _sort,
                  ordering: _query.ordering,
                ),
              ),
              ..._products(list, title),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _products(AsyncValue<Paginated<ProductSummary>> list, String title) {
    return list.when(
      loading: () => [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: CircularProgressIndicator(color: AppPallete.primary)),
          ),
        ),
      ],
      error: (error, _) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 32),
            child: ErrorState(failure: error, onRetry: () => ref.invalidate(productListProvider(_query))),
          ),
        ),
      ],
      data: (page) {
        if (page.results.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: PhosphorIconsDuotone.package,
                  title: 'No products found',
                  message: 'Nothing in $title matches this view yet.',
                ),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            sliver: SliverList.separated(
              itemCount: page.results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _CatalogCard(product: page.results[index]).entrance(index: index, enabled: index < 6),
            ),
          ),
          if (page.hasMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppPallete.primary)),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ];
      },
    );
  }
}

CategoryModel? _find(List<CategoryModel> categories, String? slug) {
  if (slug == null) return null;
  for (final category in categories) {
    if (category.slug == slug) return category;
  }
  return null;
}

SubcategoryModel? _findSub(CategoryModel? category, String? slug) {
  if (category == null || slug == null) return null;
  for (final sub in category.subcategories) {
    if (sub.slug == slug) return sub;
  }
  return null;
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.subtitle,
    required this.onHome,
    this.image,
    this.categoryName,
    this.onCategory,
  });

  final String title;
  final String subtitle;
  final String? image;
  final String? categoryName;
  final VoidCallback onHome;
  final VoidCallback? onCategory;

  static const _fallback = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2F6BFF), Color(0xFF5B8CFF), Color(0xFFFF8A3D)],
  );

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final artwork = image?.trim();
    final hasImage = artwork != null && artwork.isNotEmpty;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnDark,
      child: SizedBox(
        height: top + 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              AppNetworkImage(
                url: artwork,
                alignment: Alignment.centerRight,
                background: AppPallete.headerMid,
              )
            else
              const DecoratedBox(decoration: BoxDecoration(gradient: _fallback)),
            if (hasImage) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppPallete.headerEnd.withValues(alpha: 0.9),
                      AppPallete.headerEnd.withValues(alpha: 0.55),
                      AppPallete.headerEnd.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.42, 0.78],
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 36,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00F3F7FE), AppPallete.background],
                    ),
                  ),
                ),
              ),
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(16, top + 10, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Breadcrumb(categoryName: categoryName, title: title, onHome: onHome, onCategory: onCategory),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleLarge.copyWith(color: AppPallete.onDark, fontSize: 28, height: 1.05),
                  ),
                  if (subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyLarge.copyWith(color: const Color(0xFFF4F7FF), fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.title,
    required this.onHome,
    this.categoryName,
    this.onCategory,
  });

  final String title;
  final String? categoryName;
  final VoidCallback onHome;
  final VoidCallback? onCategory;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodySmall.copyWith(color: const Color(0xFFE7EEFF), fontSize: 12);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Pressable(onTap: onHome, child: Text('Home', style: style)),
        const Icon(PhosphorIconsBold.caretRight, size: 10, color: Color(0xFFE7EEFF)),
        if (categoryName != null && onCategory != null) ...[
          Pressable(onTap: onCategory, child: Text(categoryName!, style: style)),
          const Icon(PhosphorIconsBold.caretRight, size: 10, color: Color(0xFFE7EEFF)),
        ],
        Text(title, style: style.copyWith(color: AppPallete.onDark, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ChipRow extends StatefulWidget {
  const _ChipRow({required this.category, required this.selectedSlug});

  final CategoryModel category;
  final String? selectedSlug;

  @override
  State<_ChipRow> createState() => _ChipRowState();
}

class _ChipRowState extends State<_ChipRow> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final index = widget.category.subcategories.indexWhere((sub) => sub.slug == widget.selectedSlug);
    if (index >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final selectedSlug = widget.selectedSlug;
    final subs = category.subcategories;
    return SizedBox(
      height: 58,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        itemCount: subs.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _Chip(
              label: 'All ${category.name}',
              icon: PhosphorIconsRegular.squaresFour,
              selected: selectedSlug == null,
              onTap: () => context.push(Routes.productList(title: category.name, categorySlug: category.slug)),
            );
          }
          final sub = subs[index - 1];
          return _Chip(
            label: sub.name,
            icon: _iconFor(sub.slug),
            selected: sub.slug == selectedSlug,
            onTap: () => context.push(
              Routes.productList(title: sub.name, categorySlug: category.slug, subcategorySlug: sub.slug),
            ),
          );
        },
      ),
    );
  }
}

IconData _iconFor(String slug) {
  final value = slug.toLowerCase();
  if (value.contains('neck')) return PhosphorIconsRegular.headphones;
  if (value.contains('power') || value.contains('bank')) return PhosphorIconsRegular.batteryHigh;
  if (value.contains('adapt') || value.contains('charg')) return PhosphorIconsRegular.plug;
  if (value.contains('tws') || value.contains('ear')) return PhosphorIconsRegular.headphones;
  return PhosphorIconsRegular.tag;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppPallete.onDark : AppPallete.ink;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppPallete.accent : AppPallete.surface,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: const Color(0xFFE3E8F2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.label.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.title,
    required this.count,
    required this.filtered,
    required this.onFilter,
    required this.onSort,
    required this.ordering,
  });

  final String title;
  final int? count;
  final bool filtered;
  final VoidCallback onFilter;
  final ValueChanged<String?> onSort;
  final String? ordering;

  @override
  Widget build(BuildContext context) {
    final countLabel = count == null
        ? ''
        : count == 1
            ? '1 product'
            : '$count products';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMedium.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
                if (countLabel.isNotEmpty)
                  Text(countLabel, style: AppTypography.bodySmall.copyWith(fontSize: 12)),
              ],
            ),
          ),
          _HeaderAction(icon: PhosphorIconsRegular.funnel, label: 'Filter', marked: filtered, onTap: onFilter),
          const SizedBox(width: 6),
          _HeaderAction(
            icon: PhosphorIconsRegular.arrowsDownUp,
            label: 'Sort',
            marked: ordering != null,
            onTap: () async {
              final next = await showModalBottomSheet<String>(
                context: context,
                backgroundColor: AppPallete.surface,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
                builder: (context) => _SortSheet(ordering: ordering),
              );
              if (next == null) return;
              onSort(next == 'default' ? null : next);
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.label, required this.onTap, this.marked = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool marked;

  @override
  Widget build(BuildContext context) {
    final color = marked ? AppPallete.primary : AppPallete.inkSoft;
    return Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppPallete.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: marked ? AppPallete.primary : const Color(0xFFE3E8F2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: AppTypography.label.copyWith(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            const Icon(PhosphorIconsBold.caretDown, size: 10, color: AppPallete.textHint),
          ],
        ),
      ),
    );
  }
}

class _CatalogCard extends ConsumerWidget {
  const _CatalogCard({required this.product});

  final ProductSummary product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(isWishlistedProvider(product.id));
    final discount = product.discountPercentage;
    final compare = product.comparePrice;
    final saving = product.hasDiscount ? Formatters.decimal(compare) - Formatters.decimal(product.price) : Decimal.zero;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPallete.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F2)),
        boxShadow: const [BoxShadow(color: Color(0x0D172033), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: Stack(
                children: [
                  Pressable(
                    semanticLabel: product.name,
                    onTap: () => context.push(Routes.product(product.slug)),
                      child: AppNetworkImage(
                      url: product.primaryImage,
                      fit: BoxFit.contain,
                      borderRadius: BorderRadius.circular(12),
                      background: const Color(0xFFF7F9FC),
                    ),
                  ),
                  if (discount > 0)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(color: AppPallete.accent, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          '-$discount%',
                          textScaler: TextScaler.noScaling,
                          style: AppTypography.label.copyWith(color: AppPallete.onDark, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Pressable(
                      semanticLabel: saved ? 'Remove from wishlist' : 'Save to wishlist',
                      onTap: () {
                        final added = ref.read(wishlistNotifierProvider.notifier).toggle(product.id);
                        if (added == null) showToast(context, 'Your wishlist is full.', kind: ToastKind.error);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(color: AppPallete.surface, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Icon(
                          saved ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                          size: 16,
                          color: saved ? AppPallete.sale : AppPallete.heartIdle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Pressable(
              onTap: () => context.push(Routes.product(product.slug)),
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleSmall.copyWith(fontSize: 16, height: 1.25, fontWeight: FontWeight.w800),
              ),
            ),
            if (product.sku.isNotEmpty)
              Text(product.sku, style: AppTypography.bodySmall.copyWith(fontSize: 12, color: AppPallete.textSecondary)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  Formatters.money(product.price),
                  style: AppTypography.price.copyWith(color: AppPallete.ink, fontSize: 18),
                ),
                if (product.hasDiscount) ...[
                  const SizedBox(width: 8),
                  Text(Formatters.money(compare), style: AppTypography.strike.copyWith(fontSize: 13)),
                ],
              ],
            ),
            if (saving > Decimal.zero)
              Text(
                'Save ${Formatters.money(saving)}',
                style: AppTypography.label.copyWith(color: AppPallete.success, fontWeight: FontWeight.w700, fontSize: 12),
              )
            else if (product.isOutOfStock)
              Text('Out of stock', style: AppTypography.label.copyWith(color: AppPallete.danger, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                _IconButton(
                  icon: PhosphorIconsRegular.arrowsLeftRight,
                  label: 'Compare',
                  onTap: () => showToast(context, 'Compare is coming soon'),
                ),
                const SizedBox(width: 8),
                _IconButton(
                  icon: PhosphorIconsRegular.eye,
                  label: 'Quick view',
                  onTap: () => _showQuickView(context, ref, product),
                ),
                const SizedBox(width: 8),
                Expanded(child: _AddButton(product: product)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppPallete.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE4E9F2)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: AppPallete.inkSoft),
      ),
    );
  }
}

class _AddButton extends ConsumerStatefulWidget {
  const _AddButton({required this.product});

  final ProductSummary product;

  @override
  ConsumerState<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends ConsumerState<_AddButton> {
  var _busy = false;

  Future<void> _add() async {
    if (_busy) return;
    setState(() => _busy = true);
    await quickAddToCart(context, ref, widget.product);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.product.isOutOfStock;
    return Pressable(
      semanticLabel: disabled ? 'Out of stock' : 'Add to cart',
      onTap: disabled ? null : _add,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFC5CDD8) : AppPallete.accent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppPallete.onDark),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(PhosphorIconsFill.shoppingCart, size: 15, color: AppPallete.onDark),
                  const SizedBox(width: 6),
                  Text(
                    disabled ? 'Out of stock' : 'Add to Cart',
                    style: AppTypography.label.copyWith(color: AppPallete.onDark, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
      ),
    );
  }
}

void _showQuickView(BuildContext context, WidgetRef ref, ProductSummary product) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppPallete.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppPallete.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.4,
            child: AppNetworkImage(url: product.primaryImage, borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 12),
          Text(product.name, style: AppTypography.titleMedium),
          if (product.sku.isNotEmpty) Text(product.sku, style: AppTypography.bodySmall),
          if (product.shortDescription.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(product.shortDescription, style: AppTypography.bodyLarge),
          ],
          const SizedBox(height: 8),
          Text(Formatters.money(product.price), style: AppTypography.price.copyWith(color: AppPallete.ink)),
          const SizedBox(height: 12),
          _AddButton(product: product),
        ],
      ),
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.onSale});

  final bool onSale;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late bool _sale = widget.onSale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Filter', style: AppTypography.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('On sale'),
            value: _sale,
            activeThumbColor: AppPallete.accent,
            onChanged: (value) => setState(() => _sale = value),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPallete.accent, foregroundColor: AppPallete.onDark),
            onPressed: () => Navigator.pop(context, _sale),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.ordering});

  final String? ordering;

  @override
  Widget build(BuildContext context) {
    const options = <(String, String)>[
      ('default', 'Recommended'),
      ('price', 'Price: low to high'),
      ('-price', 'Price: high to low'),
      ('-created_at', 'Newest'),
      ('name', 'Name'),
    ];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text('Sort', style: AppTypography.titleMedium),
          for (final option in options)
            ListTile(
              title: Text(option.$2),
              trailing: (ordering ?? 'default') == option.$1
                  ? const Icon(PhosphorIconsBold.check, color: AppPallete.accent)
                  : null,
              onTap: () => Navigator.pop(context, option.$1),
            ),
        ],
      ),
    );
  }
}
