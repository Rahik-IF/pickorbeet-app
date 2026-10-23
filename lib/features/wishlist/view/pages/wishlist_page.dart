import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/motion/entrance.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/cart_notifier.dart';
import 'package:pickorbeet/core/providers/wishlist_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/router/tab_reselect.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/widgets/brand_lockup.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';
import 'package:pickorbeet/core/widgets/header_background.dart';
import 'package:pickorbeet/core/widgets/skeleton.dart';
import 'package:pickorbeet/core/widgets/state_views.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/wishlist/view/widgets/wishlist_card.dart';
import 'package:pickorbeet/features/wishlist/viewmodel/wishlist_providers.dart';
import 'package:skeletonizer/skeletonizer.dart';

const _page = Color(0xFFEEF5FF);
const _ink = Color(0xFF101848);
const _muted = Color(0xFF8C93A7);
const _orange = Color(0xFFFF7A16);
const _chipInk = Color(0xFF24253C);
const _chipLine = Color(0xFFE4E9F2);
const _moveInk = Color(0xFF2450E6);

const _titleStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.45,
  height: 1.15,
  color: _ink,
);
const _subtitleStyle = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.35, color: _muted);

/// Wishlist tab: saved products, category chips, and move-to-cart.
class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});

  static const tabIndex = 2;

  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage> {
  final _scroll = ScrollController();
  final _bulk = <String>{};

  List<ProductSummary>? _cached;
  String? _category;
  bool _intro = true;
  bool _moving = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(wishlistProductsProvider);
    try {
      await ref.read(wishlistProductsProvider.future);
    } on Object {
      // A refresh that fails while cards are on screen is reported by the listener.
    }
  }

  void _flushBulk() {
    if (_bulk.isEmpty) return;
    final ids = Set<String>.of(_bulk);
    _bulk.clear();
    ref.read(wishlistNotifierProvider.notifier).removeMany(ids);
  }

  void _select(String? category, Set<String> names) {
    final current = _category != null && names.contains(_category) ? _category : null;
    if (category == current) return;
    _flushBulk();
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _intro = false;
      _category = category;
    });
  }

  void _onDismissed(ProductSummary product, WishlistRemoval reason) {
    if (!mounted) return;
    if (_bulk.remove(product.id)) {
      ref.read(wishlistNotifierProvider.notifier).remove(product.id);
      return;
    }
    final ids = ref.read(wishlistNotifierProvider);
    final index = ids.indexOf(product.id);
    if (index < 0) return;
    ref.read(wishlistNotifierProvider.notifier).remove(product.id);
    if (reason != WishlistRemoval.saved) return;
    showToast(
      context,
      'Removed from wishlist',
      actionLabel: 'Undo',
      onAction: () {
        if (!mounted) return;
        ref.read(wishlistNotifierProvider.notifier).restore(product.id, index);
      },
    );
  }

  Future<void> _moveAll(List<ProductSummary> products) async {
    if (_moving || products.isEmpty) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() => _moving = true);
    final moved = <String>[];
    var needsChoice = 0;
    var unavailable = 0;
    AppFailure? failure;
    for (final product in products) {
      if (_bulk.contains(product.id)) continue;
      if (product.isOutOfStock) {
        unavailable++;
        continue;
      }
      if (product.needsVariantChoice) {
        needsChoice++;
        continue;
      }
      final result = await ref.read(cartNotifierProvider.notifier).add(CartLine(productId: product.id, quantity: 1));
      if (!mounted) return;
      final failed = result.fold<AppFailure?>((error) => error, (_) => null);
      if (failed != null) {
        failure = failed;
        break;
      }
      moved.add(product.id);
    }
    if (!mounted) return;
    setState(() {
      _moving = false;
      _bulk.addAll(moved);
    });
    showToast(
      context,
      _moveMessage(moved: moved.length, needsChoice: needsChoice, unavailable: unavailable, failure: failure),
      kind: moved.isEmpty ? ToastKind.error : ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    listenForTabReselect(ref, context, WishlistPage.tabIndex, _scroll);
    final ids = ref.watch(wishlistNotifierProvider);
    final async = ref.watch(wishlistProductsProvider);

    ref.listen(wishlistProductsProvider, (previous, next) {
      final items = next.valueOrNull;
      if (items != null && !next.isLoading) {
        final saved = ref.read(wishlistNotifierProvider);
        if (saved.isNotEmpty && items.length != saved.length) {
          ref.read(wishlistNotifierProvider.notifier).retainOnly({for (final item in items) item.id});
        }
      }
      if (next.hasError && _cached != null && previous?.hasError != true && mounted) {
        showToast(context, "Couldn't refresh your wishlist.", kind: ToastKind.error);
      }
    });

    final latest = async.valueOrNull;
    if (latest != null) _cached = latest;
    final savedIds = ids.toSet();
    final products = [
      for (final product in latest ?? _cached ?? const <ProductSummary>[])
        if (savedIds.contains(product.id)) product,
    ];
    final names = _categoryNames(products);
    final active = _category != null && names.contains(_category) ? _category : null;
    final waiting = ids.isNotEmpty && products.isEmpty && !async.hasError;
    final failed = ids.isNotEmpty && products.isEmpty && async.hasError;

    final Widget lower;
    if (waiting) {
      lower = const _WishlistSkeleton(key: ValueKey('loading'));
    } else if (failed) {
      lower = _Failure(key: const ValueKey('error'), failure: async.error ?? const AppFailure(), onRetry: _refresh);
    } else if (products.isEmpty) {
      lower = const _Empty(key: ValueKey('empty'));
    } else {
      lower = _Results(
        key: const ValueKey('list'),
        products: products,
        active: active,
        intro: _intro,
        bulk: _bulk,
        onSelect: (category) => _select(category, names),
        onDismissed: _onDismissed,
      );
    }

    return Scaffold(
      backgroundColor: _page,
      body: Column(
        children: [
          const _WishlistHeader(),
          Expanded(
            child: RefreshIndicator(
              color: AppPallete.primary,
              backgroundColor: AppPallete.surface,
              onRefresh: _refresh,
              child: ListView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
                children: [
                  _Heading(
                    showMove: products.isNotEmpty,
                    moving: _moving,
                    onMove: () => unawaited(_moveAll(products)),
                  ).entrance(),
                  const SizedBox(height: 4),
                  const Text(
                    'Save your favorite products and shop them later.',
                    style: _subtitleStyle,
                  ).entrance(index: 1),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: Motion.of(context, Motion.medium),
                    switchInCurve: Motion.emphasizedDecelerate,
                    switchOutCurve: Motion.emphasizedAccelerate,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        ...previous,
                        if (current != null) current,
                      ],
                    ),
                    child: lower,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistHeader extends StatelessWidget {
  const _WishlistHeader();

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
                const HeaderBackButton(),
                const BrandLockup(markSize: Size(30, 31.2), wordmarkSize: 19.4, gap: 6),
                const Spacer(),
                Pressable(
                  semanticLabel: 'Search',
                  onTap: () => context.push(Routes.search),
                  child: const SizedBox(
                    width: 40,
                    height: 44,
                    child: Icon(PhosphorIconsBold.magnifyingGlass, size: 22, color: AppPallete.onDark),
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

class _Heading extends StatelessWidget {
  const _Heading({required this.showMove, required this.moving, required this.onMove});

  final bool showMove;
  final bool moving;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text('My Wishlist', maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle),
        ),
        if (showMove) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _MoveAllButton(moving: moving, onPressed: moving ? null : onMove),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MoveAllButton extends StatelessWidget {
  const _MoveAllButton({required this.moving, required this.onPressed});

  final bool moving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'Move all to cart',
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(color: _moveInk, width: 1.15),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.short),
                child: moving
                    ? const SizedBox(
                        key: ValueKey('moving'),
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _moveInk),
                      )
                    : const Icon(
                        key: ValueKey('cart'),
                        PhosphorIconsRegular.shoppingCartSimple,
                        size: 15,
                        color: _moveInk,
                      ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Move All to Cart',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.1, color: _moveInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    super.key,
    required this.products,
    required this.active,
    required this.intro,
    required this.bulk,
    required this.onSelect,
    required this.onDismissed,
  });

  final List<ProductSummary> products;
  final String? active;
  final bool intro;
  final Set<String> bulk;
  final ValueChanged<String?> onSelect;
  final void Function(ProductSummary product, WishlistRemoval reason) onDismissed;

  @override
  Widget build(BuildContext context) {
    final counts = _counts(products);
    final ordered = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.toLowerCase().compareTo(b.toLowerCase());
      });
    final shown = [
      for (final product in products)
        if (active == null || product.categoryName.trim() == active) product,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Chips(
          total: products.length,
          ordered: ordered,
          counts: counts,
          active: active,
          onSelect: onSelect,
        ).entrance(enabled: intro),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.emphasizedDecelerate,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.medium),
            switchInCurve: Motion.emphasizedDecelerate,
            switchOutCurve: Motion.emphasizedAccelerate,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [
                ...previous,
                if (current != null) current,
              ],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey(active ?? '*'),
              children: [
                for (var i = 0; i < shown.length; i++)
                  WishlistCard(
                    key: ValueKey(shown[i].id),
                    product: shown[i],
                    dismiss: bulk.contains(shown[i].id),
                    entranceIndex: i + 1,
                    animateIn: intro,
                    onDismissed: onDismissed,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.total,
    required this.ordered,
    required this.counts,
    required this.active,
    required this.onSelect,
  });

  final int total;
  final List<String> ordered;
  final Map<String, int> counts;
  final String? active;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final chips = <(String?, String, int)>[
      (null, 'All', total),
      for (final name in ordered) (name, name, counts[name] ?? 0),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        primary: false,
        padding: const EdgeInsets.symmetric(vertical: 4),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (category, label, count) = chips[index];
          final selected = category == null ? active == null : category == active;
          return _Chip(
            label: label,
            count: count,
            selected: selected,
            onTap: () => onSelect(category),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : _chipInk;
    return Pressable(
      semanticLabel: selected ? '$label, $count, selected' : '$label, $count',
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        curve: Motion.emphasizedDecelerate,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _orange : Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(color: selected ? _orange : _chipLine),
          boxShadow: selected
              ? null
              : [BoxShadow(color: const Color(0xFF14289A).withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: AnimatedDefaultTextStyle(
          duration: Motion.of(context, Motion.short),
          curve: Motion.emphasizedDecelerate,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.1, color: color),
          child: Text('$label ($count)'),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: EmptyState(
        icon: PhosphorIconsDuotone.heart,
        title: 'No saved products',
        message: 'Tap the heart on a product and it will show up here.',
        actionLabel: 'Browse products',
        onAction: () => context.push(Routes.products),
        tint: const Color(0xFFF21634),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({super.key, required this.failure, required this.onRetry});

  final Object failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: ErrorState(failure: failure, onRetry: onRetry),
    );
  }
}

class _WishlistSkeleton extends StatelessWidget {
  const _WishlistSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeletonTheme(
      child: Skeletonizer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                SkeletonBox(width: 78, height: 32, radius: 999),
                SizedBox(width: 8),
                SkeletonBox(width: 118, height: 32, radius: 999),
                SizedBox(width: 8),
                SkeletonBox(width: 96, height: 32, radius: 999),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < 3; i++) ...[
              const SkeletonBox(height: 124, radius: 16),
              if (i < 2) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

Map<String, int> _counts(List<ProductSummary> products) {
  final counts = <String, int>{};
  for (final product in products) {
    final name = product.categoryName.trim();
    if (name.isEmpty) continue;
    counts[name] = (counts[name] ?? 0) + 1;
  }
  return counts;
}

Set<String> _categoryNames(List<ProductSummary> products) => _counts(products).keys.toSet();

String _moveMessage({
  required int moved,
  required int needsChoice,
  required int unavailable,
  required AppFailure? failure,
}) {
  if (moved == 0 && failure != null && needsChoice == 0 && unavailable == 0) return failure.message;
  if (moved == 0 && needsChoice > 0 && unavailable == 0) {
    return needsChoice == 1
        ? 'Choose a colour or size before moving that product.'
        : 'Choose a colour or size before moving those products.';
  }
  if (moved == 0 && unavailable > 0 && needsChoice == 0) return 'Those saved products are out of stock.';
  if (moved == 0) return failure?.message ?? 'Nothing could be moved to the cart.';
  final label = moved == 1 ? 'Moved 1 product to your cart' : 'Moved $moved products to your cart';
  if (needsChoice == 0 && unavailable == 0 && failure == null) return label;
  if (needsChoice > 0) return '$label. Some still need a colour or size.';
  if (unavailable > 0) return '$label. Some are out of stock.';
  return '$label. ${failure?.message ?? ''}'.trim();
}
