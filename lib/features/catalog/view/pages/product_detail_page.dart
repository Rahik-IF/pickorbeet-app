import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/cart_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_spacing.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/core/widgets/app_header.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/core/widgets/price_text.dart';
import 'package:pickorbeet/core/widgets/quantity_stepper.dart';
import 'package:pickorbeet/core/widgets/section.dart';
import 'package:pickorbeet/core/widgets/skeleton.dart';
import 'package:pickorbeet/core/widgets/state_views.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/view/widgets/product_card.dart';
import 'package:pickorbeet/features/catalog/viewmodel/catalog_providers.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Gallery, options, and add to cart for one product.
class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.slug, this.heroTag});

  final String slug;

  /// Matches the product card image so the open transition can fly the photo.
  final String? heroTag;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  final _pages = PageController();
  final _optionsKey = GlobalKey();
  var _image = 0;
  var _quantity = 1;
  String? _size;
  String? _color;
  String? _preparedFor;
  var _adding = false;

  @override
  void didUpdateWidget(ProductDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug == widget.slug) return;
    _preparedFor = null;
    _size = null;
    _color = null;
    _quantity = 1;
    _image = 0;
    _adding = false;
    if (_pages.hasClients) _pages.jumpToPage(0);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Single-option products are preselected so they can go straight into the cart.
  void _prepare(ProductDetail detail) {
    if (_preparedFor == detail.summary.id) return;
    _preparedFor = detail.summary.id;
    final variants = detail.summary.variants;
    final sizes = _optionValues(variants, (variant) => variant.size);
    final colors = _optionValues(variants, (variant) => variant.color);
    _size = sizes.length == 1 ? sizes.single : null;
    _color = colors.length == 1 ? colors.single : null;
    _quantity = 1;
    _image = 0;
  }

  Future<void> _refresh() async {
    final current = ref.read(productDetailProvider(widget.slug)).valueOrNull;
    ref.invalidate(productDetailProvider(widget.slug));
    if (current != null) {
      ref.invalidate(
        relatedProductsProvider(
          productId: current.summary.id,
          categorySlug: current.categorySlug,
          subcategorySlug: current.subcategorySlug,
        ),
      );
    }
    try {
      await ref.read(productDetailProvider(widget.slug).future);
    } on Object {
      // The listener reports a failed refresh when the product is still on screen.
    }
  }

  void _showImage(int index) {
    if (_image == index) return;
    setState(() => _image = index);
    if (!_pages.hasClients) return;
    unawaited(
      _pages.animateToPage(
        index,
        duration: Motion.of(context, Motion.short),
        curve: Motion.emphasized,
      ),
    );
  }

  void _chooseSize(ProductDetail detail, String size) {
    if (_size == size) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _size = size;
      final colors = _optionValues(
        detail.summary.variants,
        (variant) => variant.color,
        size: size,
      );
      if (_color != null && colors.isNotEmpty && !colors.contains(_color)) {
        _color = colors.length == 1 ? colors.single : null;
      }
      _quantity = _clampQuantity(detail);
    });
  }

  void _chooseColor(ProductDetail detail, String color) {
    if (_color == color) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _color = color;
      final sizes = _optionValues(
        detail.summary.variants,
        (variant) => variant.size,
        color: color,
      );
      if (_size != null && sizes.isNotEmpty && !sizes.contains(_size)) {
        _size = sizes.length == 1 ? sizes.single : null;
      }
      _quantity = _clampQuantity(detail);
    });
  }

  int _clampQuantity(ProductDetail detail) {
    final cap = _stockCap(detail, size: _size, color: _color);
    if (_quantity < 1) return 1;
    if (_quantity > cap) return cap;
    return _quantity;
  }

  void _prompt(String message) {
    showToast(context, message, kind: ToastKind.error);
    final target = _optionsKey.currentContext;
    if (target == null) return;
    unawaited(
      Scrollable.ensureVisible(
        target,
        alignment: 0.2,
        duration: Motion.of(context, Motion.medium),
        curve: Motion.emphasized,
      ),
    );
  }

  Future<void> _add(ProductDetail detail) async {
    final action = _purchaseAction(detail, size: _size, color: _color);
    if (_adding || !action.canAdd) return;
    setState(() => _adding = true);
    unawaited(HapticFeedback.lightImpact());
    try {
      final variant = _selectedVariant(detail, size: _size, color: _color);
      final result = await ref
          .read(cartNotifierProvider.notifier)
          .add(
            CartLine(
              productId: detail.summary.id,
              quantity: _quantity,
              variantId: variant?.id,
            ),
          );
      if (!mounted) return;
      result.fold(
        (failure) => showToast(context, failure.message, kind: ToastKind.error),
        (_) => showToast(
          context,
          'Added to cart',
          kind: ToastKind.success,
          actionLabel: 'View cart',
          onAction: () => context.go(Routes.cart),
        ),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _openZoom(List<String> urls) {
    final initial = _image.clamp(0, urls.length - 1).toInt();
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        transitionDuration: Motion.of(context, Motion.medium),
        reverseTransitionDuration: Motion.of(context, Motion.short),
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: _ZoomGallery(urls: urls, initial: initial),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(productDetailProvider(widget.slug), (previous, next) {
      if (next.hasError && next.hasValue && !next.isLoading) {
        showToast(
          context,
          "Couldn't refresh. Showing what we had.",
          kind: ToastKind.error,
        );
      }
    });

    final async = ref.watch(productDetailProvider(widget.slug));
    final detail = async.valueOrNull;
    return Scaffold(
      backgroundColor: AppPallete.background,
      body: Column(
        children: [
          const DetailHeader(),
          Expanded(child: detail == null ? _status(async) : _loaded(detail)),
        ],
      ),
    );
  }

  Widget _status(AsyncValue<ProductDetail> async) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppPallete.primary,
      backgroundColor: AppPallete.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (async.hasError)
                SizedBox(
                  height: constraints.maxHeight,
                  child: _failure(async.error!),
                )
              else
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    12,
                    AppSpacing.page,
                    16,
                  ),
                  child: _SkeletonBody(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _failure(Object error) {
    final failure = error is AppFailure
        ? error
        : AppFailure.fromException(error);
    if (failure.kind == FailureKind.notFound) {
      return EmptyState(
        icon: PhosphorIconsRegular.package,
        title: 'Product not found',
        message: 'This product is unavailable or the link is incorrect.',
        actionLabel: 'Browse products',
        onAction: () => context.go(Routes.products),
      );
    }
    return ErrorState(
      failure: failure,
      onRetry: () => ref.invalidate(productDetailProvider(widget.slug)),
    );
  }

  Widget _loaded(ProductDetail detail) {
    _prepare(detail);
    final about = _aboutCopy(detail);
    final specs = _specRows(detail);
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: AppPallete.primary,
            backgroundColor: AppPallete.surface,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                12,
                AppSpacing.page,
                16,
              ),
              children: [
                _gallery(detail),
                const SizedBox(height: 10),
                _summary(detail),
                if (about != null || specs.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _about(about, specs),
                ],
                const SizedBox(height: 10),
                const _Promises(),
                _RelatedRail(detail: detail),
              ],
            ),
          ),
        ),
        _bar(detail),
      ],
    );
  }

  Widget _gallery(ProductDetail detail) {
    final urls = detail.gallery;
    if (urls.isNotEmpty && _image >= urls.length) _image = urls.length - 1;
    final photos = _photos(urls);
    return _Sheet.bare(
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ColoredBox(
              color: AppPallete.productTile,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: detail.summary.isOutOfStock
                        ? Opacity(opacity: 0.55, child: photos)
                        : photos,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: WishlistHeart(
                      product: detail.summary,
                      diameter: 32,
                      iconSize: 16,
                      shadow: true,
                    ),
                  ),
                  if (urls.length > 1)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: _CountPill(index: _image, count: urls.length),
                    ),
                ],
              ),
            ),
          ),
          if (urls.length > 1) _thumbs(urls),
        ],
      ),
    );
  }

  Widget _photos(List<String> urls) {
    if (urls.isEmpty) return _hero(const _EmptyPhoto(), enabled: true);
    if (urls.length == 1) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_openZoom(urls)),
        child: _hero(_photo(urls.first), enabled: true),
      );
    }
    return PageView.builder(
      controller: _pages,
      itemCount: urls.length,
      onPageChanged: (value) {
        if (_image == value) return;
        setState(() => _image = value);
      },
      itemBuilder: (context, page) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_openZoom(urls)),
        child: _hero(_photo(urls[page]), enabled: page == 0),
      ),
    );
  }

  Widget _hero(Widget child, {required bool enabled}) {
    final tag = widget.heroTag;
    if (tag == null || !enabled) return child;
    return Hero(tag: tag, child: child);
  }

  Widget _photo(String url) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: AppNetworkImage(
        url: url,
        fit: BoxFit.contain,
        background: Colors.transparent,
      ),
    );
  }

  Widget _thumbs(List<String> urls) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, page) {
          final selected = page == _image;
          return Pressable(
            semanticLabel: 'Photo ${page + 1}',
            onTap: () => _showImage(page),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppPallete.primary : Colors.transparent,
                  width: 1.6,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: AppNetworkImage(
                    url: urls[page],
                    borderRadius: BorderRadius.circular(7),
                    background: AppPallete.productTile,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _summary(ProductDetail detail) {
    final product = detail.summary;
    final category = _categoryLabel(detail);
    final target = _categoryTarget(detail);
    final price = _unitPrice(detail, size: _size, color: _color);
    final percent = _discountPercent(price, product.comparePrice);
    final stock = _availability(detail, size: _size, color: _color);
    final sizes = _optionValues(product.variants, (variant) => variant.size);
    final colors = _optionValues(product.variants, (variant) => variant.color);
    final blurb = product.shortDescription.trim();

    return _Sheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (category.isNotEmpty)
            Pressable(
              onTap: target == null ? null : () => context.push(target),
              child: Text(
                category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  color: AppPallete.primaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          if (category.isNotEmpty) const SizedBox(height: 6),
          Semantics(
            header: true,
            child: Text(
              product.name,
              style: AppTypography.titleLarge.copyWith(
                fontSize: 20,
                height: 1.25,
              ),
            ),
          ),
          if (product.rating != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  PhosphorIconsFill.star,
                  size: 13,
                  color: AppPallete.star,
                ),
                const SizedBox(width: 4),
                Text(
                  _ratingLabel(product),
                  style: AppTypography.label.copyWith(
                    fontSize: 12,
                    color: AppPallete.inkSoft,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: PriceText(
                  price: price,
                  comparePrice: product.comparePrice,
                  style: AppTypography.price.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  strikeStyle: AppTypography.strike.copyWith(fontSize: 13),
                ),
              ),
              if (percent > 0) ...[
                const SizedBox(width: 8),
                DiscountBadge(
                  percent: percent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  radius: 6,
                  textStyle: AppTypography.labelSmall.copyWith(
                    color: AppPallete.onDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: stock.$2,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 7, height: 7),
              ),
              const SizedBox(width: 6),
              Text(
                stock.$1,
                style: AppTypography.label.copyWith(
                  color: stock.$2,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (blurb.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              blurb,
              style: AppTypography.bodyLarge.copyWith(
                fontSize: 13,
                height: 1.45,
                color: AppPallete.textSecondary,
              ),
            ),
          ],
          if (sizes.isNotEmpty || colors.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1, color: AppPallete.divider),
            const SizedBox(height: 14),
            KeyedSubtree(
              key: _optionsKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sizes.isNotEmpty)
                    _choices(
                      title: 'Size',
                      values: sizes,
                      selected: _size,
                      available: (value) =>
                          _optionInStock(product.variants, size: value),
                      onSelected: (value) => _chooseSize(detail, value),
                    ),
                  if (sizes.isNotEmpty && colors.isNotEmpty)
                    const SizedBox(height: 14),
                  if (colors.isNotEmpty)
                    _choices(
                      title: 'Color',
                      values: colors,
                      selected: _color,
                      available: (value) =>
                          _optionInStock(product.variants, color: value),
                      onSelected: (value) => _chooseColor(detail, value),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _choices({
    required String title,
    required List<String> values,
    required String? selected,
    required bool Function(String value) available,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values)
              _ChoiceChip(
                label: value,
                selected: value == selected,
                available: available(value),
                onTap: () => onSelected(value),
              ),
          ],
        ),
      ],
    );
  }

  Widget _about(String? copy, List<(String, String)> specs) {
    return _Sheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (copy != null) ...[
            const SectionHeader(title: 'Product details'),
            const SizedBox(height: 8),
            _ExpandableText(copy),
          ],
          if (specs.isNotEmpty) ...[
            if (copy != null) const SizedBox(height: 16),
            const SectionHeader(title: 'Specifications'),
            const SizedBox(height: 4),
            for (final row in specs) _SpecRow(label: row.$1, value: row.$2),
          ],
        ],
      ),
    );
  }

  Widget _bar(ProductDetail detail) {
    final action = _purchaseAction(detail, size: _size, color: _color);
    final showQuantity = action.canAdd || action.prompt != null;
    final VoidCallback? onPressed;
    if (action.prompt != null) {
      final prompt = action.prompt!;
      onPressed = () => _prompt(prompt);
    } else if (action.canAdd) {
      onPressed = () => unawaited(_add(detail));
    } else {
      onPressed = null;
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppPallete.surface,
        border: Border(top: BorderSide(color: AppPallete.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              if (showQuantity) ...[
                QuantityStepper(
                  value: _quantity,
                  max: _stockCap(detail, size: _size, color: _color),
                  enabled: !_adding,
                  height: 40,
                  buttonWidth: 34,
                  valueWidth: 30,
                  radius: 10,
                  onChanged: (value) => setState(() => _quantity = value),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: AppButton(
                  label: action.label,
                  icon: action.canAdd
                      ? PhosphorIconsBold.shoppingCartSimple
                      : null,
                  loading: _adding,
                  height: 48,
                  onPressed: onPressed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child, this.padding = const EdgeInsets.all(14)});

  const _Sheet.bare({required this.child}) : padding = null;

  final Widget child;
  final EdgeInsetsGeometry? padding;

  static const _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final inset = padding;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPallete.surface,
        borderRadius: _radius,
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: inset == null ? child : Padding(padding: inset, child: child),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppPallete.onDark
        : available
        ? AppPallete.ink
        : AppPallete.textHint;
    return Pressable(
      semanticLabel: available ? label : '$label, out of stock',
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        curve: Motion.emphasized,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppPallete.primary : AppPallete.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppPallete.primary : AppPallete.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: foreground,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            decoration: available ? null : TextDecoration.lineThrough,
            decorationColor: foreground,
          ),
        ),
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  var _expanded = false;
  static const _limit = 280;

  @override
  void didUpdateWidget(_ExpandableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final long = text.length > _limit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          long && !_expanded ? _cut(text) : text,
          style: AppTypography.bodyLarge.copyWith(
            fontSize: 13,
            height: 1.5,
            color: AppPallete.inkSoft,
          ),
        ),
        if (long)
          Pressable(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _expanded ? 'Show less' : 'Read more',
                style: AppTypography.label.copyWith(
                  color: AppPallete.primaryText,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _cut(String text) {
    final slice = text.substring(0, _limit);
    final breakAt = slice.lastIndexOf(' ');
    final end = breakAt > 180 ? breakAt : _limit;
    return '${slice.substring(0, end).trimRight()}…';
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppPallete.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                color: AppPallete.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Promises extends StatelessWidget {
  const _Promises();

  static const _items = <(IconData, String)>[
    (PhosphorIconsRegular.truck, 'Fast delivery'),
    (PhosphorIconsRegular.arrowCounterClockwise, 'Easy returns'),
    (PhosphorIconsRegular.shieldCheck, 'Secure payment'),
  ];

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0)
              const SizedBox(
                width: 1,
                height: 36,
                child: ColoredBox(color: AppPallete.divider),
              ),
            Expanded(
              child: _PromiseTile(icon: _items[i].$1, label: _items[i].$2),
            ),
          ],
        ],
      ),
    );
  }
}

class _PromiseTile extends StatelessWidget {
  const _PromiseTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppPallete.benefitIcon),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.label.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppPallete.inkSoft,
          ),
        ),
      ],
    );
  }
}

class _RelatedRail extends ConsumerWidget {
  const _RelatedRail({required this.detail});

  final ProductDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = ref.watch(
      relatedProductsProvider(
        productId: detail.summary.id,
        categorySlug: detail.categorySlug,
        subcategorySlug: detail.subcategorySlug,
      ),
    );
    return related.when(
      loading: () => const _RelatedSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        final target = _categoryTarget(detail);
        const width = 140.0;
        final height = ProductCard.heightFor(
          width,
          MediaQuery.textScalerOf(context),
        );
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _Sheet.bare(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
                  child: SectionHeader(
                    title: 'You may also like',
                    onViewAll: target == null
                        ? null
                        : () => context.push(target),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: height,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    physics: const BouncingScrollPhysics(),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => ProductCard(
                      product: products[index],
                      width: width,
                      heroScope: 'related-${detail.summary.id}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RelatedSkeleton extends StatelessWidget {
  const _RelatedSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(child: _SkeletonBlock()),
          SizedBox(width: 10),
          Expanded(child: _SkeletonBlock()),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: AppPallete.skeleton,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: SizedBox(height: 160),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPallete.ink.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '${index + 1} / $count',
          style: AppTypography.caption.copyWith(
            color: AppPallete.onDark,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        PhosphorIconsLight.image,
        size: 42,
        color: AppPallete.textHint,
      ),
    );
  }
}

class _ZoomGallery extends StatefulWidget {
  const _ZoomGallery({required this.urls, required this.initial});

  final List<String> urls;
  final int initial;

  @override
  State<_ZoomGallery> createState() => _ZoomGalleryState();
}

class _ZoomGalleryState extends State<_ZoomGallery> {
  late final PageController _controller = PageController(
    initialPage: widget.initial,
  );
  late int _index = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnDark,
      child: Scaffold(
        backgroundColor: AppPallete.ink,
        body: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (_, page) => LayoutBuilder(
                builder: (context, constraints) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: AppNetworkImage(
                      url: widget.urls[page],
                      fit: BoxFit.contain,
                      background: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.urls.length > 1)
              Positioned(
                top: top + 20,
                left: 60,
                right: 60,
                child: IgnorePointer(
                  child: Text(
                    '${_index + 1} / ${widget.urls.length}',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppPallete.onDark,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: top + 8,
              left: 8,
              child: Pressable(
                semanticLabel: 'Close',
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    PhosphorIconsRegular.x,
                    color: AppPallete.onDark,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    return const AppSkeletonTheme(
      child: Skeletonizer(
        child: Column(
          children: [
            SkeletonBox(height: 320, radius: 16),
            SizedBox(height: 10),
            SkeletonBox(height: 150, radius: 16),
            SizedBox(height: 10),
            SkeletonBox(height: 72, radius: 16),
          ],
        ),
      ),
    );
  }
}

List<String> _optionValues(
  List<ProductVariant> variants,
  String? Function(ProductVariant variant) pick, {
  String? size,
  String? color,
}) {
  final values = <String>[];
  for (final variant in variants) {
    if (!variant.isActive) continue;
    if (size != null && variant.size != size) continue;
    if (color != null && variant.color != color) continue;
    final value = pick(variant)?.trim();
    if (value == null || value.isEmpty || values.contains(value)) continue;
    values.add(value);
  }
  return values;
}

bool _optionInStock(
  List<ProductVariant> variants, {
  String? size,
  String? color,
}) {
  for (final variant in variants) {
    if (!variant.isActive || !variant.inStock) continue;
    if (size != null && variant.size != size) continue;
    if (color != null && variant.color != color) continue;
    return true;
  }
  return false;
}

bool _hasOptions(List<ProductVariant> variants) =>
    _optionValues(variants, (variant) => variant.size).isNotEmpty ||
    _optionValues(variants, (variant) => variant.color).isNotEmpty;

ProductVariant? _selectedVariant(
  ProductDetail detail, {
  String? size,
  String? color,
}) {
  final active = [
    for (final variant in detail.summary.variants)
      if (variant.isActive) variant,
  ];
  if (active.isEmpty) return null;
  final sizes = _optionValues(active, (variant) => variant.size);
  final colors = _optionValues(active, (variant) => variant.color);
  if (sizes.isEmpty && colors.isEmpty) {
    for (final variant in active) {
      if (variant.inStock) return variant;
    }
    return active.first;
  }
  if (sizes.isNotEmpty && size == null) return null;
  if (colors.isNotEmpty && color == null) return null;
  ProductVariant? fallback;
  for (final variant in active) {
    final sizeOk = sizes.isEmpty || variant.size == size;
    final colorOk = colors.isEmpty || variant.color == color;
    if (!sizeOk || !colorOk) continue;
    fallback ??= variant;
    if (variant.inStock) return variant;
  }
  return fallback;
}

String _unitPrice(ProductDetail detail, {String? size, String? color}) {
  final variant = _selectedVariant(detail, size: size, color: color);
  if (variant == null) return detail.summary.price;
  if (Formatters.decimal(variant.price).toDouble() <= 0) {
    return detail.summary.price;
  }
  return variant.price;
}

int _discountPercent(String price, String? compare) {
  final current = Formatters.decimal(price).toDouble();
  final was = Formatters.decimal(compare).toDouble();
  if (was <= current || was <= 0) return 0;
  return ((was - current) / was * 100).round();
}

int _stockCap(ProductDetail detail, {String? size, String? color}) {
  final variant = _selectedVariant(detail, size: size, color: color);
  final int stock;
  if (variant != null) {
    stock = variant.stockQuantity;
  } else if (_hasOptions(detail.summary.variants)) {
    stock = 99;
  } else {
    stock = detail.summary.stockQuantity;
  }
  if (stock <= 0) return 1;
  if (stock > 99) return 99;
  return stock;
}

(String, Color) _availability(
  ProductDetail detail, {
  String? size,
  String? color,
}) {
  final variant = _selectedVariant(detail, size: size, color: color);
  if (variant != null) {
    if (!variant.inStock) return ('Out of stock', AppPallete.danger);
    if (variant.isLowStock) {
      return ('Only ${variant.stockQuantity} left', AppPallete.warning);
    }
    return ('In stock', AppPallete.success);
  }
  final product = detail.summary;
  if (product.isOutOfStock) return ('Out of stock', AppPallete.danger);
  if (!_hasOptions(product.variants) &&
      product.isLowStock &&
      product.stockQuantity > 0) {
    return ('Only ${product.stockQuantity} left', AppPallete.warning);
  }
  return ('In stock', AppPallete.success);
}

({String label, bool canAdd, String? prompt}) _purchaseAction(
  ProductDetail detail, {
  String? size,
  String? color,
}) {
  final variants = detail.summary.variants;
  final sizes = _optionValues(variants, (variant) => variant.size);
  final colors = _optionValues(variants, (variant) => variant.color);
  if (sizes.isNotEmpty && size == null) {
    return (label: 'Select a size', canAdd: false, prompt: 'Choose a size');
  }
  if (colors.isNotEmpty && color == null) {
    return (label: 'Select a color', canAdd: false, prompt: 'Choose a color');
  }
  final variant = _selectedVariant(detail, size: size, color: color);
  final out = variant != null ? !variant.inStock : detail.summary.isOutOfStock;
  if (out) return (label: 'Out of stock', canAdd: false, prompt: null);
  return (label: 'Add to cart', canAdd: true, prompt: null);
}

String _categoryLabel(ProductDetail detail) {
  final parts = <String?>[
    detail.summary.categoryName,
    detail.summary.subcategoryName,
  ];
  return parts
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(' · ');
}

String? _categoryTarget(ProductDetail detail) {
  if (detail.categorySlug.isEmpty) return null;
  final subcategory = detail.subcategorySlug;
  if (subcategory != null && subcategory.isNotEmpty) {
    return Routes.productList(
      title: detail.summary.subcategoryName,
      categorySlug: detail.categorySlug,
      subcategorySlug: subcategory,
    );
  }
  return Routes.category(detail.categorySlug);
}

String _cleanSpec(String value) => value
    .split('·')
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .join(' · ');

List<(String, String)> _specRows(ProductDetail detail) {
  final rows = <(String, String)>[
    if (detail.summary.sku.trim().isNotEmpty)
      ('SKU', detail.summary.sku.trim()),
  ];
  for (final row in detail.specs) {
    if (row.$1 == 'Category') continue;
    final value = _cleanSpec(row.$2);
    if (value.isEmpty) continue;
    rows.add((row.$1, value));
  }
  return rows;
}

String? _aboutCopy(ProductDetail detail) {
  final copy = detail.plainDescription.trim();
  if (copy.isEmpty) return null;
  if (copy == detail.summary.shortDescription.trim()) return null;
  return copy;
}

String _ratingLabel(ProductSummary product) {
  final score = product.rating!.toStringAsFixed(1);
  final reviews = product.reviewCount;
  if (reviews == null) return score;
  final noun = reviews == 1 ? 'review' : 'reviews';
  return '$score ($reviews $noun)';
}
