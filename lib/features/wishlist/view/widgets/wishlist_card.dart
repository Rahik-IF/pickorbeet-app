import 'dart:async';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/motion/entrance.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/cart_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/models/official_badge.dart';
import 'package:pickorbeet/features/catalog/view/widgets/product_card.dart';

const _ink = Color(0xFF141B3F);
const _metaInk = Color(0xFF8B91A3);
const _price = Color(0xFF1B3FDB);
const _strike = Color(0xFF9AA1B4);
const _save = Color(0xFF0F9A4A);
const _heart = Color(0xFFF21634);
const _orange = Color(0xFFFF6C00);
const _viewFill = Color(0xFFE6F0FF);
const _viewInk = Color(0xFF2A46C4);
const _soldFill = Color(0xFFE7ECF4);
const _soldInk = Color(0xFF8B93A8);
const _added = Color(0xFF12924A);
const _photo = Color(0xFFF4F7FC);
const _dots = Color(0xFF5C6578);

const _nameStyle = TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w700,
  height: 1.15,
  letterSpacing: -0.2,
  color: _ink,
);
const _metaStyle = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.25, color: _metaInk);
const _priceStyle = TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w800,
  height: 1.1,
  letterSpacing: -0.2,
  color: _price,
);
const _strikeStyle = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w500,
  height: 1.1,
  color: _strike,
  decoration: TextDecoration.lineThrough,
  decorationColor: _strike,
);
const _saveStyle = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2, color: _save);
const _buttonStyle = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.05, letterSpacing: -0.1);
const _ratingStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.1, color: Color(0xFF2A3148));

final _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: const BorderRadius.all(Radius.circular(16)),
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF14289A).withValues(alpha: 0.055),
      blurRadius: 16,
      offset: const Offset(0, 5),
    ),
  ],
);

/// Why a card is leaving the list. [saved] offers undo; [moved] already went to the cart.
enum WishlistRemoval { saved, moved }

/// One saved product, laid out like the wishlist design: photo, price, and the two actions.
class WishlistCard extends ConsumerStatefulWidget {
  const WishlistCard({
    super.key,
    required this.product,
    required this.onDismissed,
    this.dismiss = false,
    this.entranceIndex = 0,
    this.animateIn = true,
  });

  final ProductSummary product;
  final void Function(ProductSummary product, WishlistRemoval reason) onDismissed;

  /// Plays the leave animation. Used when several cards move to the cart together.
  final bool dismiss;
  final int entranceIndex;
  final bool animateIn;

  @override
  ConsumerState<WishlistCard> createState() => _WishlistCardState();
}

class _WishlistCardState extends ConsumerState<WishlistCard> with TickerProviderStateMixin {
  late final AnimationController _leave;
  late final AnimationController _heartPulse;
  late final Animation<double> _heartScale;
  late final Animation<double> _fade;
  late final Animation<double> _shrink;
  late final Animation<Offset> _slide;
  late final CurvedAnimation _heartCurve;
  late final CurvedAnimation _fadeCurve;
  late final CurvedAnimation _shrinkCurve;
  late final CurvedAnimation _slideCurve;

  bool _played = false;
  bool _adding = false;
  bool _added = false;

  @override
  void initState() {
    super.initState();
    _leave = AnimationController(vsync: this, duration: const Duration(milliseconds: 340));
    _heartPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _heartCurve = CurvedAnimation(parent: _heartPulse, curve: Curves.easeOut);
    _fadeCurve = CurvedAnimation(parent: _leave, curve: const Interval(0, 0.6, curve: Curves.easeOut));
    _shrinkCurve = CurvedAnimation(parent: _leave, curve: const Interval(0.25, 1, curve: Curves.easeInCubic));
    _slideCurve = CurvedAnimation(parent: _leave, curve: Curves.easeIn);
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.34), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.34, end: 0.82), weight: 55),
    ]).animate(_heartCurve);
    _fade = Tween(begin: 1.0, end: 0.0).animate(_fadeCurve);
    _shrink = Tween(begin: 1.0, end: 0.0).animate(_shrinkCurve);
    _slide = Tween<Offset>(begin: Offset.zero, end: const Offset(0.05, 0)).animate(_slideCurve);
    if (widget.dismiss) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_playDismiss(WishlistRemoval.moved, haptic: false));
      });
    }
  }

  @override
  void didUpdateWidget(WishlistCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dismiss && !oldWidget.dismiss) {
      unawaited(_playDismiss(WishlistRemoval.moved, haptic: false));
    }
  }

  @override
  void dispose() {
    _heartCurve.dispose();
    _fadeCurve.dispose();
    _shrinkCurve.dispose();
    _slideCurve.dispose();
    _leave.dispose();
    _heartPulse.dispose();
    super.dispose();
  }

  Future<void> _playDismiss(WishlistRemoval reason, {bool haptic = true}) async {
    if (_played) return;
    _played = true;
    if (haptic) unawaited(HapticFeedback.selectionClick());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    if (Motion.reduced(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDismissed(widget.product, reason);
      });
      return;
    }
    unawaited(_heartPulse.forward(from: 0));
    await Future<void>.delayed(const Duration(milliseconds: 110));
    if (!mounted) return;
    await _leave.forward();
    if (!mounted) return;
    widget.onDismissed(widget.product, reason);
  }

  Future<void> _add() async {
    if (_played || _adding || widget.product.isOutOfStock) return;
    setState(() => _adding = true);
    final added = await quickAddToCart(context, ref, widget.product);
    if (!mounted) return;
    setState(() {
      _adding = false;
      _added = added;
    });
    if (!added) return;
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (mounted) setState(() => _added = false);
  }

  Future<void> _moveToCart() async {
    if (_played || _adding) return;
    final product = widget.product;
    if (product.isOutOfStock) {
      showToast(context, 'This product is out of stock.', kind: ToastKind.error);
      return;
    }
    if (product.needsVariantChoice) {
      await quickAddToCart(context, ref, product);
      return;
    }
    setState(() => _adding = true);
    final result = await ref.read(cartNotifierProvider.notifier).add(CartLine(productId: product.id, quantity: 1));
    if (!mounted) return;
    setState(() => _adding = false);
    result.fold(
      (failure) => showToast(context, failure.message, kind: ToastKind.error),
      (_) {
        showToast(context, 'Moved to cart', kind: ToastKind.success);
        unawaited(_playDismiss(WishlistRemoval.moved));
      },
    );
  }

  void _details() {
    if (_played) return;
    unawaited(context.push(Routes.product(widget.product.slug)));
  }

  Future<void> _openMenu() async {
    if (_played) return;
    final box = context.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || overlay is! RenderBox || !overlay.hasSize) return;
    final origin = box.localToGlobal(Offset(box.size.width - 36, 12), ancestor: overlay);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(Rect.fromLTWH(origin.dx, origin.dy, 28, 28), Offset.zero & overlay.size),
      color: Colors.white,
      elevation: 10,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      items: const [
        PopupMenuItem(value: 'cart', child: _MenuLine(icon: PhosphorIconsRegular.shoppingCartSimple, label: 'Move to cart')),
        PopupMenuItem(
          value: 'remove',
          child: _MenuLine(icon: PhosphorIconsRegular.trash, label: 'Remove', color: _heart),
        ),
      ],
    );
    if (!mounted || selected == null) return;
    switch (selected) {
      case 'cart':
        await _moveToCart();
      case 'remove':
        await _playDismiss(WishlistRemoval.saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final percent = _percent(product);
    final meta = _meta(product);
    final rating = _ratingLabel(product);
    final save = _saveLabel(product);

    final card = DecoratedBox(
      decoration: _cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: _WishlistCardBody(
          image: _Photo(
            product: product,
            percent: percent,
            animate: widget.animateIn,
            onOpen: _details,
            badge: officialBadgeStyleOf(ref),
          ),
          details: Pressable(
            pressedScale: 0.985,
            onTap: _played ? null : _details,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: _nameStyle),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: _metaStyle),
                ],
                if (rating != null) ...[
                  const SizedBox(height: 3),
                  _Rating(label: rating),
                ],
                const SizedBox(height: 4),
                _Price(product: product),
                if (save != null) ...[
                  const SizedBox(height: 2),
                  Text(save, maxLines: 1, overflow: TextOverflow.ellipsis, style: _saveStyle),
                ],
              ],
            ),
          ),
          toolbar: Row(
            children: [
              ScaleTransition(
                scale: _heartScale,
                child: Pressable(
                  semanticLabel: 'Remove ${product.name} from wishlist',
                  onTap: _played ? null : () => unawaited(_playDismiss(WishlistRemoval.saved)),
                  child: const SizedBox(
                    width: 32,
                    height: 28,
                    child: Icon(PhosphorIconsFill.heart, size: 18, color: _heart),
                  ),
                ),
              ),
              const Spacer(),
              Pressable(
                semanticLabel: 'More actions for ${product.name}',
                onTap: _played ? null : () => unawaited(_openMenu()),
                child: const SizedBox(
                  width: 32,
                  height: 28,
                  child: Icon(PhosphorIconsBold.dotsThreeVertical, size: 18, color: _dots),
                ),
              ),
            ],
          ),
          actions: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AddButton(
                product: product,
                adding: _adding,
                added: _added,
                onTap: _played ? null : () => unawaited(_add()),
              ),
              const SizedBox(height: 4),
              _ActionButton(
                label: 'View details for ${product.name}',
                background: _viewFill,
                onTap: _played ? null : _details,
                child: Text('View Details', style: _buttonStyle.copyWith(color: _viewInk)),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizeTransition(
        axisAlignment: -1,
        sizeFactor: _shrink,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: IgnorePointer(ignoring: _played, child: card),
          ),
        ),
      ),
    ).entrance(index: widget.entranceIndex, enabled: widget.animateIn && !_played);
  }
}

class _Photo extends StatelessWidget {
  const _Photo({
    required this.product,
    required this.percent,
    required this.animate,
    required this.onOpen,
    required this.badge,
  });

  final ProductSummary product;
  final int percent;
  final bool animate;
  final VoidCallback onOpen;
  final OfficialBadgeStyle badge;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Pressable(
            semanticLabel: percent > 0 ? '${product.name}, $percent% off. View details' : 'View ${product.name}',
            onTap: onOpen,
            child: Opacity(
              opacity: product.isOutOfStock ? 0.5 : 1,
              child: AppNetworkImage(
                url: product.primaryImage,
                background: _photo,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          if (product.isOfficial)
            OfficialMark(style: badge, inset: 6, scale: badge.scaleFor(0.7), maxWidth: 120),
          if (percent > 0)
            Positioned(
              left: 6,
              top: product.isOfficial && badge.position == 'top-left' ? badge.dropFor(30) : 6,
              child: _Badge(percent: percent, animate: animate),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.percent, required this.animate});

  final int percent;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final badge = DecoratedBox(
      decoration: const BoxDecoration(
        color: _orange,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          '-$percent%',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, height: 1, color: Colors.white, letterSpacing: -0.1),
        ),
      ),
    );
    if (!animate || Motion.reduced(context)) return badge;
    return badge
        .animate()
        .fadeIn(duration: Motion.short)
        .scaleXY(begin: 0.6, end: 1, duration: Motion.long, curve: Curves.easeOutBack);
  }
}

class _Rating extends StatelessWidget {
  const _Rating({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(PhosphorIconsFill.star, size: 13, color: Color(0xFFF2AC1E)),
        const SizedBox(width: 4),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ratingStyle)),
      ],
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.product});

  final ProductSummary product;

  @override
  Widget build(BuildContext context) {
    final compare = product.hasDiscount ? product.comparePrice : null;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(_taka(product.price), maxLines: 1, style: _priceStyle),
          if (compare != null) ...[
            const SizedBox(width: 6),
            Text(_taka(compare), maxLines: 1, style: _strikeStyle),
          ],
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.product, required this.adding, required this.added, required this.onTap});

  final ProductSummary product;
  final bool adding;
  final bool added;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final soldOut = product.isOutOfStock;
    final Color background;
    final Color foreground;
    final Widget content;
    if (soldOut) {
      background = _soldFill;
      foreground = _soldInk;
      content = Text('Out of stock', key: const ValueKey('stock'), style: _buttonStyle.copyWith(color: foreground));
    } else if (adding) {
      background = _orange;
      foreground = Colors.white;
      content = const SizedBox(
        key: ValueKey('adding'),
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else if (added) {
      background = _added;
      foreground = Colors.white;
      content = Row(
        key: const ValueKey('added'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsFill.check, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text('Added', style: _buttonStyle.copyWith(color: foreground)),
        ],
      );
    } else {
      background = _orange;
      foreground = Colors.white;
      content = Row(
        key: const ValueKey('add'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsRegular.shoppingCartSimple, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text('Add to Cart', style: _buttonStyle.copyWith(color: foreground)),
        ],
      );
    }

    return _ActionButton(
      label: soldOut ? '${product.name} is out of stock' : 'Add ${product.name} to cart',
      background: background,
      shadow: !soldOut && !added,
      onTap: soldOut ? null : onTap,
      child: AnimatedSwitcher(
        duration: Motion.of(context, Motion.short),
        switchInCurve: Motion.emphasizedDecelerate,
        switchOutCurve: Motion.emphasizedAccelerate,
        child: content,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.background,
    required this.onTap,
    required this.child,
    this.shadow = false,
  });

  final String label;
  final Color background;
  final VoidCallback? onTap;
  final Widget child;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final button = Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        curve: Motion.emphasizedDecelerate,
        height: 26,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          boxShadow: shadow
              ? [BoxShadow(color: _orange.withValues(alpha: 0.22), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: child),
      ),
    );
    return Semantics(button: true, enabled: onTap != null, label: label, excludeSemantics: true, child: button);
  }
}

class _MenuLine extends StatelessWidget {
  const _MenuLine({required this.icon, required this.label, this.color = _ink});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

/// Photo, copy, and actions in one row. The photo matches the taller of the copy and the
/// actions, and the buttons sit on the bottom of that height. A [LayoutBuilder] inside the
/// photo cannot answer intrinsic-height queries, so this does the measurement itself.
class _WishlistCardBody extends MultiChildRenderObjectWidget {
  _WishlistCardBody({
    required Widget image,
    required Widget details,
    required Widget toolbar,
    required Widget actions,
  }) : super(children: [image, details, toolbar, actions]);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderWishlistCardBody();
}

class _WishlistCardParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderWishlistCardBody extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _WishlistCardParentData>,
         RenderBoxContainerDefaultsMixin<RenderBox, _WishlistCardParentData> {
  static const _imageGap = 10.0;
  static const _actionGap = 8.0;
  static const _toolbarGap = 8.0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _WishlistCardParentData) child.parentData = _WishlistCardParentData();
  }

  RenderBox _at(int index) {
    var child = firstChild;
    for (var i = 0; i < index; i++) {
      child = childAfter(child!);
    }
    return child!;
  }

  (double, double, double) _columns(double maxWidth) {
    const gaps = _imageGap + _actionGap;
    var image = (maxWidth * 0.27).clamp(0.0, 104.0);
    var action = (maxWidth * 0.28).clamp(0.0, 108.0);
    if (maxWidth >= 300) {
      image = image.clamp(84.0, 104.0);
      action = action.clamp(96.0, 108.0);
    }
    var details = maxWidth - image - action - gaps;
    // The name and the review line need the middle. The photo and the buttons give up width first.
    final minDetails = math.min(156.0, maxWidth * 0.42);
    if (details < minDetails) {
      var need = minDetails - details;
      final fromAction = math.min(need, math.max(0.0, action - 92));
      action -= fromAction;
      need -= fromAction;
      final fromImage = math.min(need, math.max(0.0, image - 72));
      image -= fromImage;
      details = maxWidth - image - action - gaps;
    }
    if (image + action + gaps > maxWidth) {
      final room = math.max(0.0, maxWidth - gaps);
      final spare = math.max(image + action, 1);
      image = room * (image / spare);
      action = math.max(0.0, room - image);
      details = math.max(0.0, maxWidth - image - action - gaps);
    }
    return (image, action, math.max(0.0, details));
  }

  @override
  void performLayout() {
    final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
    final (imageWidth, actionWidth, detailsWidth) = _columns(maxWidth);
    final image = _at(0);
    final details = _at(1);
    final toolbar = _at(2);
    final actions = _at(3);

    details.layout(BoxConstraints(maxWidth: detailsWidth), parentUsesSize: true);
    toolbar.layout(BoxConstraints.tightFor(width: actionWidth), parentUsesSize: true);
    actions.layout(BoxConstraints.tightFor(width: actionWidth), parentUsesSize: true);

    final height = math.max(details.size.height, toolbar.size.height + _toolbarGap + actions.size.height);
    image.layout(BoxConstraints.tightFor(width: imageWidth, height: height), parentUsesSize: true);

    final actionX = maxWidth - actionWidth;
    _place(image, Offset.zero);
    _place(details, Offset(imageWidth + _imageGap, 0));
    _place(toolbar, Offset(actionX, 0));
    _place(actions, Offset(actionX, height - actions.size.height));
    size = constraints.constrain(Size(maxWidth, height));
  }

  void _place(RenderBox child, Offset offset) {
    (child.parentData! as _WishlistCardParentData).offset = offset;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  double _intrinsicHeight(double width) {
    if (!width.isFinite) return 0;
    final (_, actionWidth, detailsWidth) = _columns(width);
    final details = _at(1).getMaxIntrinsicHeight(detailsWidth);
    final toolbar = _at(2).getMaxIntrinsicHeight(actionWidth);
    final actions = _at(3).getMaxIntrinsicHeight(actionWidth);
    return math.max(details, toolbar + _toolbarGap + actions);
  }

  @override
  double computeMinIntrinsicWidth(double height) => 88 + 100 + _imageGap + _actionGap;

  @override
  double computeMaxIntrinsicWidth(double height) => computeMinIntrinsicWidth(height);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}

String _taka(Object? value) => '${Formatters.taka}${Formatters.amount(value)}';

int _percent(ProductSummary product) {
  if (product.discountPercentage > 0) return product.discountPercentage;
  final compare = product.comparePrice;
  if (compare == null || !product.hasDiscount) return 0;
  final was = Formatters.decimal(compare).toDouble();
  final now = Formatters.decimal(product.price).toDouble();
  if (was <= 0 || now >= was) return 0;
  return ((was - now) / was * 100).round();
}

String? _saveLabel(ProductSummary product) {
  final compare = product.comparePrice;
  if (compare == null || !product.hasDiscount) return null;
  final saved = Formatters.decimal(compare) - Formatters.decimal(product.price);
  if (saved <= Decimal.zero) return null;
  return 'Save ${Formatters.taka}${Formatters.amount(saved)}';
}

String _meta(ProductSummary product) {
  final color = _variantColor(product);
  if (color != null) {
    final brand = product.name.trim().split(RegExp(r'\s+')).first;
    if (brand.isNotEmpty) return '$brand | $color';
  }
  if (product.sku.isNotEmpty) return product.sku;
  return product.categoryName;
}

String? _variantColor(ProductSummary product) {
  String? fallback;
  for (final variant in product.variants) {
    final color = variant.color?.trim();
    if (color == null || color.isEmpty) continue;
    if (variant.isActive) return color;
    fallback ??= color;
  }
  return fallback;
}

String? _ratingLabel(ProductSummary product) {
  final rating = product.rating;
  if (rating == null) return null;
  final score = rating.toStringAsFixed(1);
  final count = product.reviewCount;
  if (count == null) return score;
  final compact = count >= 1000 ? Formatters.compact(count) : '$count';
  final noun = count == 1 ? 'review' : 'reviews';
  return '$score ($compact $noun)';
}
