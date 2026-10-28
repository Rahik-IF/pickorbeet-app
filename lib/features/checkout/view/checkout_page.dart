import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/models/address_model.dart';
import 'package:pickorbeet/core/motion/entrance.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/providers/cart_notifier.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/core/widgets/state_views.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/repositories/address_repository.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:pickorbeet/features/cart/repositories/cart_remote_repository.dart';
import 'package:pickorbeet/features/checkout/checkout_args.dart';
import 'package:pickorbeet/features/checkout/checkout_logic.dart';
import 'package:pickorbeet/features/checkout/checkout_repository.dart';
import 'package:pickorbeet/features/checkout/view/checkout_sections.dart';
import 'package:url_launcher/url_launcher.dart';

/// One-screen checkout: address, items, payment, and the total, matched to the checkout design.
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key, this.args = const CheckoutArgs()});

  final CheckoutArgs args;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _postal = TextEditingController();

  String? _selectedId;
  CheckoutPayment _payment = CheckoutPayment.cod;
  String? _coupon;
  String _discount = '0';
  String? _pricedFor;
  var _placing = false;
  var _placed = false;
  var _step = 0;
  var _showGuestErrors = false;

  @override
  void initState() {
    super.initState();
    final code = widget.args.couponCode?.trim();
    _coupon = code == null || code.isEmpty ? null : code;
    for (final controller in [
      _name,
      _phone,
      _line1,
      _line2,
      _city,
      _district,
      _postal,
    ]) {
      controller.addListener(_onGuestEdit);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _line1,
      _line2,
      _city,
      _district,
      _postal,
    ]) {
      controller.removeListener(_onGuestEdit);
      controller.dispose();
    }
    super.dispose();
  }

  void _onGuestEdit() {
    if (mounted) setState(() {});
  }

  bool _insideDhaka({required bool signedIn, required AddressModel? selected}) {
    if (signedIn) {
      if (selected == null) return true;
      return shipsInsideDhaka(city: selected.city, district: selected.district);
    }
    if (_city.text.trim().isEmpty && _district.text.trim().isEmpty) return true;
    return shipsInsideDhaka(city: _city.text, district: _district.text);
  }

  List<CartItemModel> _linesOf(CartModel cart) {
    if (widget.args.itemIds.isEmpty) return cart.items;
    final wanted = widget.args.itemIds.toSet();
    return [
      for (final item in cart.items)
        if (wanted.contains(item.id)) item,
    ];
  }

  String? _effectiveId(List<AddressModel> items) {
    if (items.isEmpty) return null;
    for (final item in items) {
      if (item.id == _selectedId) return item.id;
    }
    for (final item in items) {
      if (item.isDefault) return item.id;
    }
    return items.first.id;
  }

  AddressModel? _selectedAddress(List<AddressModel> items) {
    final id = _effectiveId(items);
    if (id == null) return null;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _scheduleQuote(String subtotal) {
    final code = _coupon;
    if (code == null || _pricedFor == subtotal) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _coupon == code && _pricedFor != subtotal) {
        unawaited(_reprice(code, subtotal));
      }
    });
  }

  Future<void> _reprice(String code, String subtotal) async {
    _pricedFor = subtotal;
    final result = await ref
        .read(cartRemoteRepositoryProvider)
        .validateCoupon(code: code, subtotal: subtotal);
    if (!mounted || _coupon != code || _pricedFor != subtotal) return;
    result.fold((failure) {
      setState(() {
        _coupon = null;
        _discount = '0';
        _pricedFor = null;
      });
      showToast(context, failure.message, kind: ToastKind.error);
    }, (quote) => setState(() => _discount = quote.discountAmount));
  }

  Future<void> _refresh() async {
    await ref.read(cartNotifierProvider.notifier).reload();
    if (!mounted) return;
    ref.invalidate(checkoutAddressesProvider);
    await ref.read(checkoutAddressesProvider.future);
  }

  Future<void> _setQuantity(CartItemModel item, int quantity) async {
    final failure = await ref
        .read(cartNotifierProvider.notifier)
        .setQuantity(item.id, quantity);
    if (!mounted || failure == null) return;
    showToast(context, failure.message, kind: ToastKind.error);
  }

  void _editCart() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.cart);
    }
  }

  Future<void> _addAddress() async {
    final signedIn =
        ref.read(sessionNotifierProvider) == SessionStatus.signedIn;
    if (!signedIn) {
      await context.push(Routes.loginFrom(widget.args.location));
      return;
    }
    await context.push(Routes.newAddress);
    if (!mounted) return;
    ref.invalidate(checkoutAddressesProvider);
    ref.invalidate(addressesProvider);
  }

  Future<void> _editAddress(AddressModel address) async {
    await context.push(Routes.editAddress(address.id));
    if (!mounted) return;
    ref.invalidate(checkoutAddressesProvider);
    ref.invalidate(addressesProvider);
  }

  Map<String, String> _guestErrors() {
    final errors = <String, String>{};
    if (_name.text.trim().isEmpty) errors['name'] = 'Enter the recipient name';
    if (!RegExp(r'^01\d{9}$').hasMatch(Formatters.phoneForApi(_phone.text))) {
      errors['phone'] = 'Enter a valid mobile number';
    }
    if (_line1.text.trim().isEmpty) {
      errors['line1'] = 'Enter the delivery address';
    }
    if (_city.text.trim().isEmpty) errors['city'] = 'Enter the city';
    if (_district.text.trim().isEmpty) {
      errors['district'] = 'Enter the district';
    }
    return errors;
  }

  Future<void> _celebrate() async {
    if (!mounted) return;
    setState(() {
      _placing = false;
      _placed = true;
    });
    if (Motion.reduced(context)) return;
    for (var step = 1; step <= 3; step++) {
      await Future<void>.delayed(const Duration(milliseconds: 170));
      if (!mounted) return;
      setState(() => _step = step);
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }

  Future<void> _openPayment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        showToast(context, 'Order placed. Open it to finish payment.');
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Order placed. Open it to finish payment.');
      }
    }
  }

  void _leaveFor(PlacedOrder order) {
    if (!mounted) return;
    if (order.id.isEmpty) {
      context.go(Routes.orders);
      return;
    }
    context.go(Routes.order(order.id));
  }

  Future<void> _submit() async {
    if (_placing || _placed || !_payment.available) return;
    final cart = ref.read(cartNotifierProvider).valueOrNull;
    if (cart == null) return;
    final lines = _linesOf(cart);
    if (lines.isEmpty) return;
    if (lines.any((item) => item.isOutOfStock)) {
      showToast(
        context,
        'Remove out-of-stock items to continue.',
        kind: ToastKind.error,
      );
      return;
    }

    final signedIn =
        ref.read(sessionNotifierProvider) == SessionStatus.signedIn;
    final Map<String, Object?> body;
    if (signedIn) {
      final addresses =
          ref.read(checkoutAddressesProvider).valueOrNull ??
          const <AddressModel>[];
      final address = _selectedAddress(addresses);
      if (address == null) {
        showToast(
          context,
          'Add a delivery address to continue.',
          kind: ToastKind.error,
        );
        return;
      }
      body = checkoutPayload(
        name: address.fullName,
        phone: address.phone,
        line1: address.addressLine1,
        line2: address.addressLine2,
        city: address.city,
        district: address.district,
        postalCode: address.postalCode,
        couponCode: _coupon,
        itemIds: [for (final line in lines) line.id],
        payment: _payment,
      );
    } else {
      final errors = _guestErrors();
      if (errors.isNotEmpty) {
        setState(() => _showGuestErrors = true);
        showToast(context, errors.values.first, kind: ToastKind.error);
        return;
      }
      body = checkoutPayload(
        name: _name.text,
        phone: _phone.text,
        line1: _line1.text,
        line2: _line2.text,
        city: _city.text,
        district: _district.text,
        postalCode: _postal.text,
        couponCode: _coupon,
        itemIds: [for (final line in lines) line.id],
        payment: _payment,
        asGuest: true,
      );
    }

    setState(() => _placing = true);
    final result = await ref.read(checkoutRepositoryProvider).place(body);
    if (!mounted) return;
    switch (result) {
      case Left(value: final failure):
        setState(() => _placing = false);
        showToast(context, failure.message, kind: ToastKind.error);
      case Right(value: final order):
        try {
          await ref.read(cartNotifierProvider.notifier).reload();
        } catch (_) {}
        if (!mounted) return;
        if (_payment.online) {
          final payment = await ref
              .read(checkoutRepositoryProvider)
              .paymentUrl(order.id);
          if (!mounted) return;
          switch (payment) {
            case Left(value: final failure):
              setState(() => _placing = false);
              showToast(
                context,
                'Order placed. ${failure.message}',
                kind: ToastKind.error,
              );
              _leaveFor(order);
            case Right(value: final url):
              await _celebrate();
              if (!mounted) return;
              await _openPayment(url);
              _leaveFor(order);
          }
        } else {
          await _celebrate();
          if (!mounted) return;
          showToast(
            context,
            'Order ${order.orderNumber} placed',
            kind: ToastKind.success,
          );
          _leaveFor(order);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn =
        ref.watch(sessionNotifierProvider) == SessionStatus.signedIn;
    final addresses = ref.watch(checkoutAddressesProvider);
    final cart = ref.watch(cartNotifierProvider);

    return Scaffold(
      backgroundColor: CheckoutColors.page,
      body: Column(
        children: [
          const CheckoutHeader(),
          Expanded(
            child: cart.when(
              skipLoadingOnReload: true,
              loading: () => const CheckoutSkeleton(),
              error: (error, _) => ErrorState(
                failure: error,
                onRetry: () => unawaited(_refresh()),
              ),
              data: (model) =>
                  _content(model, signedIn: signedIn, addresses: addresses),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(
    CartModel cart, {
    required bool signedIn,
    required AsyncValue<List<AddressModel>> addresses,
  }) {
    final lines = _linesOf(cart);
    if (lines.isEmpty) {
      return EmptyState(
        icon: PhosphorIconsDuotone.shoppingBag,
        title: cart.isEmpty ? 'Your cart is empty' : 'Nothing to check out',
        message: cart.isEmpty
            ? 'Add a product before placing an order.'
            : 'The items you selected are no longer in your cart.',
        actionLabel: 'Back to cart',
        onAction: _editCart,
      );
    }

    final saved = addresses.valueOrNull ?? const <AddressModel>[];
    final selected = signedIn ? _selectedAddress(saved) : null;
    final inside = _insideDhaka(signedIn: signedIn, selected: selected);
    final itemsTotal = lines.fold(
      Decimal.zero,
      (sum, item) => sum + Formatters.decimal(item.totalPrice),
    );
    var discount = Formatters.decimal(_discount);
    if (discount < Decimal.zero) discount = Decimal.zero;
    if (discount > itemsTotal) discount = itemsTotal;
    final deliveryAmount = inside
        ? cart.deliveryInsideDhaka
        : cart.deliveryOutsideDhaka;
    final delivery = Formatters.decimal(deliveryAmount);
    final total = itemsTotal - discount + delivery;
    _scheduleQuote(itemsTotal.toString());

    final outOfStock = lines.any((item) => item.isOutOfStock);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppPallete.primary,
      backgroundColor: AppPallete.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          CheckoutColors.margin,
          16,
          CheckoutColors.margin,
          20 + bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CheckoutStepper(active: _step),
          ).entrance(),
          const SizedBox(height: 14),
          DeliveryAddressCard(
            actionLabel: signedIn ? 'Add New' : 'Sign in',
            actionIcon: signedIn
                ? PhosphorIconsBold.plus
                : PhosphorIconsRegular.signIn,
            onAction: () => unawaited(_addAddress()),
            child: _addressBody(signedIn, addresses, selected?.id),
          ).entrance(index: 1),
          const SizedBox(height: 12),
          OrderItemsCard(
            items: lines,
            onQuantity: (item, quantity) =>
                unawaited(_setQuantity(item, quantity)),
            onEditCart: _editCart,
          ).entrance(index: 2),
          const SizedBox(height: 12),
          PaymentMethodCard(
            selected: _payment,
            enabled: !_placing && !_placed,
            onChanged: (method) {
              if (!method.available) return;
              setState(() => _payment = method);
            },
          ).entrance(index: 3),
          const SizedBox(height: 12),
          OrderSummaryCard(
            units: lines.fold(0, (sum, item) => sum + item.quantity),
            itemsTotal: itemsTotal.toString(),
            discount: discount.toString(),
            delivery: delivery.toString(),
            total: total.toString(),
            insideDhaka: cart.deliveryInsideDhaka,
            outsideDhaka: cart.deliveryOutsideDhaka,
          ).entrance(index: 4),
          if (outOfStock) ...[
            const SizedBox(height: 12),
            Text(
              'An item is out of stock. Update the cart to continue.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(
                color: AppPallete.danger,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 14),
          AppButton(
            label: _placed ? 'Order placed' : 'Place Order',
            trailingIcon: _placed
                ? PhosphorIconsBold.check
                : PhosphorIconsBold.arrowRight,
            height: 50,
            radius: 14,
            loading: _placing,
            textStyle: AppTypography.button.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            onPressed: outOfStock || _placing
                ? null
                : (_placed ? () {} : () => unawaited(_submit())),
          ).entrance(index: 5),
        ],
      ),
    );
  }

  Widget _addressBody(
    bool signedIn,
    AsyncValue<List<AddressModel>> addresses,
    String? selectedId,
  ) {
    if (!signedIn) {
      final errors = _showGuestErrors
          ? _guestErrors()
          : const <String, String>{};
      return _GuestDeliveryForm(
        name: _name,
        phone: _phone,
        line1: _line1,
        line2: _line2,
        city: _city,
        district: _district,
        postal: _postal,
        errors: errors,
      );
    }
    return addresses.when(
      skipLoadingOnReload: true,
      loading: () => const AddressListSkeleton(),
      error: (error, _) => ErrorState(
        failure: error,
        compact: true,
        onRetry: () => ref.invalidate(checkoutAddressesProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No delivery address yet. Add a home or office to place this order.',
              style: AppTypography.bodyLarge.copyWith(
                fontSize: 12.5,
                height: 1.4,
                color: CheckoutColors.body,
              ),
            ),
          );
        }
        final selected = selectedId;
        return Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              AddressChoice(
                address: items[i],
                selected: items[i].id == selected,
                onSelect: () => setState(() => _selectedId = items[i].id),
                onEdit: () => unawaited(_editAddress(items[i])),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _GuestDeliveryForm extends StatelessWidget {
  const _GuestDeliveryForm({
    required this.name,
    required this.phone,
    required this.line1,
    required this.line2,
    required this.city,
    required this.district,
    required this.postal,
    required this.errors,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController line1;
  final TextEditingController line2;
  final TextEditingController city;
  final TextEditingController district;
  final TextEditingController postal;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GuestField(
          label: 'Full name',
          controller: name,
          error: errors['name'],
          action: TextInputAction.next,
          autofill: AutofillHints.name,
        ),
        const SizedBox(height: 8),
        _GuestField(
          label: 'Phone',
          controller: phone,
          error: errors['phone'],
          keyboard: TextInputType.phone,
          action: TextInputAction.next,
          autofill: AutofillHints.telephoneNumber,
        ),
        const SizedBox(height: 8),
        _GuestField(
          label: 'Address',
          controller: line1,
          error: errors['line1'],
          action: TextInputAction.next,
          autofill: AutofillHints.streetAddressLine1,
        ),
        const SizedBox(height: 8),
        _GuestField(
          label: 'Area (optional)',
          controller: line2,
          action: TextInputAction.next,
          autofill: AutofillHints.streetAddressLine2,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _GuestField(
                label: 'City',
                controller: city,
                error: errors['city'],
                action: TextInputAction.next,
                autofill: AutofillHints.addressCity,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GuestField(
                label: 'District',
                controller: district,
                error: errors['district'],
                action: TextInputAction.next,
                autofill: AutofillHints.addressState,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _GuestField(
          label: 'Postal code (optional)',
          controller: postal,
          keyboard: TextInputType.number,
          action: TextInputAction.done,
          autofill: AutofillHints.postalCode,
        ),
      ],
    );
  }
}

class _GuestField extends StatelessWidget {
  const _GuestField({
    required this.label,
    required this.controller,
    this.error,
    this.keyboard,
    this.action,
    this.autofill,
  });

  final String label;
  final TextEditingController controller;
  final String? error;
  final TextInputType? keyboard;
  final TextInputAction? action;
  final String? autofill;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      textInputAction: action,
      autofillHints: [if (autofill != null) autofill!],
      decoration: InputDecoration(labelText: label, errorText: error),
    );
  }
}
