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
import 'package:pickorbeet/features/home/view/widgets/category_section_card.dart';

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

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// New lines start selected. Lines the server dropped leave the selection.
  void _adopt(List<CartItemModel> items) {
    final ids = items.map((item) => item.id).toSet();
    for (final id in ids) {
      if (_known.add(id)) _selected.add(id);
    }
    final gone = _known.where((id) => !ids.contains(id)).toList();
    for (final id in gone) {
      _known.remove(id);
      _selected.remove(id);
    }
  }

  Future<void> _refresh() => ref.read(cartNotifierProvider.notifier).reload();

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

  Future<void> _editVoucher(String subtotal) async {
    final result = await showModalBottomSheet<_VoucherResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPallete.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) =>
          _VoucherSheet(subtotal: subtotal, currentCode: _couponCode),
    );
    if (result == null || !mounted) return;
    setState(() {
      _couponCode = result.quote?.code;
      _discount = result.quote?.discountAmount ?? '0';
      _pricedFor = result.quote == null ? null : subtotal;
    });
  }

  void _reprice(String code, String subtotal) {
    _pricedFor = subtotal;
    unawaited(() async {
      final result = await ref
          .read(cartRemoteRepositoryProvider)
          .validateCoupon(code: code, subtotal: subtotal);
      if (!mounted || _couponCode != code) return;
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
    final delivery = selected.isEmpty
        ? Decimal.zero
        : Formatters.decimal(cart.deliveryInsideDhaka);
    final total = itemsTotal - discount + delivery;
    final subtotalText = itemsTotal.toString();
    final code = _couponCode;
    if (code != null && _pricedFor != subtotalText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _couponCode == code && _pricedFor != subtotalText) {
          _reprice(code, subtotalText);
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
              onSelected: () => setState(() {
                final id = cart.items[i].id;
                if (!_selected.add(id)) _selected.remove(id);
              }),
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
            insideDhaka: cart.deliveryInsideDhaka,
            outsideDhaka: cart.deliveryOutsideDhaka,
            total: total.toString(),
            onDiscount: () => unawaited(_editVoucher(subtotalText)),
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
    final subtitle = item.shortDescription.trim().isNotEmpty
        ? item.shortDescription.trim()
        : item.variantLabel;
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
                        'Out of stock',
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
                          enabled: !item.isOutOfStock,
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
    required this.insideDhaka,
    required this.outsideDhaka,
    required this.total,
    required this.onDiscount,
    required this.canCheckout,
    required this.onCheckout,
  });

  final int units;
  final String itemsTotal;
  final String discount;
  final String? couponCode;
  final String delivery;
  final String insideDhaka;
  final String outsideDhaka;
  final String total;
  final VoidCallback onDiscount;
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
                Pressable(
                  semanticLabel: couponCode == null
                      ? 'Add a voucher'
                      : 'Voucher $couponCode',
                  onTap: onDiscount,
                  child: _MoneyRow(
                    label: couponCode == null
                        ? 'Discount'
                        : 'Discount · $couponCode',
                    value: discount,
                    deduction: hasDiscount,
                    labelStyle: label.copyWith(color: AppPallete.primaryText),
                    valueStyle: amount.copyWith(
                      color: hasDiscount ? AppPallete.success : AppPallete.ink,
                    ),
                  ),
                ),
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
                    Text(Formatters.money(delivery), style: amount),
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

class _VoucherSheet extends ConsumerStatefulWidget {
  const _VoucherSheet({required this.subtotal, this.currentCode});

  final String subtotal;
  final String? currentCode;

  @override
  ConsumerState<_VoucherSheet> createState() => _VoucherSheetState();
}

class _VoucherSheetState extends ConsumerState<_VoucherSheet> {
  late final _code = TextEditingController(text: widget.currentCode ?? '');
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a voucher code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(cartRemoteRepositoryProvider)
        .validateCoupon(code: code, subtotal: widget.subtotal);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _busy = false;
        _error = failure.message;
      }),
      (quote) => Navigator.pop(context, _VoucherResult.applied(quote)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
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
          Text('Voucher', style: AppTypography.titleMedium),
          const SizedBox(height: 4),
          Text(
            'The discount is checked against the items you selected.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Voucher code',
              errorText: _error,
              filled: true,
              fillColor: AppPallete.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => unawaited(_apply()),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Apply',
            loading: _busy,
            onPressed: _busy ? null : () => unawaited(_apply()),
          ),
          if (widget.currentCode != null) ...[
            const SizedBox(height: 8),
            AppButton(
              label: 'Remove voucher',
              variant: AppButtonVariant.ghost,
              onPressed: _busy
                  ? null
                  : () =>
                        Navigator.pop(context, const _VoucherResult.cleared()),
            ),
          ],
        ],
      ),
    );
  }
}
