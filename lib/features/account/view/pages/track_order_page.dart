import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/model/order_detail.dart';
import 'package:pickorbeet/features/account/repositories/orders_repository.dart';
import 'package:pickorbeet/features/account/view/orders_palette.dart';
import 'package:pickorbeet/features/account/view/widgets/shipment_card.dart';
import 'package:pickorbeet/features/account/viewmodel/orders_controller.dart';
import 'package:url_launcher/url_launcher.dart';

/// Look up a parcel by order number or Steadfast tracking code.
class TrackOrderPage extends ConsumerStatefulWidget {
  const TrackOrderPage({super.key, this.initialQuery = '', this.orderId});

  final String initialQuery;
  final String? orderId;

  @override
  ConsumerState<TrackOrderPage> createState() => _TrackOrderPageState();
}

class _TrackOrderPageState extends ConsumerState<TrackOrderPage> {
  late final TextEditingController _query = TextEditingController(text: widget.initialQuery);
  final _phone = TextEditingController();
  TrackingResult? _result;
  var _loading = false;
  var _refreshing = false;
  var _wait = 0;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isNotEmpty) {
      unawaited(_search());
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _query.dispose();
    _phone.dispose();
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

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty) {
      showToast(context, 'Enter an order number or a Steadfast tracking code', kind: ToastKind.error);
      return;
    }
    setState(() => _loading = true);
    final result = await ref.read(ordersRepositoryProvider).track(query: query, phone: _phone.text);
    if (!mounted) return;
    setState(() => _loading = false);
    result.fold(
      (failure) {
        setState(() => _result = null);
        showToast(context, failure.message, kind: ToastKind.error);
      },
      (found) => setState(() {
        _result = found;
        _arm(found.shipment?.refreshAvailableIn ?? 0);
      }),
    );
  }

  Future<void> _refresh() async {
    final id = _result?.id ?? widget.orderId;
    if (id == null || id.isEmpty) return;
    setState(() => _refreshing = true);
    final result = await ref.read(ordersRepositoryProvider).refreshShipment(id);
    if (!mounted) return;
    setState(() => _refreshing = false);
    result.fold(
      (failure) {
        final wait = failure.retryAfter?.inSeconds ?? 0;
        if (wait > 0) _arm(wait);
        showToast(context, failure.message, kind: ToastKind.error);
      },
      (order) {
        final current = _result;
        setState(() {
          _result = TrackingResult(
            id: order.id,
            orderNumber: order.orderNumber,
            reference: current?.reference,
            status: order.status,
            paymentStatus: order.paymentStatus,
            createdAt: order.createdAt ?? current?.createdAt,
            history: order.history,
            shipment: order.shipment,
          );
          _arm(order.shipment?.refreshAvailableIn ?? 60);
        });
        ref.invalidate(ordersControllerProvider);
        showToast(context, 'Courier status updated', kind: ToastKind.success);
      },
    );
  }

  Future<void> _open(String? url) async {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      if (mounted) showToast(context, 'Could not open the tracking page.', kind: ToastKind.error);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final signedIn = ref.watch(sessionNotifierProvider) == SessionStatus.signedIn;
    final shipment = result?.shipment;
    final canRefresh = signedIn && (result?.id ?? widget.orderId) != null && shipment != null;

    return Scaffold(
      backgroundColor: OrdersPalette.page,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => context.canPop() ? context.pop() : context.go(Routes.home),
                    semanticLabel: 'Back',
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(PhosphorIconsRegular.arrowLeft, color: OrdersPalette.ink),
                    ),
                  ),
                  Text(
                    'Track order',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800, color: OrdersPalette.ink),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Text(
                    'Order number or Steadfast tracking code',
                    style: AppTypography.bodySmall.copyWith(color: OrdersPalette.inkSoft, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _Field(controller: _query, hint: 'PO783256 or SF123456789BD', onSubmit: _search),
                  const SizedBox(height: 10),
                  Text(
                    'Phone, if you used one at checkout',
                    style: AppTypography.bodySmall.copyWith(color: OrdersPalette.inkSoft, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _Field(controller: _phone, hint: '01712345678', keyboard: TextInputType.phone, onSubmit: _search),
                  const SizedBox(height: 14),
                  AppButton(
                    label: 'Track',
                    icon: PhosphorIconsRegular.magnifyingGlass,
                    loading: _loading,
                    onPressed: _loading ? null : () => unawaited(_search()),
                  ),
                  if (result != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      result.displayNumber,
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800, color: OrdersPalette.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.statusLabel} · ${result.paymentStatus}',
                      style: AppTypography.bodySmall.copyWith(color: OrdersPalette.muted),
                    ),
                    if (result.reference != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Reference ${result.reference}',
                        style: AppTypography.bodySmall.copyWith(color: OrdersPalette.hint, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (shipment != null)
                      ShipmentCard(
                        shipment: shipment,
                        refreshing: _refreshing,
                        waitSeconds: _wait,
                        onRefresh: canRefresh ? () => unawaited(_refresh()) : null,
                        onOpenTracking: shipment.trackingUrl == null ? null : () => unawaited(_open(shipment.trackingUrl)),
                        onCopy: shipment.trackingCode == null
                            ? null
                            : () => unawaited(copyTrackingCode(context, shipment.trackingCode!, (message) {
                                showToast(context, message, kind: ToastKind.success);
                              })),
                      )
                    else
                      const _EmptyParcel(),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.onSubmit,
    this.keyboard = TextInputType.text,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;
  final TextInputType keyboard;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmit(),
      cursorColor: OrdersPalette.orange,
      style: AppTypography.bodyMedium.copyWith(color: OrdersPalette.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyMedium.copyWith(color: OrdersPalette.hint),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: OrdersPalette.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: OrdersPalette.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: OrdersPalette.orange, width: 1.4)),
      ),
    );
  }
}

class _EmptyParcel extends StatelessWidget {
  const _EmptyParcel();

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
      child: Text(
        'This order has not been handed to Steadfast yet.',
        style: AppTypography.bodySmall.copyWith(color: OrdersPalette.inkSoft),
      ),
    );
  }
}
