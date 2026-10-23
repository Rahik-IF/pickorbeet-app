import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/core/widgets/state_views.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/model/order_detail.dart';
import 'package:pickorbeet/features/account/repositories/orders_repository.dart';
import 'package:pickorbeet/features/account/view/orders_palette.dart';
import 'package:pickorbeet/features/account/view/widgets/shipment_card.dart';
import 'package:pickorbeet/features/account/viewmodel/orders_controller.dart';
import 'package:url_launcher/url_launcher.dart';

/// One order: what was bought, where it is going, and the Steadfast parcel.
class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  OrderDetail? _order;
  AppFailure? _failure;
  var _loading = true;
  var _refreshing = false;
  var _wait = 0;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  void _arm(int seconds) {
    _countdown?.cancel();
    _wait = seconds;
    if (seconds <= 0) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _wait -= 1;
        if (_wait <= 0) timer.cancel();
      });
    });
  }

  Future<void> _load() async {
    final result = await ref.read(ordersRepositoryProvider).detail(widget.orderId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _failure = failure;
        _loading = false;
      }),
      (order) => setState(() {
        _order = order;
        _failure = null;
        _loading = false;
        _arm(order.shipment?.refreshAvailableIn ?? 0);
      }),
    );
  }

  Future<void> _refreshCourier() async {
    setState(() => _refreshing = true);
    final result = await ref.read(ordersRepositoryProvider).refreshShipment(widget.orderId);
    if (!mounted) return;
    setState(() => _refreshing = false);
    result.fold(
      (failure) {
        final wait = failure.retryAfter?.inSeconds ?? 0;
        if (wait > 0) _arm(wait);
        showToast(context, failure.message, kind: ToastKind.error);
      },
      (order) {
        setState(() {
          _order = order;
          _arm(order.shipment?.refreshAvailableIn ?? 60);
        });
        ref.invalidate(ordersControllerProvider);
        showToast(context, 'Courier status updated', kind: ToastKind.success);
      },
    );
  }

  Future<void> _openTracking(String? url) async {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      if (mounted) showToast(context, 'Could not open the tracking page.', kind: ToastKind.error);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.orders);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrdersPalette.page,
      body: SafeArea(
        child: Column(
          children: [
            _Bar(title: _order?.displayNumber ?? 'Order', onBack: _back),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: OrdersPalette.orange));
    }
    final failure = _failure;
    final order = _order;
    if (failure != null || order == null) {
      return ErrorState(failure: failure ?? const AppFailure(), onRetry: () {
        setState(() {
          _loading = true;
          _failure = null;
        });
        unawaited(_load());
      });
    }
    final shipment = order.shipment;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _StatusRow(label: order.statusLabel, payment: order.paymentStatus),
        const SizedBox(height: 12),
        if (shipment != null)
          ShipmentCard(
            shipment: shipment,
            refreshing: _refreshing,
            waitSeconds: _wait,
            onRefresh: _refreshCourier,
            onOpenTracking: shipment.trackingUrl == null ? null : () => unawaited(_openTracking(shipment.trackingUrl)),
            onCopy: shipment.trackingCode == null
                ? null
                : () => unawaited(copyTrackingCode(context, shipment.trackingCode!, (message) {
                    showToast(context, message, kind: ToastKind.success);
                  })),
          )
        else
          const _Note(text: 'This order has not been handed to Steadfast yet.'),
        const SizedBox(height: 16),
        _Section(
          title: 'Items',
          child: Column(
            children: [
              for (final item in order.items) ...[
                _Line(item: item),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Deliver to',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (order.shippingName.isNotEmpty)
                Text(order.shippingName, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
              if (order.shippingPhone.isNotEmpty)
                Text(Formatters.phone(order.shippingPhone), style: AppTypography.bodySmall.copyWith(color: OrdersPalette.muted)),
              if (order.address.isNotEmpty)
                Text(order.address, style: AppTypography.bodySmall.copyWith(color: OrdersPalette.inkSoft)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Payment',
          child: Column(
            children: [
              _MoneyRow('Subtotal', Formatters.money(order.subtotal)),
              _MoneyRow('Delivery', Formatters.money(order.deliveryCharge)),
              if (Formatters.decimal(order.discount) > Formatters.decimal('0'))
                _MoneyRow('Discount', Formatters.deduction(order.discount)),
              const Divider(height: 16, color: OrdersPalette.line),
              _MoneyRow('Total', Formatters.money(order.total), strong: true),
              const SizedBox(height: 4),
              Text(
                '${order.paymentStatus}${order.paymentMethod == null ? '' : ' · ${order.paymentMethod}'}',
                style: AppTypography.bodySmall.copyWith(color: OrdersPalette.muted),
              ),
            ],
          ),
        ),
        if (order.history.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: 'Order timeline',
            child: Column(
              children: [
                for (final entry in order.history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: const BoxDecoration(color: OrdersPalette.orange, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.label, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                              if (entry.note.isNotEmpty)
                                Text(entry.note, style: AppTypography.bodySmall.copyWith(color: OrdersPalette.inkSoft)),
                              if (entry.createdAt != null)
                                Text(
                                  Formatters.dateTime(entry.createdAt),
                                  style: AppTypography.bodySmall.copyWith(color: OrdersPalette.hint, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          Pressable(
            onTap: onBack,
            semanticLabel: 'Back',
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(PhosphorIconsRegular.arrowLeft, color: OrdersPalette.ink),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800, color: OrdersPalette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.payment});

  final String label;
  final String payment;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: OrdersPalette.pillOrange, borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: AppTypography.bodySmall.copyWith(color: OrdersPalette.orangeDeep, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 8),
        Text(payment, style: AppTypography.bodySmall.copyWith(color: OrdersPalette.muted)),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OrdersPalette.line),
      ),
      child: Text(text, style: AppTypography.bodySmall.copyWith(color: OrdersPalette.inkSoft)),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OrdersPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800, color: OrdersPalette.ink)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.item});

  final OrderLine item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: AppNetworkImage(
            url: item.image,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
              if (item.detail.isNotEmpty)
                Text(item.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall.copyWith(color: OrdersPalette.muted, fontSize: 11)),
              Text('Qty ${item.quantity}', style: AppTypography.bodySmall.copyWith(color: OrdersPalette.muted, fontSize: 11)),
            ],
          ),
        ),
        Text(Formatters.money(item.totalPrice), style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w800, color: OrdersPalette.price)),
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodySmall.copyWith(
      color: strong ? OrdersPalette.ink : OrdersPalette.inkSoft,
      fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style.copyWith(color: strong ? OrdersPalette.price : OrdersPalette.ink)),
        ],
      ),
    );
  }
}
