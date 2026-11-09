import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Either;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/cart_notifier.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_spacing.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/core/widgets/brand_lockup.dart';
import 'package:pickorbeet/core/widgets/fullscreen_image_gallery.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';
import 'package:pickorbeet/core/widgets/quantity_stepper.dart';
import 'package:pickorbeet/core/widgets/section.dart';
import 'package:pickorbeet/core/widgets/skeleton.dart';
import 'package:pickorbeet/core/widgets/state_views.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/product_gallery.dart';
import 'package:pickorbeet/features/catalog/repositories/catalog_repository.dart';
import 'package:pickorbeet/features/catalog/view/widgets/product_card.dart';
import 'package:pickorbeet/features/catalog/viewmodel/catalog_providers.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  final _picked = <String, String>{};
  String? _preparedFor;
  var _adding = false;
  var _buying = false;
  var _justAdded = false;
  Timer? _addedTimer;
  var _canReview = false;
  ProductReview? _mineReview;
  String? _reviewMetaSlug;

  @override
  void didUpdateWidget(ProductDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug == widget.slug) return;
    _preparedFor = null;
    _picked.clear();
    _quantity = 1;
    _image = 0;
    _adding = false;
    _buying = false;
    _justAdded = false;
    _canReview = false;
    _mineReview = null;
    _reviewMetaSlug = null;
    _addedTimer?.cancel();
    if (_pages.hasClients) _pages.jumpToPage(0);
  }

  @override
  void dispose() {
    _addedTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  /// Single-option products are preselected so they can go straight into the cart.
  void _prepare(ProductDetail detail) {
    if (_preparedFor == detail.summary.id) return;
    _preparedFor = detail.summary.id;
    _picked.clear();
    for (final group in _groups(detail)) {
      final labels = _choiceLabels(detail, group, _picked);
      if (labels.length == 1) _picked[group.name] = labels.single;
    }
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

  void _choose(ProductDetail detail, String name, String label) {
    if (_picked[name] == label) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _picked[name] = label;
      for (final group in _groups(detail)) {
        if (group.name == name) continue;
        final labels = _choiceLabels(detail, group, _picked);
        final current = _picked[group.name];
        if (current != null && !labels.contains(current)) {
          if (labels.length == 1) {
            _picked[group.name] = labels.single;
          } else {
            _picked.remove(group.name);
          }
        }
      }
      _quantity = _clampQuantity(detail);
      _image = 0;
    });
    if (_pages.hasClients) _pages.jumpToPage(0);
  }

  int _clampQuantity(ProductDetail detail) {
    final cap = _stockCap(detail, _picked);
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

  Future<void> _add(ProductDetail detail, {bool checkout = false}) async {
    final action = _purchaseAction(detail, _picked);
    if (_adding || _buying) return;
    if (action.prompt != null) {
      _prompt(action.prompt!);
      return;
    }
    if (!action.canAdd) return;
    setState(() {
      if (checkout) {
        _buying = true;
      } else {
        _adding = true;
      }
    });
    unawaited(HapticFeedback.lightImpact());
    try {
      final variant = _selectedVariant(detail, _picked);
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
        (_) {
          if (checkout) {
            context.push(Routes.checkout);
            return;
          }
          setState(() => _justAdded = true);
          showToast(
            context,
            'Added to cart',
            kind: ToastKind.success,
            actionLabel: 'View cart',
            onAction: () => context.go(Routes.cart),
          );
          _addedTimer?.cancel();
          _addedTimer = Timer(const Duration(milliseconds: 1400), () {
            if (mounted) setState(() => _justAdded = false);
          });
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _adding = false;
          _buying = false;
        });
      }
    }
  }

  Future<void> _share(ProductDetail detail) async {
    final link = 'https://www.pickorbeet.com/product/${detail.summary.slug}';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    showToast(context, 'Link copied');
  }

  void _loadReviewMeta(String slug) {
    if (_reviewMetaSlug == slug) return;
    _reviewMetaSlug = slug;
    unawaited(() async {
      final result = await ref.read(catalogRepositoryProvider).reviews(slug);
      if (!mounted || _reviewMetaSlug != slug) return;
      result.fold((_) {}, (payload) {
        setState(() {
          _canReview = payload.canReview;
          _mineReview = payload.mine;
        });
      });
    }());
  }

  void _writeReview() {
    final signedIn = ref.read(sessionNotifierProvider) == SessionStatus.signedIn;
    if (!signedIn) {
      context.push(Routes.loginFrom(Routes.product(widget.slug)));
      return;
    }
    if (!_canReview && _mineReview == null) {
      showToast(context, 'Available after delivery');
      return;
    }
    unawaited(_openReview());
  }

  Future<void> _openReview() async {
    final slug = widget.slug;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPallete.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
      builder: (context) => _ReviewSheet(
        mine: _mineReview,
        canReview: _canReview,
        onSubmit: (rating, comment, images) => ref.read(catalogRepositoryProvider).saveReview(
          slug,
          rating: rating,
          comment: comment,
          images: images,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    _reviewMetaSlug = null;
    _loadReviewMeta(slug);
    ref.invalidate(productDetailProvider(slug));
    showToast(context, 'Review saved', kind: ToastKind.success);
  }

  Future<void> _openZoom(List<String> urls) {
    final initial = urls.isEmpty ? 0 : _image.clamp(0, urls.length - 1).toInt();
    return openFullscreenImages(context, urls: urls, initial: initial);
  }

  List<GallerySlide> _media(ProductDetail detail) {
    final chosen = _selectedVariant(detail, _picked);
    return galleryMediaForSelection(
      detail: detail,
      chosen: chosen,
      picked: _picked,
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
      backgroundColor: _DetailPalette.canvas,
      body: Column(
        children: [
          const _ProductTopBar(),
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
    if (_reviewMetaSlug != detail.summary.slug) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadReviewMeta(detail.summary.slug);
      });
    }
    final about = _aboutCopy(detail);
    final specs = _specRows(detail);
    final blurb = detail.summary.shortDescription.trim();
    final warranty = detail.summary.warrantyPeriod.trim();
    final signedIn = ref.watch(sessionNotifierProvider) == SessionStatus.signedIn;
    return RefreshIndicator(
      onRefresh: () async {
        _reviewMetaSlug = null;
        await _refresh();
        _loadReviewMeta(detail.summary.slug);
      },
      color: AppPallete.primary,
      backgroundColor: AppPallete.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _RiseIn(child: _gallery(detail)),
          const SizedBox(height: 14),
          _RiseIn(
            delay: const Duration(milliseconds: 60),
            child: _summary(detail, signedIn: signedIn),
          ),
          const SizedBox(height: 16),
          _RiseIn(
            delay: const Duration(milliseconds: 100),
            child: _ProductInfoPanel(
              slug: detail.summary.slug,
              blurb: blurb,
              copy: about,
              specs: specs,
              warranty: warranty,
              reviewCount: detail.summary.reviewCount ?? 0,
              canReview: _canReview,
              mine: _mineReview,
              onReviewSaved: () {
                _reviewMetaSlug = null;
                _loadReviewMeta(detail.summary.slug);
                ref.invalidate(productDetailProvider(widget.slug));
              },
            ),
          ),
          _RelatedRail(detail: detail),
        ],
      ),
    );
  }

  Widget _gallery(ProductDetail detail) {
    final slides = _media(detail);
    if (slides.isNotEmpty && _image >= slides.length) _image = slides.length - 1;
    final photos = _photos(slides);
    final percent = _discountPercent(detail.summary.price, detail.summary.comparePrice);
    final badge = officialBadgeStyleOf(ref);
    final many = slides.length > 1;
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppPallete.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x0D172033), blurRadius: 24, offset: Offset(0, 8)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1.42,
                child: ColoredBox(
                  color: const Color(0xFFF7F9FC),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: detail.summary.isOutOfStock ? Opacity(opacity: 0.55, child: photos) : photos,
                      ),
                      if (detail.summary.isOfficial)
                        OfficialMark(style: badge, inset: 10, scale: badge.scaleFor(1)),
                      if (percent > 0)
                        Positioned(
                          top: detail.summary.isOfficial && badge.position == 'top-left' ? badge.dropFor(46) : 10,
                          left: 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _DetailPalette.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              child: Text(
                                '-$percent%',
                                style: AppTypography.label.copyWith(
                                  color: AppPallete.onDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: detail.summary.isOfficial && badge.position == 'top-right' ? badge.dropFor(48) : 6,
                        right: 6,
                        child: WishlistHeart(product: detail.summary, diameter: 36, iconSize: 18, shadow: true),
                      ),
                      if (many) ...[
                        Positioned(
                          left: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _GalleryArrow(
                              icon: PhosphorIconsBold.caretLeft,
                              label: 'Previous media',
                              onTap: () => _showImage((_image - 1 + slides.length) % slides.length),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _GalleryArrow(
                              icon: PhosphorIconsBold.caretRight,
                              label: 'Next media',
                              onTap: () => _showImage((_image + 1) % slides.length),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: _CountPill(index: _image, count: slides.length),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (many) ...[
          const SizedBox(height: 10),
          _thumbs(slides),
        ],
      ],
    );
  }

  Widget _photos(List<GallerySlide> slides) {
    if (slides.isEmpty) return _hero(const _EmptyPhoto(), enabled: true);
    if (slides.length == 1) {
      return _slide(slides.first, hero: true, zoomUrls: _imageUrls(slides));
    }
    return PageView.builder(
      controller: _pages,
      itemCount: slides.length,
      onPageChanged: (value) {
        if (_image == value) return;
        setState(() => _image = value);
      },
      itemBuilder: (context, page) => _slide(
        slides[page],
        hero: page == 0,
        zoomUrls: _imageUrls(slides),
      ),
    );
  }

  List<String> _imageUrls(List<GallerySlide> slides) => [
    for (final slide in slides)
      if (slide is GalleryImageSlide && slide.image.image.isNotEmpty) slide.image.image,
  ];

  Widget _slide(GallerySlide slide, {required bool hero, required List<String> zoomUrls}) {
    if (slide is GalleryVideoSlide) {
      return _VideoSlide(video: slide.video);
    }
    final image = (slide as GalleryImageSlide).image;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(_openZoom(zoomUrls)),
      child: _hero(_photo(image.image), enabled: hero),
    );
  }

  Widget _hero(Widget child, {required bool enabled}) {
    final tag = widget.heroTag;
    if (tag == null || !enabled) return child;
    return Hero(tag: tag, child: child);
  }

  Widget _photo(String url) {
    return AppNetworkImage(
      url: url,
      fit: BoxFit.contain,
      background: const Color(0xFFF7F9FC),
    );
  }

  Widget _thumbs(List<GallerySlide> slides) {
    const gap = 8.0;
    const width = 72.0;
    const height = 64.0;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: slides.length,
        separatorBuilder: (_, _) => const SizedBox(width: gap),
        itemBuilder: (_, page) => _thumb(slides[page], page, width, height),
      ),
    );
  }

  Widget _thumb(GallerySlide slide, int page, double width, double height) {
    final selected = page == _image;
    final isVideo = slide is GalleryVideoSlide;
    final url = isVideo
        ? slide.video.thumbnailUrl
        : (slide as GalleryImageSlide).image.image;
    return Pressable(
      pressedScale: 0.97,
      semanticLabel: isVideo ? 'Video ${page + 1}' : 'Photo ${page + 1}',
      onTap: () => _showImage(page),
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        curve: Motion.emphasized,
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _DetailPalette.blue : Colors.transparent, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(
                url: url,
                fit: BoxFit.contain,
                borderRadius: BorderRadius.circular(8),
                background: const Color(0xFFF7F9FC),
              ),
              if (isVideo)
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xB3172033),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(PhosphorIconsFill.play, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(ProductDetail detail, {required bool signedIn}) {
    final product = detail.summary;
    final price = _unitPrice(detail, _picked);
    final percent = _discountPercent(price, product.comparePrice);
    final was = Formatters.decimal(product.comparePrice).toDouble();
    final now = Formatters.decimal(price).toDouble();
    final saved = percent > 0 ? (was - now).round() : 0;
    final stock = _availability(detail, _picked);
    final groups = _groups(detail);
    final action = _purchaseAction(detail, _picked);
    final busy = _adding || _buying;
    final canBuy = !busy && (action.canAdd || action.prompt != null);
    final cartLabel = _justAdded
        ? 'Added'
        : _adding
        ? 'Adding...'
        : (action.canAdd || action.prompt != null)
        ? 'Add to Cart'
        : action.label;
    final ready = stock.$1 == 'In stock';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  product.name,
                  style: AppTypography.titleLarge.copyWith(
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: _DetailPalette.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _RoundButton(
              label: 'Share',
              onTap: () => unawaited(_share(detail)),
              child: const Icon(PhosphorIconsRegular.shareNetwork, size: 20, color: _DetailPalette.blue),
            ),
          ],
        ),
        if (product.sku.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Product Code: ${product.sku.trim()}',
            style: AppTypography.bodyMedium.copyWith(fontSize: 13, color: _DetailPalette.muted, fontWeight: FontWeight.w500),
          ),
        ],
        const SizedBox(height: 8),
        _RatingLine(
          rating: product.rating ?? 0,
          count: product.reviewCount ?? 0,
          canWrite: !signedIn || _canReview || _mineReview != null,
          hasMine: _mineReview != null,
          onWrite: _writeReview,
        ),
        const SizedBox(height: 10),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              _taka(price),
              style: AppTypography.price.copyWith(fontSize: 30, fontWeight: FontWeight.w800, color: _DetailPalette.ink, height: 1),
            ),
            if (percent > 0)
              Text(
                _taka(product.comparePrice),
                style: AppTypography.strike.copyWith(fontSize: 16, color: _DetailPalette.strike, decorationColor: _DetailPalette.strike),
              ),
            if (percent > 0)
              DecoratedBox(
                decoration: BoxDecoration(color: _DetailPalette.saveSoft, borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text(
                    'You save ${_taka(saved)} ($percent%)',
                    style: AppTypography.label.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: _DetailPalette.save),
                  ),
                ),
              ),
          ],
        ),
        if (groups.isNotEmpty)
          KeyedSubtree(
            key: _optionsKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final group in groups) ...[
                  const SizedBox(height: 14),
                  if (group.kind == 'swatch') ...[
                    Text.rich(
                      TextSpan(
                        style: AppTypography.bodyLarge.copyWith(fontSize: 14, color: _DetailPalette.ink),
                        children: [
                          TextSpan(text: '${group.name}: '),
                          TextSpan(
                            text: _picked[group.name] ?? 'Select',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ColorSwatches(
                      colors: [
                        for (final value in group.values)
                          (label: value.label, hex: value.colorHex),
                      ],
                      selected: _picked[group.name],
                      onSelected: group.required ? (value) => _choose(detail, group.name, value) : null,
                    ),
                  ] else
                    _choices(
                      title: group.name,
                      values: [for (final value in group.values) value.label],
                      selected: _picked[group.name],
                      available: (value) => _valueInStock(detail, group, value, _picked),
                      onSelected: (value) => _choose(detail, group.name, value),
                    ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('Quantity:', style: AppTypography.bodyLarge.copyWith(fontSize: 14, color: _DetailPalette.ink)),
            const SizedBox(width: 10),
            QuantityStepper(
              value: _quantity,
              max: _stockCap(detail, _picked),
              enabled: !busy && stock.$1 != 'Out of stock',
              height: 36,
              buttonWidth: 34,
              valueWidth: 28,
              radius: 8,
              onChanged: (value) => setState(() => _quantity = value),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: stock.$2, shape: BoxShape.circle),
                    child: const SizedBox(width: 7, height: 7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      stock.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(color: stock.$2, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (ready) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Ready to ship',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(fontSize: 13, color: _DetailPalette.muted, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _PurchaseButton(
                label: cartLabel,
                icon: _justAdded ? PhosphorIconsBold.check : PhosphorIconsBold.shoppingCartSimple,
                filled: true,
                enabled: canBuy,
                onTap: () => unawaited(_add(detail)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PurchaseButton(
                label: _buying ? 'Please wait...' : 'Buy Now',
                icon: PhosphorIconsFill.lightning,
                filled: false,
                enabled: canBuy,
                onTap: () => unawaited(_add(detail, checkout: true)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _TrustRow(),
      ],
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
        Text.rich(
          TextSpan(
            style: AppTypography.bodyLarge.copyWith(fontSize: 14, color: _DetailPalette.ink),
            children: [
              TextSpan(text: '$title: '),
              TextSpan(
                text: selected ?? 'Select',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
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

}

enum _InfoTab { description, specifications, delivery, reviews }

class _ProductInfoPanel extends StatefulWidget {
  const _ProductInfoPanel({
    required this.slug,
    required this.blurb,
    required this.copy,
    required this.specs,
    required this.warranty,
    required this.reviewCount,
    required this.canReview,
    required this.mine,
    required this.onReviewSaved,
  });

  final String slug;
  final String blurb;
  final String? copy;
  final List<(String, String)> specs;
  final String warranty;
  final int reviewCount;
  final bool canReview;
  final ProductReview? mine;
  final VoidCallback onReviewSaved;

  @override
  State<_ProductInfoPanel> createState() => _ProductInfoPanelState();
}

class _ProductInfoPanelState extends State<_ProductInfoPanel> {
  _InfoTab _tab = _InfoTab.description;

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Product details'),
          const SizedBox(height: 12),
          _InfoTabBar(
            tab: _tab,
            onChanged: (value) => setState(() => _tab = value),
            specCount: widget.specs.length,
            reviewCount: widget.reviewCount,
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.short),
            switchInCurve: Motion.emphasized,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: switch (_tab) {
                _InfoTab.description => _DescriptionPanel(
                  blurb: widget.blurb,
                  copy: widget.copy,
                  warranty: widget.warranty,
                ),
                _InfoTab.specifications => _SpecTable(rows: widget.specs),
                _InfoTab.delivery => const _DeliveryInfoPanel(),
                _InfoTab.reviews => _ReviewsPanel(
                  slug: widget.slug,
                  canReview: widget.canReview,
                  mine: widget.mine,
                  onReviewSaved: widget.onReviewSaved,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTabBar extends StatelessWidget {
  const _InfoTabBar({
    required this.tab,
    required this.onChanged,
    required this.specCount,
    required this.reviewCount,
  });

  final _InfoTab tab;
  final ValueChanged<_InfoTab> onChanged;
  final int specCount;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _DetailPalette.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in _InfoTab.values)
              _InfoTabChip(
                label: switch (item) {
                  _InfoTab.description => 'Description',
                  _InfoTab.specifications =>
                    specCount > 0 ? 'Specs ($specCount)' : 'Specs',
                  _InfoTab.delivery => 'Delivery',
                  _InfoTab.reviews => 'Reviews ($reviewCount)',
                },
                selected: tab == item,
                onTap: () => onChanged(item),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoTabChip extends StatelessWidget {
  const _InfoTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.98,
      semanticLabel: label,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        curve: Motion.emphasized,
        margin: const EdgeInsets.only(right: 18),
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? _DetailPalette.blue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _DetailPalette.ink : _DetailPalette.muted,
          ),
        ),
      ),
    );
  }
}

class _DescriptionPanel extends StatelessWidget {
  const _DescriptionPanel({
    required this.blurb,
    required this.copy,
    required this.warranty,
  });

  final String blurb;
  final String? copy;
  final String warranty;

  @override
  Widget build(BuildContext context) {
    final body = copy;
    final hasCopy = body != null && body.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (blurb.isNotEmpty) ...[
          Text(
            blurb,
            style: AppTypography.bodyLarge.copyWith(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: _DetailPalette.ink,
            ),
          ),
          if (hasCopy || warranty.isNotEmpty) const SizedBox(height: 8),
        ],
        if (hasCopy)
          _ExpandableText(body)
        else if (blurb.isEmpty)
          Text(
            'The seller has not added a description yet.',
            style: AppTypography.bodyLarge.copyWith(
              fontSize: 13,
              height: 1.5,
              color: _DetailPalette.muted,
            ),
          ),
        if (warranty.isNotEmpty) ...[
          const SizedBox(height: 14),
          _WarrantyCard(period: warranty),
        ],
      ],
    );
  }
}

class _WarrantyCard extends StatelessWidget {
  const _WarrantyCard({required this.period});

  final String period;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(PhosphorIconsBold.shieldCheck, size: 16, color: _DetailPalette.blue),
                const SizedBox(width: 6),
                Text(
                  'Warranty',
                  style: AppTypography.bodyLarge.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: _DetailPalette.ink),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              period,
              style: AppTypography.bodyLarge.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: _DetailPalette.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Covered for $period from the day the order is delivered, for manufacturing defects. Keep the invoice if you need to make a claim.',
              style: AppTypography.bodyLarge.copyWith(fontSize: 13, height: 1.45, color: const Color(0xFF525E70)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryInfoPanel extends StatelessWidget {
  const _DeliveryInfoPanel();

  static const _points = <String>[
    'Delivery is available across Bangladesh. Cash on delivery means you pay when the order arrives.',
    'You can request a return within 3 days of receiving the product. The item needs to be unused, in its original condition, with tags and packaging intact.',
    'Damaged, defective, or wrong items can be returned. PickOrbeet covers the return delivery when the mistake is ours.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _points.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Text(
            _points[i],
            style: AppTypography.bodyLarge.copyWith(
              fontSize: 13,
              height: 1.5,
              color: const Color(0xFF525E70),
            ),
          ),
        ],
      ],
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child}) : padding = const EdgeInsets.all(14);

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
    final foreground = available ? _DetailPalette.ink : AppPallete.textHint;
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
          color: AppPallete.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _DetailPalette.ink : _DetailPalette.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: foreground,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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

class _SpecTable extends StatelessWidget {
  const _SpecTable({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text(
        'Specifications will appear here once the seller adds them.',
        style: AppTypography.bodyLarge.copyWith(
          fontSize: 13,
          height: 1.5,
          color: _DetailPalette.muted,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPallete.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _DetailPalette.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: i.isEven ? const Color(0xFFF7F9FC) : AppPallete.surface,
                  border: i == rows.length - 1
                      ? null
                      : const Border(bottom: BorderSide(color: Color(0xFFEEF2F7))),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          rows[i].$1,
                          style: AppTypography.bodyMedium.copyWith(
                            color: _DetailPalette.muted,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 6,
                        child: Text(
                          rows[i].$2,
                          textAlign: TextAlign.right,
                          style: AppTypography.bodyMedium.copyWith(
                            color: _DetailPalette.ink,
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  static const _items = <(IconData, String, String)>[
    (PhosphorIconsRegular.shieldCheck, '100% Original', 'Trusted Quality'),
    (PhosphorIconsRegular.creditCard, 'Secure Payment', 'Multiple Options'),
    (PhosphorIconsRegular.package, 'Easy Returns', 'Hassle Free'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in _items)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.$1, size: 18, color: _DetailPalette.blue),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        maxLines: 2,
                        style: AppTypography.label.copyWith(
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: _DetailPalette.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$3,
                        maxLines: 2,
                        style: AppTypography.label.copyWith(fontSize: 10, height: 1.2, color: _DetailPalette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

abstract final class _DetailPalette {
  static const canvas = Color(0xFFF4F7FC);
  static const ink = Color(0xFF172033);
  static const muted = Color(0xFF8B95A7);
  static const line = Color(0xFFE6ECF5);
  static const orange = Color(0xFFFF7A1A);
  static const blue = Color(0xFF2864E8);
  static const save = Color(0xFF16835B);
  static const saveSoft = Color(0xFFE7F6EE);
  static const strike = Color(0xFFA3ADBD);
  static const star = Color(0xFFF5B400);
  static const starEmpty = Color(0xFFE4E8F0);
}

class _ProductTopBar extends StatelessWidget {
  const _ProductTopBar();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnLight,
      child: ColoredBox(
        color: AppPallete.surface,
        child: Padding(
          padding: EdgeInsets.only(top: top),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const HeaderBackButton(color: _DetailPalette.ink),
                const BrandLockup(
                  onDark: false,
                  markSize: Size(26, 28),
                  wordmarkSize: 17,
                  gap: 6,
                  markLift: 0.0,
                ),
                const Spacer(),
                _RoundButton(
                  label: 'Search',
                  filled: true,
                  onTap: () => context.push(Routes.search),
                  child: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18, color: _DetailPalette.ink),
                ),
                Pressable(
                  semanticLabel: 'Wishlist',
                  onTap: () => context.go(Routes.wishlist),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(PhosphorIconsRegular.heart, size: 22, color: _DetailPalette.ink),
                  ),
                ),
                const HeaderCartButton(color: _DetailPalette.ink),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.label, required this.onTap, required this.child, this.filled = false});

  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFFF1F4F9) : null,
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }
}

class _GalleryArrow extends StatelessWidget {
  const _GalleryArrow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.97,
      semanticLabel: label,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPallete.surface,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: _DetailPalette.ink.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 16, color: _DetailPalette.ink),
        ),
      ),
    );
  }
}

class _RatingLine extends StatelessWidget {
  const _RatingLine({
    required this.rating,
    required this.count,
    required this.canWrite,
    required this.hasMine,
    required this.onWrite,
  });

  final double rating;
  final int count;
  final bool canWrite;
  final bool hasMine;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final shown = count > 0 ? rating : 0.0;
    final score = count > 0 ? rating.toStringAsFixed(1) : '';
    final noun = count == 1 ? 'review' : 'reviews';
    final label = !canWrite
        ? 'Available after delivery'
        : (hasMine ? 'Edit your review' : 'Write a review');
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        _Stars(value: shown),
        if (score.isNotEmpty)
          Text(
            score,
            style: AppTypography.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: _DetailPalette.ink),
          ),
        Text(
          '($count $noun)',
          style: AppTypography.label.copyWith(fontSize: 13, color: _DetailPalette.muted, fontWeight: FontWeight.w500),
        ),
        Container(width: 1, height: 12, color: const Color(0xFFD5DCE8)),
        Pressable(
          semanticLabel: label,
          onTap: onWrite,
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: canWrite ? _DetailPalette.blue : _DetailPalette.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 5; index++)
          Padding(
            padding: const EdgeInsets.only(right: 1),
            child: _Star(fill: (value - index).clamp(0, 1).toDouble()),
          ),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.fill});

  final double fill;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        children: [
          const Icon(PhosphorIconsFill.star, size: 14, color: _DetailPalette.starEmpty),
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: fill,
              child: const Icon(PhosphorIconsFill.star, size: 14, color: _DetailPalette.star),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({required this.colors, required this.selected, required this.onSelected});

  final List<({String label, String hex})> colors;
  final String? selected;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final color in colors)
          Pressable(
            semanticLabel: color.label,
            onTap: onSelected == null ? null : () => onSelected!(color.label),
            child: AnimatedContainer(
              duration: Motion.of(context, const Duration(milliseconds: 220)),
              curve: Motion.emphasized,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppPallete.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.label == selected ? _DetailPalette.blue : const Color(0xFFE6ECF5),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: _paint(color.hex, color.label),
                      shape: BoxShape.circle,
                      border: Border.all(color: _DetailPalette.ink.withValues(alpha: 0.08)),
                    ),
                    child: const SizedBox(width: 14, height: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    color.label,
                    style: AppTypography.bodyLarge.copyWith(
                      fontSize: 13,
                      fontWeight: color.label == selected ? FontWeight.w700 : FontWeight.w500,
                      color: _DetailPalette.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PurchaseButton extends StatelessWidget {
  const _PurchaseButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? AppPallete.onDark : _DetailPalette.blue;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Pressable(
        pressedScale: 0.98,
        semanticLabel: label,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.short),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? _DetailPalette.orange : AppPallete.surface,
            borderRadius: BorderRadius.circular(10),
            border: filled ? null : Border.all(color: _DetailPalette.blue, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiseIn extends StatefulWidget {
  const _RiseIn({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<_RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<_RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: const Cubic(0.16, 1, 0.3, 1));
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(offset: Offset(0, 12 * (1 - curved.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

class _ReviewsPanel extends ConsumerStatefulWidget {
  const _ReviewsPanel({
    required this.slug,
    required this.canReview,
    required this.mine,
    required this.onReviewSaved,
  });

  final String slug;
  final bool canReview;
  final ProductReview? mine;
  final VoidCallback onReviewSaved;

  @override
  ConsumerState<_ReviewsPanel> createState() => _ReviewsPanelState();
}

class _ReviewsPanelState extends ConsumerState<_ReviewsPanel> {
  var _query = const ProductReviewsQuery();
  ProductReviewsPayload? _payload;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_fetch());
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(catalogRepositoryProvider).reviews(widget.slug, _query);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
      }),
      (payload) => setState(() {
        _loading = false;
        _payload = payload;
      }),
    );
  }

  void _patchQuery(ProductReviewsQuery next) {
    setState(() => _query = next);
    unawaited(_fetch());
  }

  Future<void> _openWrite() async {
    final signedIn = ref.read(sessionNotifierProvider) == SessionStatus.signedIn;
    if (!signedIn) {
      unawaited(context.push(Routes.loginFrom(Routes.product(widget.slug))));
      return;
    }
    if (!widget.canReview && widget.mine == null) {
      showToast(context, 'Available after delivery');
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPallete.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
      builder: (context) => _ReviewSheet(
        mine: widget.mine,
        canReview: widget.canReview,
        onSubmit: (rating, comment, images) => ref.read(catalogRepositoryProvider).saveReview(
          widget.slug,
          rating: rating,
          comment: comment,
          images: images,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    widget.onReviewSaved();
    unawaited(_fetch());
    showToast(context, 'Review saved', kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    final breakdown = payload?.ratingBreakdown ?? const {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    final count = payload?.count ?? 0;
    final average = payload?.average;
    final results = payload?.results ?? const <ProductReview>[];
    final maxBar = breakdown.values.fold<int>(1, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count > 0 && average != null ? average.toStringAsFixed(1) : '—',
                  style: AppTypography.titleLarge.copyWith(fontSize: 28, fontWeight: FontWeight.w800, color: _DetailPalette.ink),
                ),
                _Stars(value: count > 0 ? (average ?? 0) : 0),
                const SizedBox(height: 4),
                Text(
                  '$count review${count == 1 ? '' : 's'}',
                  style: AppTypography.label.copyWith(fontSize: 12, color: _DetailPalette.muted),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  for (var star = 5; star >= 1; star--)
                    Pressable(
                      onTap: () => _patchQuery(
                        _query.copyWith(
                          rating: _query.rating == star ? null : star,
                          clearRating: _query.rating == star,
                          page: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '$star★',
                                style: AppTypography.label.copyWith(
                                  fontSize: 11,
                                  fontWeight: _query.rating == star ? FontWeight.w700 : FontWeight.w500,
                                  color: _DetailPalette.ink,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: count == 0 ? 0 : (breakdown[star] ?? 0) / maxBar,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFEEF2F7),
                                  color: _DetailPalette.star,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 18,
                              child: Text(
                                '${breakdown[star] ?? 0}',
                                textAlign: TextAlign.right,
                                style: AppTypography.label.copyWith(fontSize: 11, color: _DetailPalette.muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var star = 5; star >= 1; star--)
              _FilterChip(
                label: '$star stars',
                selected: _query.rating == star,
                onTap: () => _patchQuery(
                  _query.copyWith(
                    rating: _query.rating == star ? null : star,
                    clearRating: _query.rating == star,
                    page: 1,
                  ),
                ),
              ),
            _FilterChip(
              label: 'With photos',
              selected: _query.withPhotos,
              onTap: () => _patchQuery(_query.copyWith(withPhotos: !_query.withPhotos, page: 1)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sort', style: AppTypography.label.copyWith(fontSize: 12, color: _DetailPalette.muted)),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _query.sort,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'newest', child: Text('Newest')),
                      DropdownMenuItem(value: 'highest', child: Text('Highest rated')),
                      DropdownMenuItem(value: 'lowest', child: Text('Lowest rated')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _patchQuery(_query.copyWith(sort: value, page: 1));
                    },
                  ),
                ),
              ],
            ),
            Builder(
              builder: (context) {
                final signedIn = ref.watch(sessionNotifierProvider) == SessionStatus.signedIn;
                final canWrite = !signedIn || widget.canReview || widget.mine != null;
                final label = !canWrite
                    ? 'Available after delivery'
                    : (widget.mine != null ? 'Edit your review' : 'Write a review');
                return Pressable(
                  onTap: () => unawaited(_openWrite()),
                  child: Text(
                    label,
                    style: AppTypography.label.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: canWrite ? _DetailPalette.blue : _DetailPalette.muted,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading && payload == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_error != null)
          Text(_error!, style: AppTypography.bodyMedium.copyWith(color: const Color(0xFFD14343)))
        else if (results.isEmpty)
          Text(
            count == 0 ? 'No reviews yet. Be the first to review this product.' : 'No reviews match these filters.',
            style: AppTypography.bodyMedium.copyWith(fontSize: 13, color: _DetailPalette.muted),
          )
        else
          for (final review in results) ...[
            _ReviewTile(review: review),
            const Divider(height: 24, color: Color(0xFFEEF2F7)),
          ],
        if (payload != null && (payload.previous != null || payload.next != null))
          Row(
            children: [
              TextButton(
                onPressed: payload.previous == null || _loading
                    ? null
                    : () => _patchQuery(_query.copyWith(page: _query.page - 1)),
                child: const Text('Previous'),
              ),
              Text('Page ${_query.page}', style: AppTypography.label.copyWith(fontSize: 12, color: _DetailPalette.muted)),
              TextButton(
                onPressed: payload.next == null || _loading
                    ? null
                    : () => _patchQuery(_query.copyWith(page: _query.page + 1)),
                child: const Text('Next'),
              ),
            ],
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _DetailPalette.ink : const Color(0xFFF1F4F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _DetailPalette.muted,
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              review.author,
              style: AppTypography.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: _DetailPalette.ink),
            ),
            _Stars(value: review.rating.toDouble()),
            Text(
              review.createdAt.length >= 10 ? review.createdAt.substring(0, 10) : review.createdAt,
              style: AppTypography.label.copyWith(fontSize: 11, color: _DetailPalette.muted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          review.comment,
          style: AppTypography.bodyMedium.copyWith(fontSize: 13, height: 1.45, color: const Color(0xFF525E70)),
        ),
        if (review.images.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: review.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final urls = [
                  for (final image in review.images)
                    if (image.image.trim().isNotEmpty) image.image,
                ];
                final url = review.images[index].image;
                return Pressable(
                  semanticLabel: 'View review photo',
                  onTap: urls.isEmpty
                      ? null
                      : () => openFullscreenImages(context, urls: urls, initial: index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: AppNetworkImage(url: url),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.onSubmit,
    required this.canReview,
    this.mine,
  });

  final ProductReview? mine;
  final bool canReview;
  final Future<Either<AppFailure, bool>> Function(
    int rating,
    String comment,
    List<({String filename, List<int> bytes})> images,
  ) onSubmit;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _comment = TextEditingController();
  final _picker = ImagePicker();
  var _rating = 5;
  var _saving = false;
  String? _commentError;
  String? _photoError;
  final _images = <({String filename, List<int> bytes, Uint8List preview})>[];

  @override
  void initState() {
    super.initState();
    final mine = widget.mine;
    if (mine != null) {
      _rating = mine.rating.clamp(1, 5);
      _comment.text = mine.comment;
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1600, limit: 5);
    if (picked.isEmpty || !mounted) return;
    final next = <({String filename, List<int> bytes, Uint8List preview})>[..._images];
    for (final file in picked) {
      if (next.length >= 5) break;
      final bytes = await file.readAsBytes();
      next.add((filename: file.name, bytes: bytes, preview: bytes));
    }
    if (!mounted) return;
    setState(() {
      _photoError = null;
      _images
        ..clear()
        ..addAll(next.take(5));
    });
  }

  bool _isPhotoError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('photo') || lower.contains('image');
  }

  Future<void> _send() async {
    final comment = _comment.text.trim();
    if (comment.isEmpty) {
      setState(() => _commentError = 'Write a short comment with your rating.');
      return;
    }
    setState(() {
      _saving = true;
      _commentError = null;
      _photoError = null;
    });
    final result = await widget.onSubmit(
      _rating,
      comment,
      [for (final image in _images) (filename: image.filename, bytes: image.bytes)],
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _saving = false;
        if (_isPhotoError(failure.message)) {
          _photoError = failure.message;
        } else {
          _commentError = failure.message;
        }
      }),
      (_) => Navigator.of(context).pop(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final eligible = widget.canReview || widget.mine != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.mine != null ? 'Your review' : 'Write a review',
            style: AppTypography.titleLarge.copyWith(fontSize: 18, color: _DetailPalette.ink),
          ),
          const SizedBox(height: 12),
          if (!eligible)
            Text(
              'Available after delivery — you can review this product once an order with it is delivered.',
              style: AppTypography.bodyMedium.copyWith(fontSize: 13, color: _DetailPalette.muted),
            )
          else ...[
            Row(
              children: [
                for (var star = 1; star <= 5; star++)
                  Pressable(
                    semanticLabel: '$star star${star == 1 ? '' : 's'}',
                    onTap: _saving ? null : () => setState(() => _rating = star),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        PhosphorIconsFill.star,
                        size: 28,
                        color: star <= _rating ? _DetailPalette.star : _DetailPalette.starEmpty,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              minLines: 3,
              maxLines: 5,
              maxLength: 2000,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'How was this product?',
                errorText: _commentError,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final image = _images[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(image.preview, width: 64, height: 64, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Pressable(
                            onTap: _saving
                                ? null
                                : () => setState(() => _images.removeAt(index)),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(color: Color(0xB3172033), shape: BoxShape.circle),
                              child: Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(PhosphorIconsBold.x, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            Pressable(
              onTap: _saving || _images.length >= 5 ? null : () => unawaited(_pickPhotos()),
              child: Text(
                'Add photos (${_images.length}/5)',
                style: AppTypography.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: _DetailPalette.blue),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'New uploads replace existing photos.',
              style: AppTypography.label.copyWith(fontSize: 11, color: _DetailPalette.muted),
            ),
            if (_photoError != null) ...[
              const SizedBox(height: 6),
              Text(
                _photoError!,
                style: AppTypography.label.copyWith(fontSize: 12, color: const Color(0xFFD14343)),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: _PurchaseButton(
                label: _saving ? 'Saving...' : (widget.mine != null ? 'Update review' : 'Submit review'),
                icon: PhosphorIconsBold.check,
                filled: true,
                enabled: !_saving,
                onTap: () => unawaited(_send()),
              ),
            ),
          ],
        ],
      ),
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
          '${index + 1}/$count',
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

class _VideoSlide extends StatefulWidget {
  const _VideoSlide({required this.video});

  final ProductVideo video;

  @override
  State<_VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends State<_VideoSlide> {
  WebViewController? _controller;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    final embed = widget.video.embedUrl;
    if (embed.isEmpty) {
      _failed = true;
      return;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF7F9FC))
      ..loadRequest(Uri.parse(embed));
    _controller = controller;
  }

  Future<void> _openExternally() async {
    final raw = widget.video.youtubeUrl.trim().isNotEmpty
        ? widget.video.youtubeUrl.trim()
        : 'https://www.youtube.com/watch?v=${widget.video.youtubeId}';
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _controller == null) {
      return ColoredBox(
        color: const Color(0xFFF7F9FC),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(PhosphorIconsFill.play, size: 36, color: _DetailPalette.blue),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => unawaited(_openExternally()),
                child: const Text('Open on YouTube'),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller!),
        Positioned(
          left: 8,
          bottom: 8,
          child: TextButton.icon(
            onPressed: () => unawaited(_openExternally()),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xB3172033),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(PhosphorIconsRegular.arrowSquareOut, size: 14),
            label: const Text('YouTube'),
          ),
        ),
      ],
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

class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    return const AppSkeletonTheme(
      child: Skeletonizer(
        child: Column(
          children: [
            SkeletonBox(height: 250, radius: 16),
            SizedBox(height: 10),
            SkeletonBox(height: 68, radius: 10),
            SizedBox(height: 14),
            SkeletonBox(height: 28),
            SizedBox(height: 8),
            SkeletonBox(height: 16, radius: 4),
            SizedBox(height: 12),
            SkeletonBox(height: 48, radius: 10),
            SizedBox(height: 14),
            SkeletonBox(height: 92, radius: 16),
          ],
        ),
      ),
    );
  }
}

class _Group {
  const _Group({
    required this.name,
    required this.kind,
    required this.values,
    required this.required,
  });

  final String name;
  final String kind;
  final List<VariantChoice> values;
  final bool required;
}

List<VariantChoice> _variantChoices(ProductVariant variant) {
  if (variant.options.isNotEmpty) return variant.options;
  return [
    if ((variant.size ?? '').trim().isNotEmpty)
      VariantChoice(name: 'Size', label: variant.size!.trim()),
    if ((variant.color ?? '').trim().isNotEmpty)
      VariantChoice(name: 'Color', kind: 'swatch', label: variant.color!.trim()),
  ];
}

bool _isColorGroup(String name, String kind) {
  if (kind == 'swatch') return true;
  return RegExp(r'\bcolou?rs?\b', caseSensitive: false).hasMatch(name.trim());
}

List<_Group> _groups(ProductDetail detail) {
  if (detail.optionGroups.isNotEmpty) {
    return [
      for (final group in detail.optionGroups)
        if (group.name.trim().isNotEmpty && group.values.isNotEmpty)
          _Group(
            name: group.name.trim(),
            kind: _isColorGroup(group.name, group.kind) ? 'swatch' : 'text',
            required: true,
            values: [
              for (final value in group.values)
                if (value.label.trim().isNotEmpty)
                  VariantChoice(
                    name: group.name.trim(),
                    label: value.label.trim(),
                    kind: _isColorGroup(group.name, group.kind) ? 'swatch' : 'text',
                    colorHex: value.colorHex,
                  ),
            ],
          ),
    ];
  }
  final sizes = <String>[];
  final colors = <String>[];
  for (final variant in detail.summary.variants) {
    if (!variant.isActive) continue;
    final size = variant.size?.trim() ?? '';
    final color = variant.color?.trim() ?? '';
    if (size.isNotEmpty && !sizes.contains(size)) sizes.add(size);
    if (color.isNotEmpty && !colors.contains(color)) colors.add(color);
  }
  final groups = <_Group>[
    if (sizes.isNotEmpty)
      _Group(
        name: 'Size',
        kind: 'text',
        required: true,
        values: [for (final label in sizes) VariantChoice(name: 'Size', label: label)],
      ),
    if (colors.isNotEmpty)
      _Group(
        name: 'Color',
        kind: 'swatch',
        required: true,
        values: [for (final label in colors) VariantChoice(name: 'Color', kind: 'swatch', label: label)],
      ),
  ];
  final fallback = detail.color?.trim() ?? '';
  if (groups.isEmpty && fallback.isNotEmpty) {
    groups.add(_Group(
      name: 'Color',
      kind: 'swatch',
      required: false,
      values: [VariantChoice(name: 'Color', kind: 'swatch', label: fallback)],
    ));
  }
  return groups;
}

bool _matchesPicked(ProductVariant variant, List<_Group> groups, Map<String, String> picked, {String? skip}) {
  final choices = _variantChoices(variant);
  for (final group in groups) {
    if (!group.required || group.name == skip) continue;
    final label = picked[group.name];
    if (label == null) continue;
    if (!choices.any((choice) => choice.name == group.name && choice.label == label)) return false;
  }
  return true;
}

List<String> _choiceLabels(ProductDetail detail, _Group group, Map<String, String> picked) {
  final groups = _groups(detail);
  final labels = <String>[];
  for (final value in group.values) {
    final found = detail.summary.variants.any((variant) {
      if (!variant.isActive) return false;
      final choices = _variantChoices(variant);
      if (!choices.any((choice) => choice.name == group.name && choice.label == value.label)) return false;
      return _matchesPicked(variant, groups, picked, skip: group.name);
    });
    if (found || detail.summary.variants.isEmpty) labels.add(value.label);
  }
  if (labels.isNotEmpty) return labels;
  return [for (final value in group.values) value.label];
}

bool _valueInStock(ProductDetail detail, _Group group, String label, Map<String, String> picked) {
  final groups = _groups(detail);
  for (final variant in detail.summary.variants) {
    if (!variant.isActive || !variant.inStock) continue;
    final choices = _variantChoices(variant);
    if (!choices.any((choice) => choice.name == group.name && choice.label == label)) continue;
    if (_matchesPicked(variant, groups, picked, skip: group.name)) return true;
  }
  return false;
}

ProductVariant? _selectedVariant(ProductDetail detail, Map<String, String> picked) {
  final active = [
    for (final variant in detail.summary.variants)
      if (variant.isActive) variant,
  ];
  if (active.isEmpty) return null;
  final required = [for (final group in _groups(detail)) if (group.required) group];
  if (required.isEmpty) {
    for (final variant in active) {
      if (variant.inStock) return variant;
    }
    return active.first;
  }
  if (required.any((group) => picked[group.name] == null)) return null;
  ProductVariant? fallback;
  for (final variant in active) {
    final choices = _variantChoices(variant);
    final matches = required.every((group) => choices.any(
      (choice) => choice.name == group.name && choice.label == picked[group.name],
    ));
    if (!matches) continue;
    fallback ??= variant;
    if (variant.inStock) return variant;
  }
  return fallback;
}

String _unitPrice(ProductDetail detail, Map<String, String> picked) {
  final variant = _selectedVariant(detail, picked);
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

bool _soldOut(ProductDetail detail, Map<String, String> picked) {
  final variant = _selectedVariant(detail, picked);
  return variant != null ? !variant.inStock : detail.summary.isOutOfStock;
}

/// The server checks real stock when the item is added, so the picker only needs the ceiling.
int _stockCap(ProductDetail detail, Map<String, String> picked) =>
    _soldOut(detail, picked) ? 1 : CartItemModel.orderCeiling;

(String, Color) _availability(ProductDetail detail, Map<String, String> picked) =>
    _soldOut(detail, picked)
        ? ('Out of stock', AppPallete.danger)
        : ('In stock', _DetailPalette.save);

({String label, bool canAdd, String? prompt}) _purchaseAction(
  ProductDetail detail,
  Map<String, String> picked,
) {
  for (final group in _groups(detail)) {
    if (group.required && picked[group.name] == null) {
      final name = group.name.toLowerCase();
      return (label: 'Select a $name', canAdd: false, prompt: 'Choose a $name');
    }
  }
  if (_soldOut(detail, picked)) return (label: 'Out of stock', canAdd: false, prompt: null);
  return (label: 'Add to cart', canAdd: true, prompt: null);
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
  return [
    for (final row in detail.specs)
      if (_cleanSpec(row.$2).isNotEmpty) (row.$1, _cleanSpec(row.$2)),
  ];
}

String? _aboutCopy(ProductDetail detail) {
  final copy = detail.plainDescription.trim();
  if (copy.isEmpty) return null;
  if (copy == detail.summary.shortDescription.trim()) return null;
  return copy;
}

String _taka(Object? value) => '৳${Formatters.amount(value)}';

Color _paint(String hex, String name) {
  final value = hex.trim();
  if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
    final channels = int.parse(value.substring(1), radix: 16);
    return Color(0xFF000000 | channels);
  }
  return _swatchColor(name);
}

Color _swatchColor(String name) {
  const colors = <String, Color>{
    'black': Color(0xFF171717),
    'white': Color(0xFFF4F4F4),
    'red': Color(0xFFE11D48),
    'blue': Color(0xFF3B82F6),
    'navy': Color(0xFF1E3A8A),
    'green': Color(0xFF16A34A),
    'yellow': Color(0xFFF5C518),
    'orange': Color(0xFFFF7A1A),
    'purple': Color(0xFF7C3AED),
    'pink': Color(0xFFEC4899),
    'brown': Color(0xFF8B5E3C),
    'gray': Color(0xFF9CA3AF),
    'grey': Color(0xFF9CA3AF),
    'beige': Color(0xFFE7D7C5),
    'maroon': Color(0xFF7F1D1D),
    'silver': Color(0xFFC5CDD8),
  };
  return colors[name.trim().toLowerCase()] ?? const Color(0xFFD5DDE8);
}
