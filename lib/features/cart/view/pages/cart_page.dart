import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/models/paginated.dart';
import 'package:pickorbeet/core/motion/animated_values.dart';
import 'package:pickorbeet/core/motion/entrance.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/cart_notifier.dart';
import 'package:pickorbeet/core/providers/wishlist_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/router/tab_reselect.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/core/widgets/app_header.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/core/widgets/price_text.dart';
import 'package:pickorbeet/core/widgets/quantity_stepper.dart';
import 'package:pickorbeet/core/widgets/section.dart';
import 'package:pickorbeet/core/widgets/state_views.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:pickorbeet/features/cart/repositories/cart_remote_repository.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/view/widgets/product_card.dart';
import 'package:pickorbeet/features/catalog/viewmodel/catalog_providers.dart';
import 'package:pickorbeet/features/checkout/checkout_args.dart';
import 'package:pickorbeet/features/checkout/checkout_logic.dart';
import 'package:pickorbeet/features/checkout/checkout_repository.dart';
import 'package:pickorbeet/features/home/view/widgets/category_section_card.dart';
import 'package:pickorbeet/features/vouchers/model/store_voucher.dart';
import 'package:pickorbeet/features/vouchers/repositories/vouchers_repository.dart';

/// The cart: selectable lines, a voucher, recommendations, and a total that counts as it changes.
class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  static const tabIndex = 4;
  static const margin = 12.2;

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  final _scroll = ScrollController();
  final _known = <String>{};
  final _selected = <String>{};

  String? _couponCode;
  String _discount = '0';
  String? _pricedFor;
  String? _pendingCoupon;
  String? _handledCouponQuery;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final raw = GoRouterState.of(context).uri.queryParameters['coupon']?.trim();
    final code = (raw == null || raw.isEmpty) ? null : raw.toUpperCase();
    if (code == null || code == _handledCouponQuery) return;
    _handledCouponQuery = code;
    _pendingCoupon = code;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Applies a deep-linked coupon once some lines are selected.
  void _applyPendingCoupon(List<CartItemModel> lines) {
    final code = _pendingCoupon;
    if (code == null || code.isEmpty) return;
    _pendingCoupon = null;
    if (_couponCode == code && _pricedFor == couponQuoteKey(lines)) return;
    setState(() {
      _couponCode = code;
      _discount = '0';
    });
    _reprice(code, lines);
  }

  /// New lines start selected. Unavailable lines and lines the server dropped leave the selection.
  void _adopt(List<CartItemModel> items) {
    final ids = items.map((item) => item.id).toSet();
    for (final item in items) {
      if (_known.add(item.id)) _selected.add(item.id);
      if (item.isOutOfStock) _selected.remove(item.id);
    }
    final gone = _known.where((id) => !ids.contains(id)).toList();
    for (final id in gone) {
      _known.remove(id);
      _selected.remove(id);
    }
  }

  Future<void> _refresh() => ref.read(cartNotifierProvider.notifier).reload();

  void _toggle(CartItemModel item) {
    if (item.isOutOfStock && !_selected.contains(item.id)) {
      showToast(context, '${item.productName} is unavailable right now.', kind: ToastKind.error);
      return;
    }
    setState(() {
      if (!_selected.add(item.id)) _selected.remove(item.id);
    });
  }

  Future<void> _setQuantity(CartItemModel item, int quantity) async {
    final failure = await ref
        .read(cartNotifierProvider.notifier)
        .setQuantity(item.id, quantity);
    if (!mounted || failure == null) return;
    showToast(context, failure.message, kind: ToastKind.error);
  }

  Future<void> _remove(CartItemModel item) async {
    final (_, failure) = await ref
        .read(cartNotifierProvider.notifier)
        .remove(item.id);
    if (!mounted) return;
    if (failure != null) {
      showToast(context, failure.message, kind: ToastKind.error);
      return;
    }
    showToast(
      context,
      '${item.productName} removed',
      actionLabel: 'Undo',
      duration: const Duration(seconds: 4),
      onAction: () => unawaited(_undo(item)),
    );
  }

  Future<void> _undo(CartItemModel item) async {
    final failure = await ref
        .read(cartNotifierProvider.notifier)
        .undoRemove(item);
    if (!mounted || failure == null) return;
    showToast(context, failure.message, kind: ToastKind.error);
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text('Every item in your cart will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep items'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear cart'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final failure = await ref.read(cartNotifierProvider.notifier).clear();
    if (!mounted || failure == null) return;
    showToast(context, failure.message, kind: ToastKind.error);
  }

  Future<void> _editVoucher(List<CartItemModel> lines) async {
    if (lines.isEmpty) {
      showToast(context, 'Select the items you want to buy first.', kind: ToastKind.error);
      return;
    }
    final result = await showModalBottomSheet<_VoucherResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPallete.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => _VoucherSheet(
        itemIds: [for (final line in lines) line.id],
        currentCode: _couponCode,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _couponCode = result.quote?.code;
      _discount = result.quote?.discountAmount ?? '0';
      _pricedFor = result.quote == null ? null : couponQuoteKey(lines);
    });
  }

  void _removeVoucher() => setState(() {
    _couponCode = null;
    _discount = '0';
    _pricedFor = null;
  });

  void _reprice(String code, List<CartItemModel> lines) {
    final key = couponQuoteKey(lines);
    _pricedFor = key;
    unawaited(() async {
      final result = await ref
          .read(cartRemoteRepositoryProvider)
          .validateCoupon(code: code, itemIds: [for (final line in lines) line.id]);
      if (!mounted || _couponCode != code || _pricedFor != key) return;
      result.fold((failure) {
        setState(() {
          _couponCode = null;
          _discount = '0';
          _pricedFor = null;
        });
        showToast(context, failure.message, kind: ToastKind.error);
      }, (quote) => setState(() => _discount = quote.discountAmount));
    }());
  }

  @override
  Widget build(BuildContext context) {
    listenForTabReselect(ref, context, CartPage.tabIndex, _scroll);
    final cart = ref.watch(cartNotifierProvider);

    return Scaffold(
      backgroundColor: AppPallete.background,
      body: Column(
        children: [
          const TabHeader(heroTag: 'search-cart'),
          Expanded(
            child: cart.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppPallete.primary),
              ),
              error: (error, _) =>
                  ErrorState(failure: error, onRetry: _refresh),
              data: _body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(CartModel cart) {
    _adopt(cart.items);
    if (cart.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: AppPallete.primary,
        backgroundColor: AppPallete.surface,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 72),
            EmptyState(
              icon: PhosphorIconsDuotone.shoppingCart,
              title: 'Your cart is empty',
              message: 'Products you add will wait for you here.',
              actionLabel: 'Browse categories',
              onAction: () => context.go(Routes.categories),
            ),
          ],
        ),
      );
    }

    final selected = [
      for (final item in cart.items)
        if (_selected.contains(item.id)) item,
    ];
    final units = selected.fold<int>(0, (sum, item) => sum + item.quantity);
    final itemsTotal = selected.fold(
      Decimal.zero,
      (sum, item) => sum + Formatters.decimal(item.totalPrice),
    );
    var discount = Formatters.decimal(_discount);
    if (discount < Decimal.zero) discount = Decimal.zero;
    if (discount > itemsTotal) discount = itemsTotal;
    final insideDhaka = estimateInsideDhaka(
      ref.watch(checkoutAddressesProvider).valueOrNull ?? const [],
    );
    final delivery = selected.isEmpty
        ? Decimal.zero
        : Formatters.decimal(
            insideDhaka == false
                ? cart.deliveryOutsideDhaka
                : cart.deliveryInsideDhaka,
          );
    final total = itemsTotal - discount + delivery;
    if (_pendingCoupon != null && selected.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyPendingCoupon(selected);
      });
    }
    final code = _couponCode;
    final quoteKey = couponQuoteKey(selected);
    if (code != null && selected.isNotEmpty && _pricedFor != quoteKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _couponCode == code && _pricedFor != quoteKey) {
          _reprice(code, selected);
        }
      });
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppPallete.primary,
      backgroundColor: AppPallete.surface,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          CartPage.margin,
          14,
          CartPage.margin,
          20,
        ),
        children: [
          _CartTitle(count: cart.totalItems, onClear: _clear).entrance(),
          const SizedBox(height: 12),
          for (var i = 0; i < cart.items.length; i++) ...[
            _CartLine(
              item: cart.items[i],
              selected: _selected.contains(cart.items[i].id),
              onSelected: () => _toggle(cart.items[i]),
              onQuantity: (quantity) =>
                  unawaited(_setQuantity(cart.items[i], quantity)),
              onRemove: () => unawaited(_remove(cart.items[i])),
            ).entrance(index: i, enabled: i < 4),
            const SizedBox(height: 10),
          ],
          _Suggestions(
            excluded: cart.items.map((item) => item.productId).toSet(),
          ),
          const SizedBox(height: 12),
          _Summary(
            units: units,
            itemsTotal: itemsTotal.toString(),
            discount: discount.toString(),
            couponCode: _couponCode,
            delivery: delivery.toString(),
            deliveryIsEstimate: insideDhaka == null && selected.isNotEmpty,
            insideDhaka: cart.deliveryInsideDhaka,
            outsideDhaka: cart.deliveryOutsideDhaka,
            total: total.toString(),
            onVoucher: () => unawaited(_editVoucher(selected)),
            onRemoveVoucher: _removeVoucher,
            canCheckout: selected.isNotEmpty,
            onCheckout: () => context.push(
              CheckoutArgs(
                itemIds: [for (final item in selected) item.id],
                couponCode: _couponCode,
              ).location,
            ),
          ).entrance(index: 4),
        ],
      ),
    );
  }
}

class _CartTitle extends StatelessWidget {
  const _CartTitle({required this.count, required this.onClear});

  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? 'item' : 'items';
    return Row(
      children: [
        Text(
          'My Cart',
          style: AppTypography.titleLarge.copyWith(
            fontSize: 18.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($count $label)',
          style: AppTypography.bodyLarge.copyWith(
            color: AppPallete.textSecondary,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        Pressable(
          semanticLabel: 'Clear cart',
          onTap: onClear,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                PhosphorIconsRegular.trash,
                size: 14,
                color: AppPallete.sale,
              ),
              const SizedBox(width: 4),
              Text(
                'Clear Cart',
                style: AppTypography.label.copyWith(
                  color: AppPallete.sale,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CartLine extends ConsumerWidget {
  const _CartLine({
    required this.item,
    required this.selected,
    required this.onSelected,
    required this.onQuantity,
    required this.onRemove,
  });

  final CartItemModel item;
  final bool selected;
  final VoidCallback onSelected;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(isWishlistedProvider(item.productId));
    final blurb = item.shortDescription.trim();
    final subtitle = item.options.isNotEmpty
        ? item.variantLabel
        : (blurb.isNotEmpty ? blurb : item.variantLabel);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: AppPallete.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          PhosphorIconsBold.trash,
          color: AppPallete.onDark,
          size: 18,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPallete.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: HomeCard.shadow,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: _CheckBox(checked: selected, onTap: onSelected),
              ),
              const SizedBox(width: 8),
              Pressable(
                semanticLabel: item.productName,
                onTap: () => context.push(Routes.product(item.productSlug)),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    children: [
                      AppNetworkImage(
                        url: item.productImage,
                        borderRadius: BorderRadius.circular(10),
                        background: const Color(0xFFF4F7FC),
                      ),
                      if (item.hasDiscount)
                        Positioned(
                          left: 4,
                          top: 4,
                          child: _OffBadge(percent: item.discountPercentage),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Pressable(
                            onTap: () =>
                                context.push(Routes.product(item.productSlug)),
                            child: Text(
                              item.productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleSmall.copyWith(
                                fontSize: 12.4,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                        Pressable(
                          semanticLabel: saved
                              ? 'Remove from wishlist'
                              : 'Save to wishlist',
                          onTap: () {
                            final added = ref
                                .read(wishlistNotifierProvider.notifier)
                                .toggle(item.productId);
                            if (added == null && context.mounted) {
                              showToast(
                                context,
                                'Your wishlist is full.',
                                kind: ToastKind.error,
                              );
                            }
                          },
                          child: Icon(
                            saved
                                ? PhosphorIconsFill.heart
                                : PhosphorIconsRegular.heart,
                            size: 18,
                            color: saved
                                ? AppPallete.sale
                                : AppPallete.heartIdle,
                          ),
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(fontSize: 10),
                      ),
                    if (item.isOutOfStock)
                      Text(
                        'Unavailable',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppPallete.danger,
                          fontSize: 10,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: PriceText(
                            price: item.unitPrice,
                            comparePrice: item.comparePrice,
                            style: AppTypography.price.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppPallete.ink,
                            ),
                            strikeStyle: AppTypography.strike.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ),
                        QuantityStepper(
                          value: item.quantity,
                          max: item.maxQuantity,
                          canIncrease: !item.isOutOfStock,
                          onChanged: onQuantity,
                        ),
                      ],
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

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked, required this.onTap});

  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: checked ? 'Selected' : 'Not selected',
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: checked ? AppPallete.primary : AppPallete.surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: checked ? AppPallete.primary : const Color(0xFFD5DCEC),
            width: 1.4,
          ),
        ),
        child: checked
            ? const Icon(
                PhosphorIconsBold.check,
                size: 11,
                color: AppPallete.onDark,
              )
            : null,
      ),
    );
  }
}

class _OffBadge extends StatelessWidget {
  const _OffBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppPallete.sale,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$percent% OFF',
        textScaler: TextScaler.noScaling,
        style: AppTypography.labelSmall.copyWith(
          color: AppPallete.onDark,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.excluded});

  final Set<String> excluded;

  static List<ProductSummary> _pick(
    AsyncValue<Paginated<ProductSummary>> list,
    Set<String> excluded,
  ) {
    final results = list.valueOrNull?.results;
    if (results == null) return const [];
    return [
      for (final product in results)
        if (!excluded.contains(product.id) && !product.isOutOfStock) product,
    ].take(8).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Featured products first. When those are already in the cart, fall back to the rest of the shop.
    final featured = _pick(
      ref.watch(productListProvider(const ProductQuery(featured: true))),
      excluded,
    );
    final products = featured.length >= 2
        ? featured
        : _pick(
            ref.watch(
              productListProvider(const ProductQuery(ordering: '-created_at')),
            ),
            excluded,
          );
    if (products.isEmpty) return const SizedBox.shrink();
    const width = 92.9;
    final height = ProductCard.heightFor(
      width,
      MediaQuery.textScalerOf(context),
    );
    return HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 0),
            child: SectionHeader(
              title: 'You May Also Like',
              onViewAll: () => context.push(
                Routes.productList(title: 'You May Also Like', featured: true),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ProductCard(
                product: products[index],
                width: width,
                heroScope: 'cart',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.units,
    required this.itemsTotal,
    required this.discount,
    required this.couponCode,
    required this.delivery,
    required this.deliveryIsEstimate,
    required this.insideDhaka,
    required this.outsideDhaka,
    required this.total,
    required this.onVoucher,
    required this.onRemoveVoucher,
    required this.canCheckout,
    required this.onCheckout,
  });

  final int units;
  final String itemsTotal;
  final String discount;
  final String? couponCode;
  final String delivery;

  /// No saved address yet, so the zone is unknown and [delivery] is the lowest rate.
  final bool deliveryIsEstimate;
  final String insideDhaka;
  final String outsideDhaka;
  final String total;
  final VoidCallback onVoucher;
  final VoidCallback onRemoveVoucher;
  final bool canCheckout;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final label = AppTypography.bodyMedium.copyWith(
      fontSize: 12,
      color: AppPallete.inkSoft,
    );
    final amount = AppTypography.titleSmall.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
    );
    final hasDiscount = Formatters.decimal(discount) > Decimal.zero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppPallete.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: HomeCard.shadow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.receipt,
                      size: 16,
                      color: AppPallete.ink,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Order Summary',
                      style: AppTypography.titleSmall.copyWith(fontSize: 13.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MoneyRow(
                  label: 'Items ($units)',
                  value: itemsTotal,
                  labelStyle: label,
                  valueStyle: amount,
                ),
                const SizedBox(height: 8),
                _VoucherRow(
                  code: couponCode,
                  saved: discount,
                  onTap: onVoucher,
                  onRemove: onRemoveVoucher,
                ),
                if (couponCode != null) ...[
                  const SizedBox(height: 8),
                  _MoneyRow(
                    label: 'Discount',
                    value: discount,
                    deduction: hasDiscount,
                    labelStyle: label,
                    valueStyle: amount.copyWith(
                      color: hasDiscount ? AppPallete.success : AppPallete.ink,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Delivery Charge', style: label),
                    const SizedBox(width: 4),
                    Tooltip(
                      message:
                          '${Formatters.money(insideDhaka)} inside Dhaka, ${Formatters.money(outsideDhaka)} outside.',
                      triggerMode: TooltipTriggerMode.tap,
                      child: const Icon(
                        PhosphorIconsRegular.info,
                        size: 14,
                        color: AppPallete.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      deliveryIsEstimate
                          ? 'From ${Formatters.money(delivery)}'
                          : Formatters.money(delivery),
                      style: amount,
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: AppPallete.divider),
                ),
                Row(
                  children: [
                    Text(
                      'Total Amount',
                      style: AppTypography.titleSmall.copyWith(fontSize: 13.5),
                    ),
                    const Spacer(),
                    AnimatedMoney(
                      total,
                      style: AppTypography.price.copyWith(
                        fontSize: 16,
                        color: AppPallete.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Proceed to Checkout',
          trailingIcon: PhosphorIconsBold.arrowRight,
          height: 48,
          onPressed: canCheckout ? onCheckout : null,
        ),
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
    this.deduction = false,
  });

  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool deduction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        Text(
          deduction ? Formatters.deduction(value) : Formatters.money(value),
          style: valueStyle,
        ),
      ],
    );
  }
}

class _VoucherResult {
  const _VoucherResult.applied(this.quote);
  const _VoucherResult.cleared() : quote = null;

  final CouponQuote? quote;
}

/// "Select or enter code" until a voucher is applied, then its code, the saving and a remove button.
class _VoucherRow extends StatelessWidget {
  const _VoucherRow({
    required this.code,
    required this.saved,
    required this.onTap,
    required this.onRemove,
  });

  final String? code;
  final String saved;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final applied = code;
    return Pressable(
      semanticLabel: applied == null ? 'Select or enter a voucher code' : 'Voucher $applied',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(
          color: AppPallete.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(PhosphorIconsRegular.ticket, size: 16, color: AppPallete.primary),
            const SizedBox(width: 8),
            Text(
              'Voucher',
              style: AppTypography.bodyMedium.copyWith(fontSize: 12, color: AppPallete.ink),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                applied == null ? 'Select or enter code' : '$applied · saves ${Formatters.money(saved)}',
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  fontSize: 11.5,
                  fontWeight: applied == null ? FontWeight.w500 : FontWeight.w700,
                  color: applied == null ? AppPallete.primaryText : AppPallete.success,
                ),
              ),
            ),
            if (applied == null)
              const Icon(PhosphorIconsRegular.caretRight, size: 14, color: AppPallete.primaryText)
            else
              Pressable(
                semanticLabel: 'Remove voucher',
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(PhosphorIconsBold.x, size: 13, color: AppPallete.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lists the shopper's vouchers for the selected lines, best saving first, and accepts a typed code.
class _VoucherSheet extends ConsumerStatefulWidget {
  const _VoucherSheet({required this.itemIds, this.currentCode});

  final List<String> itemIds;
  final String? currentCode;

  @override
  ConsumerState<_VoucherSheet> createState() => _VoucherSheetState();
}

class _VoucherSheetState extends ConsumerState<_VoucherSheet> {
  late final _code = TextEditingController(text: widget.currentCode ?? '');
  late final Future<List<StoreVoucher>> _wallet = _loadWallet();
  String? _applying;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<List<StoreVoucher>> _loadWallet() async {
    final result = await ref.read(vouchersRepositoryProvider).list(itemIds: widget.itemIds);
    return result.fold((failure) => throw failure, cartVouchers);
  }

  Future<void> _apply(String raw) async {
    final code = raw.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a voucher code.');
      return;
    }
    setState(() {
      _applying = code;
      _error = null;
    });
    final result = await ref
        .read(cartRemoteRepositoryProvider)
        .validateCoupon(code: code, itemIds: widget.itemIds);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _applying = null;
        _error = failure.message;
      }),
      (quote) => Navigator.pop(context, _VoucherResult.applied(quote)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final busy = _applying != null;
    final note = AppTypography.bodySmall.copyWith(color: AppPallete.textSecondary);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppPallete.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Vouchers', style: AppTypography.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Discounts are checked against the items you selected.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter voucher code',
                      errorText: _error,
                      errorMaxLines: 2,
                      filled: true,
                      fillColor: AppPallete.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: busy ? null : (value) => unawaited(_apply(value)),
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'Apply',
                  expand: false,
                  height: 48,
                  loading: busy && _applying == _code.text.trim().toUpperCase(),
                  onPressed: busy ? null : () => unawaited(_apply(_code.text)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: FutureBuilder<List<StoreVoucher>>(
                future: _wallet,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(color: AppPallete.primary),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text("We couldn't load your vouchers. You can still enter a code.", style: note);
                  }
                  final vouchers = snapshot.data ?? const <StoreVoucher>[];
                  if (vouchers.isEmpty) return Text('No vouchers to choose from yet.', style: note);
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: vouchers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final voucher = vouchers[index];
                      return _VoucherOption(
                        voucher: voucher,
                        selected: voucher.code == widget.currentCode,
                        loading: _applying == voucher.code,
                        onTap: busy ? null : () => unawaited(_apply(voucher.code)),
                      );
                    },
                  );
                },
              ),
            ),
            if (widget.currentCode != null) ...[
              const SizedBox(height: 8),
              AppButton(
                label: 'Remove voucher',
                variant: AppButtonVariant.ghost,
                onPressed: busy ? null : () => Navigator.pop(context, const _VoucherResult.cleared()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One voucher in the sheet. Ones that don't cover the selected lines are greyed out with the reason.
class _VoucherOption extends StatelessWidget {
  const _VoucherOption({
    required this.voucher,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  final StoreVoucher voucher;
  final bool selected;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final usable = voucher.applies != false;
    final saving = voucher.estimatedDiscount;
    final detail = !usable
        ? (voucher.reason ?? "Doesn't apply to these items")
        : saving != null && Formatters.decimal(saving) > Decimal.zero
            ? 'You save ${Formatters.money(saving)}'
            : voucher.minimum;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: usable ? AppPallete.surface : AppPallete.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppPallete.primary : AppPallete.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: usable ? voucher.tone.stub : AppPallete.border,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              voucher.headline,
              maxLines: 1,
              style: AppTypography.titleSmall.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: usable ? voucher.tone.ink : AppPallete.textHint,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voucher.code,
                  style: AppTypography.titleSmall.copyWith(
                    fontSize: 12.5,
                    color: usable ? AppPallete.ink : AppPallete.textHint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  voucher.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(fontSize: 10.5),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: usable ? AppPallete.success : AppPallete.danger,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppPallete.primary),
            )
          else if (selected)
            const Icon(PhosphorIconsFill.checkCircle, size: 18, color: AppPallete.primary)
          else if (usable)
            Text(
              'Apply',
              style: AppTypography.label.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppPallete.primaryText,
              ),
            ),
        ],
      ),
    );
    if (!usable) return Semantics(enabled: false, label: '${voucher.code}. $detail', child: card);
    return Pressable(semanticLabel: 'Apply ${voucher.code}', onTap: onTap, child: card);
  }
}
