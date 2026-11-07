import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/features/account/view/orders_palette.dart';

/// How a notification kind looks in the banner: a label, an icon and its colour.
@immutable
class NotificationLook {
  const NotificationLook(this.label, this.icon, this.tint);

  final String label;
  final IconData icon;
  final Color tint;

  factory NotificationLook.of(String kind, {String parcelStatus = ''}) {
    if (kind.startsWith('support.')) {
      return const NotificationLook('Help chat', PhosphorIconsFill.chatCircleDots, AppPallete.accent);
    }
    if (kind.startsWith('product.') || kind.startsWith('promo.')) {
      return switch (kind) {
        'product.arrival' => const NotificationLook('New arrival', PhosphorIconsFill.star, AppPallete.primary),
        'product.price_drop' || 'promo.sale' =>
          const NotificationLook('Offer', PhosphorIconsFill.tag, AppPallete.accent),
        'product.low_stock' => const NotificationLook('Hurry', PhosphorIconsFill.heart, AppPallete.accent),
        'product.back_in_stock' =>
          const NotificationLook('Back in stock', PhosphorIconsFill.package, OrdersPalette.green),
        _ => const NotificationLook('PickOrbeet', PhosphorIconsFill.star, AppPallete.primary),
      };
    }
    if (kind == 'parcel.update') {
      return switch (parcelStatus) {
        'hold' || 'partial_delivered' =>
          const NotificationLook('Delivery', PhosphorIconsFill.truck, OrdersPalette.orange),
        'cancelled' => const NotificationLook('Delivery', PhosphorIconsFill.warningCircle, OrdersPalette.red),
        'delivered' => const NotificationLook('Delivery', PhosphorIconsFill.checkCircle, OrdersPalette.green),
        _ => const NotificationLook('Delivery', PhosphorIconsFill.truck, AppPallete.primary),
      };
    }
    return switch (kind) {
      'order.shipped' || 'order.out_for_delivery' =>
        const NotificationLook('Delivery', PhosphorIconsFill.truck, AppPallete.primary),
      'order.delivered' => const NotificationLook('Delivery', PhosphorIconsFill.checkCircle, OrdersPalette.green),
      'order.cancelled' || 'payment.failed' =>
        const NotificationLook('Order', PhosphorIconsFill.warningCircle, OrdersPalette.red),
      'payment.paid' => const NotificationLook('Payment', PhosphorIconsFill.creditCard, OrdersPalette.green),
      'order.refunded' || 'refund.requested' || 'refund.completed' =>
        const NotificationLook('Refund', PhosphorIconsFill.arrowUUpLeft, AppPallete.primary),
      _ when kind.startsWith('order.') =>
        const NotificationLook('Order', PhosphorIconsFill.package, AppPallete.primary),
      _ => const NotificationLook('PickOrbeet', PhosphorIconsFill.bellSimpleRinging, AppPallete.primary),
    };
  }
}

/// A live notification while the app is open. It slides in under the status bar,
/// goes away by itself, on a swipe up, or on a tap that opens what it is about.
/// A newer banner replaces the one showing.
class InAppBanner {
  InAppBanner._();

  static OverlayEntry? _entry;

  static void show(
    OverlayState overlay, {
    required NotificationLook look,
    required String title,
    required String body,
    required VoidCallback onTap,
    String? imageUrl,
  }) {
    hide();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Banner(
        key: UniqueKey(),
        look: look,
        title: title,
        body: body,
        imageUrl: imageUrl,
        onTap: onTap,
        onGone: () {
          if (identical(_entry, entry)) _entry = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    unawaited(HapticFeedback.lightImpact());
  }

  static void hide() {
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _Banner extends StatefulWidget {
  const _Banner({
    super.key,
    required this.look,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.onTap,
    required this.onGone,
  });

  final NotificationLook look;
  final String title;
  final String body;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback onGone;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  static const _shownFor = Duration(milliseconds: 4800);

  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  Timer? _timer;
  double _drag = 0;
  var _leaving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_motion.forward());
    _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(_shownFor, _leave);
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    _timer?.cancel();
    await _motion.reverse();
    widget.onGone();
  }

  void _open() {
    widget.onTap();
    unawaited(_leave());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final tint = dark ? Color.lerp(widget.look.tint, Colors.white, 0.4)! : widget.look.tint;

    final card = Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.08) : AppPallete.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF051340).withValues(alpha: dark ? 0.5 : 0.14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF051340).withValues(alpha: dark ? 0.3 : 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: widget.imageUrl == null || widget.imageUrl!.isEmpty
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: dark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(widget.look.icon, size: 21, color: tint),
                  )
                : AppNetworkImage(
                    url: widget.imageUrl,
                    borderRadius: BorderRadius.circular(13),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.look.label.toUpperCase(),
                        style: AppTypography.labelSmall.copyWith(
                          color: tint,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Text(
                      'now',
                      style: AppTypography.labelSmall.copyWith(color: scheme.onSurfaceVariant, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(color: scheme.onSurface, fontSize: 14),
                ),
                if (widget.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLarge.copyWith(color: scheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, -1.3), end: Offset.zero).animate(_curve),
            child: FadeTransition(
              opacity: _curve,
              child: Transform.translate(
                offset: Offset(0, _drag),
                child: Semantics(
                  liveRegion: true,
                  button: true,
                  label: '${widget.look.label}. ${widget.title}. ${widget.body}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _open,
                    onVerticalDragStart: (_) => _timer?.cancel(),
                    onVerticalDragUpdate: (details) =>
                        setState(() => _drag = (_drag + details.delta.dy).clamp(-120.0, 12.0)),
                    onVerticalDragEnd: (details) {
                      if (_drag < -24 || (details.primaryVelocity ?? 0) < -300) {
                        unawaited(_leave());
                        return;
                      }
                      setState(() => _drag = 0);
                      _arm();
                    },
                    child: Material(type: MaterialType.transparency, child: card),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
