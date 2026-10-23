import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/motion/entrance.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/cart_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/widgets/bottom_nav.dart';
import 'package:pickorbeet/core/widgets/brand_lockup.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';
import 'package:pickorbeet/core/widgets/header_background.dart';
import 'package:pickorbeet/core/widgets/skeleton.dart';
import 'package:pickorbeet/core/widgets/state_views.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/model/customer_order.dart';
import 'package:pickorbeet/features/account/repositories/order_summary_repository.dart';
import 'package:pickorbeet/features/account/view/orders_palette.dart';
import 'package:pickorbeet/features/account/view/widgets/order_card.dart';
import 'package:pickorbeet/features/account/viewmodel/orders_controller.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

/// My Orders: search, status chips, and a card for every stage in the design.
class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key, this.initialStatus});

  final String? initialStatus;

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _cancelling = <String>{};
  final _buying = <String>{};
  Timer? _debounce;
  var _focused = false;
  late OrderFilter _filter;

  OrdersController get _orders =>
      ref.read(ordersControllerProvider(widget.initialStatus).notifier);

  @override
  void initState() {
    super.initState();
    _filter = OrderFilter.fromQuery(widget.initialStatus);
    _scroll.addListener(_onScroll);
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels < position.maxScrollExtent - 360) return;
    unawaited(_loadMore());
  }

  Future<void> _loadMore() async {
    final message = await _orders.loadMore();
    if (message != null && mounted) {
      showToast(context, message, kind: ToastKind.error);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) unawaited(_applySearch(value));
    });
    setState(() {});
  }

  Future<void> _applySearch(String value) async {
    final message = await _orders.applySearch(value);
    if (message != null && mounted) {
      showToast(context, message, kind: ToastKind.error);
    }
  }

  Future<void> _select(OrderFilter filter) async {
    if (filter == _filter) {
      final message = await _orders.setFilter(filter);
      if (message != null && mounted) {
        showToast(context, message, kind: ToastKind.error);
      }
      return;
    }
    final previous = _filter;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _filter = filter);
    if (_scroll.hasClients) {
      unawaited(
        _scroll.animateTo(
          0,
          duration: Motion.of(context, Motion.medium),
          curve: Motion.emphasizedDecelerate,
        ),
      );
    }
    final message = await _orders.setFilter(filter);
    if (!mounted) return;
    if (message != null) {
      setState(() => _filter = previous);
      showToast(context, message, kind: ToastKind.error);
    }
  }

  Future<void> _refresh() async {
    try {
      await _orders.refresh();
    } on Object catch (error) {
      if (!mounted) return;
      showToast(
        context,
        error is AppFailure ? error.message : 'Could not refresh orders.',
        kind: ToastKind.error,
      );
    }
  }

  void _openTab(int index) {
    const tabs = <String>[
      Routes.home,
      Routes.categories,
      Routes.wishlist,
      Routes.account,
      Routes.cart,
    ];
    context.go(tabs[index]);
  }

  Future<void> _cancel(CustomerOrder order) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _CancelSheet(order: order),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling.add(order.id));
    final message = await _orders.cancel(order.id);
    if (!mounted) return;
    setState(() => _cancelling.remove(order.id));
    if (message != null) {
      showToast(context, message, kind: ToastKind.error);
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    showToast(
      context,
      '${order.displayNumber} cancelled',
      kind: ToastKind.success,
    );
  }

  Future<void> _track(CustomerOrder order) async {
    final raw = order.trackingUrl;
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri != null && await canLaunchUrl(uri)) {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
    }
    if (!mounted) return;
    final params = <String, String>{
      'order': order.orderNumber,
      if (order.trackingCode != null) 'tracking': order.trackingCode!,
    };
    unawaited(
      context.push(Uri(path: Routes.trackOrder, queryParameters: params).toString()),
    );
  }

  Future<void> _buyAgain(CustomerOrder order) async {
    final preview = order.preview;
    final productId = preview?.productId;
    if (productId == null || productId.isEmpty) {
      showToast(
        context,
        'This product is no longer available.',
        kind: ToastKind.error,
      );
      return;
    }
    setState(() => _buying.add(order.id));
    final result = await ref
        .read(cartNotifierProvider.notifier)
        .add(
          CartLine(
            productId: productId,
            variantId: preview?.variantId,
            quantity: 1,
          ),
        );
    if (!mounted) return;
    setState(() => _buying.remove(order.id));
    result.fold(
      (failure) => showToast(context, failure.message, kind: ToastKind.error),
      (_) {
        unawaited(HapticFeedback.lightImpact());
        showToast(
          context,
          'Added to cart',
          kind: ToastKind.success,
          actionLabel: 'View cart',
          onAction: () => context.go(Routes.cart),
        );
      },
    );
  }

  Future<void> _review(CustomerOrder order) async {
    final name = order.preview?.name ?? 'this order';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _ReviewSheet(productName: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ordersControllerProvider(widget.initialStatus));
    final summary = ref.watch(orderSummaryProvider).valueOrNull;
    final refreshing = async.isLoading && async.hasValue;

    return Scaffold(
      backgroundColor: OrdersPalette.page,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: AppBottomNav(
        currentIndex: 3,
        cartCount: ref.watch(cartCountProvider),
        onSelect: _openTab,
      ),
      body: Column(
        children: [
          const _OrdersHeader(),
          AnimatedContainer(
            duration: Motion.of(context, Motion.short),
            height: refreshing ? 2 : 0,
            child: const LinearProgressIndicator(
              minHeight: 2,
              color: OrdersPalette.orange,
              backgroundColor: Colors.transparent,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: OrdersPalette.orange,
              backgroundColor: Colors.white,
              child: CustomScrollView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _intro(summary)),
                  ..._results(async),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro(OrderSummary? summary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: _TitleBlock()),
              const SizedBox(width: 10),
              _SearchField(
                controller: _search,
                focusNode: _focus,
                focused: _focused,
                onChanged: _onSearchChanged,
                onClear: () {
                  _search.clear();
                  _debounce?.cancel();
                  unawaited(_applySearch(''));
                  setState(() {});
                },
              ),
            ],
          ).entrance(rise: 8),
          const SizedBox(height: 12),
          _FilterRow(
            selected: _filter,
            summary: summary,
            onSelect: (filter) => unawaited(_select(filter)),
          ).entrance(index: 1, rise: 8),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  List<Widget> _results(AsyncValue<OrdersState> async) {
    if (async.isLoading && !async.hasValue) {
      return const [SliverToBoxAdapter(child: _SkeletonList())];
    }
    if (async.hasError && !async.hasValue) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(failure: async.error!, onRetry: _refresh),
        ),
      ];
    }
    final data = async.valueOrNull;
    if (data == null) {
      return const [SliverToBoxAdapter(child: SizedBox.shrink())];
    }
    if (data.orders.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: PhosphorIconsRegular.package,
            title: _emptyTitle(data),
            message: _emptyMessage(data),
            tint: OrdersPalette.orange,
          ).entrance(),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(13, 0, 13, 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final order = data.orders[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RepaintBoundary(
                key: ValueKey('${data.filter.name}-$index-${order.id}'),
                child: OrderCard(
                  order: order,
                  cancelling: _cancelling.contains(order.id),
                  buying: _buying.contains(order.id),
                  onDetails: () => context.push(Routes.order(order.id)),
                  onCancel: () => unawaited(_cancel(order)),
                  onTrack: () => unawaited(_track(order)),
                  onBuyAgain: () => unawaited(_buyAgain(order)),
                  onReview: () => unawaited(_review(order)),
                ).entrance(index: index, rise: 16),
              ),
            );
          }, childCount: data.orders.length),
        ),
      ),
      if (data.loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: OrdersPalette.orange,
                ),
              ),
            ),
          ),
        )
      else
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ];
  }

  String _emptyTitle(OrdersState data) {
    if (data.search.isNotEmpty) return 'No matching orders';
    return switch (data.filter) {
      OrderFilter.all => 'No orders yet',
      OrderFilter.processing => 'Nothing processing',
      OrderFilter.shipped => 'Nothing on the way',
      OrderFilter.delivered => 'No delivered orders',
      OrderFilter.cancelled => 'No cancelled orders',
    };
  }

  String _emptyMessage(OrdersState data) {
    if (data.search.isNotEmpty) {
      return 'Try a different order number or product name.';
    }
    return switch (data.filter) {
      OrderFilter.all => 'When you place an order, you can track it here.',
      OrderFilter.processing => 'Orders being prepared will show up here.',
      OrderFilter.shipped =>
        'Shipped orders will show their delivery progress here.',
      OrderFilter.delivered =>
        'Delivered orders will be ready to buy again or review.',
      OrderFilter.cancelled =>
        'Cancelled and refunded orders will show up here.',
    };
  }
}

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnDark,
      child: HeaderBackground(
        child: SizedBox(
          height: top + 50,
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: Row(
              children: [
                HeaderBackButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(Routes.account),
                ),
                const BrandLockup(
                  markSize: Size(30, 31.2),
                  wordmarkSize: 19.4,
                  gap: 6,
                ),
                const Spacer(),
                Pressable(
                  semanticLabel: 'Search products',
                  onTap: () => context.push(Routes.search),
                  child: const SizedBox(
                    width: 40,
                    height: 44,
                    child: Icon(
                      PhosphorIconsBold.magnifyingGlass,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
                const HeaderCartButton(),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Orders',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleLarge.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.45,
            height: 1.15,
            color: OrdersPalette.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Track, manage and return your orders.',
          maxLines: 2,
          style: AppTypography.bodyLarge.copyWith(
            fontSize: 12,
            height: 1.3,
            color: OrdersPalette.muted,
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final showClear = controller.text.isNotEmpty;
    return AnimatedContainer(
      duration: Motion.of(context, Motion.short),
      curve: Motion.standard,
      width: 156,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused ? OrdersPalette.orange : OrdersPalette.line,
        ),
        boxShadow: focused
            ? const [
                BoxShadow(
                  color: Color(0x33FF8608),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x0A14289A),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: OrdersPalette.orange,
        style: AppTypography.bodyMedium.copyWith(
          fontSize: 12,
          color: OrdersPalette.ink,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search your orders...',
          hintStyle: AppTypography.bodyMedium.copyWith(
            fontSize: 12,
            color: OrdersPalette.hint,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            PhosphorIconsBold.magnifyingGlass,
            size: 15,
            color: OrdersPalette.hint,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 36,
          ),
          suffixIcon: AnimatedSwitcher(
            duration: Motion.of(context, Motion.short),
            child: showClear
                ? Pressable(
                    key: const ValueKey('clear'),
                    semanticLabel: 'Clear search',
                    onTap: onClear,
                    child: const SizedBox(
                      width: 28,
                      height: 36,
                      child: Icon(
                        PhosphorIconsBold.x,
                        size: 12,
                        color: OrdersPalette.muted,
                      ),
                    ),
                  )
                : const SizedBox(key: ValueKey('empty'), width: 8),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 8,
            minHeight: 36,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.summary,
    required this.onSelect,
  });

  final OrderFilter selected;
  final OrderSummary? summary;
  final ValueChanged<OrderFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final filter in OrderFilter.values) ...[
            if (filter != OrderFilter.all) const SizedBox(width: 8),
            _Chip(
              label: filter.label,
              count: _count(summary, filter),
              selected: filter == selected,
              onTap: () => onSelect(filter),
            ),
          ],
        ],
      ),
    );
  }

  int _count(OrderSummary? summary, OrderFilter filter) {
    if (summary == null) return 0;
    return switch (filter) {
      OrderFilter.all => summary.total,
      OrderFilter.processing => summary.processingCount,
      OrderFilter.shipped => summary.shippedCount,
      OrderFilter.delivered => summary.delivered,
      OrderFilter.cancelled => summary.cancelled + summary.returned,
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = selected ? Colors.white : OrdersPalette.inkSoft;
    final badgeText = selected
        ? OrdersPalette.orange
        : OrdersPalette.countIdleText;
    final badgeFill = selected ? Colors.white : OrdersPalette.countIdle;
    return Pressable(
      semanticLabel: '$label, $count',
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        curve: Motion.emphasized,
        height: 32,
        padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
        decoration: BoxDecoration(
          color: selected ? OrdersPalette.orange : OrdersPalette.chipIdle,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x40FF8608),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x0F14289A),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: Motion.of(context, Motion.short),
              style: AppTypography.label.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: text,
              ),
              child: Text(label),
            ),
            const SizedBox(width: 6),
            AnimatedContainer(
              duration: Motion.of(context, Motion.short),
              curve: Motion.emphasized,
              height: 18,
              constraints: const BoxConstraints(minWidth: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeFill,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '$count',
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: badgeText,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return AppSkeletonTheme(
      child: Skeletonizer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
          child: Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                const _SkeletonCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 110, height: 14),
                    SizedBox(height: 6),
                    SkeletonBox(width: 160, height: 10),
                  ],
                ),
              ),
              SkeletonBox(width: 88, height: 24, radius: 12),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              SkeletonBox(width: 64, height: 64, radius: 12),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 120, height: 12),
                    SizedBox(height: 6),
                    SkeletonBox(width: 80, height: 10),
                    SizedBox(height: 8),
                    SkeletonBox(width: 90, height: 12),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 38, radius: 11)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(height: 38, radius: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancelSheet extends StatelessWidget {
  const _CancelSheet({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE4E8F2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: OrdersPalette.pillRed,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              PhosphorIconsRegular.xCircle,
              color: OrdersPalette.red,
              size: 26,
            ),
          ).animatePop(),
          const SizedBox(height: 12),
          Text(
            'Cancel this order?',
            style: AppTypography.titleMedium.copyWith(
              fontSize: 18,
              color: OrdersPalette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We will stop ${order.displayNumber} if it has not shipped. This cannot be undone.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              fontSize: 13,
              height: 1.4,
              color: OrdersPalette.muted,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SheetButton(
                  label: 'Keep order',
                  filled: false,
                  onTap: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SheetButton(
                  label: 'Cancel order',
                  filled: true,
                  onTap: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.productName});

  final String productName;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 0;
  var _sent = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.emphasizedDecelerate,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: _sent ? _thanks() : _form(),
      ),
    );
  }

  Widget _form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE4E8F2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Write a review',
          style: AppTypography.titleMedium.copyWith(
            fontSize: 18,
            color: OrdersPalette.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyLarge.copyWith(color: OrdersPalette.muted),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var star = 1; star <= 5; star++)
              Pressable(
                semanticLabel: '$star ${star == 1 ? 'star' : 'stars'}',
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  setState(() => _rating = star);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    star <= _rating
                        ? PhosphorIconsFill.star
                        : PhosphorIconsRegular.star,
                    size: 32,
                    color: star <= _rating
                        ? const Color(0xFFF5A524)
                        : const Color(0xFFD5DAE6),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 4,
          cursorColor: OrdersPalette.orange,
          style: AppTypography.bodyLarge.copyWith(
            fontSize: 13,
            color: OrdersPalette.ink,
          ),
          decoration: InputDecoration(
            hintText: 'What did you think of it?',
            hintStyle: AppTypography.bodyLarge.copyWith(
              fontSize: 13,
              color: OrdersPalette.hint,
            ),
            filled: true,
            fillColor: const Color(0xFFF6F8FD),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SheetButton(
          label: 'Submit review',
          filled: true,
          expand: true,
          onTap: _rating == 0
              ? null
              : () {
                  unawaited(HapticFeedback.lightImpact());
                  setState(() => _sent = true);
                },
        ),
      ],
    );
  }

  Widget _thanks() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: OrdersPalette.pillGreen,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            PhosphorIconsFill.checkCircle,
            color: OrdersPalette.green,
            size: 30,
          ),
        ).animatePop(),
        const SizedBox(height: 12),
        Text(
          'Thanks for the review',
          style: AppTypography.titleMedium.copyWith(
            fontSize: 18,
            color: OrdersPalette.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Thanks for telling us how ${widget.productName} worked for you.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge.copyWith(
            fontSize: 13,
            height: 1.4,
            color: OrdersPalette.muted,
          ),
        ),
        const SizedBox(height: 16),
        _SheetButton(
          label: 'Done',
          filled: true,
          expand: true,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.expand = false,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final child = Pressable(
      pressedScale: 0.98,
      semanticLabel: label,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: !enabled
              ? const Color(0xFFE7EAF2)
              : filled
              ? (label == 'Cancel order'
                    ? OrdersPalette.red
                    : OrdersPalette.orange)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: OrdersPalette.line),
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: filled || !enabled ? Colors.white : OrdersPalette.ink,
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

extension on Widget {
  /// A one-shot pop for sheet icons. Stays still when motion is reduced.
  Widget animatePop() => _Pop(child: this);
}

class _Pop extends StatelessWidget {
  const _Pop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return child
        .animate()
        .scaleXY(
          begin: 0.7,
          end: 1,
          duration: Motion.long,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: Motion.short);
  }
}
