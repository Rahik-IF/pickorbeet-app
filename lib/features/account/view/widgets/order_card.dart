import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/features/account/model/customer_order.dart';
import 'package:pickorbeet/features/account/view/orders_palette.dart';

/// One order, in the treatment for its stage: progress, delivery, or a closing note.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onDetails,
    required this.onCancel,
    required this.onTrack,
    required this.onBuyAgain,
    required this.onReview,
    this.cancelling = false,
    this.buying = false,
  });

  final CustomerOrder order;
  final VoidCallback onDetails;
  final VoidCallback onCancel;
  final VoidCallback onTrack;
  final VoidCallback onBuyAgain;
  final VoidCallback onReview;
  final bool cancelling;
  final bool buying;

  _Tone get _tone => switch (order.stage) {
    OrderStage.processing => const _Tone(
      OrdersPalette.cream,
      OrdersPalette.orangeDeep,
      OrdersPalette.pillOrange,
    ),
    OrderStage.shipped => const _Tone(
      Colors.white,
      OrdersPalette.blue,
      OrdersPalette.pillBlue,
    ),
    OrderStage.delivered => const _Tone(
      OrdersPalette.mint,
      OrdersPalette.green,
      OrdersPalette.pillGreen,
    ),
    OrderStage.cancelled => const _Tone(
      OrdersPalette.blush,
      OrdersPalette.red,
      OrdersPalette.pillRed,
    ),
  };

  IconData get _badgeIcon => switch (order.status) {
    'shipped' || 'out_for_delivery' => PhosphorIconsRegular.truck,
    'delivered' => PhosphorIconsFill.checkCircle,
    'cancelled' || 'refunded' => PhosphorIconsFill.xCircle,
    _ => PhosphorIconsRegular.clock,
  };

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    return AnimatedContainer(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.emphasizedDecelerate,
      decoration: BoxDecoration(
        color: tone.canvas,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1210186A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Pressable(
              pressedScale: 0.985,
              semanticLabel:
                  '${order.displayNumber}, ${order.badgeLabel}. View details',
              onTap: onDetails,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.displayNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: OrdersPalette.ink,
                          ),
                        ),
                        if (order.placedLabel.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            order.placedLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11,
                              color: OrdersPalette.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _StatusPill(
                      label: order.badgeLabel,
                      icon: _badgeIcon,
                      tone: tone,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Body(order: order, tone: tone),
            if (order.stage != OrderStage.cancelled) ...[
              const SizedBox(height: 12),
              _Actions(
                order: order,
                cancelling: cancelling,
                buying: buying,
                onDetails: onDetails,
                onCancel: onCancel,
                onTrack: onTrack,
                onBuyAgain: onBuyAgain,
                onReview: onReview,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tone {
  const _Tone(this.canvas, this.accent, this.pill);

  final Color canvas;
  final Color accent;
  final Color pill;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
      decoration: BoxDecoration(
        color: tone.pill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tone.accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: tone.accent,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 1),
          Icon(PhosphorIconsBold.caretRight, size: 11, color: tone.accent),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.order, required this.tone});

  final CustomerOrder order;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Thumb(image: order.preview?.image),
        const SizedBox(width: 10),
        Expanded(flex: 52, child: _ProductCopy(order: order)),
        const SizedBox(width: 8),
        Expanded(
          flex: 48,
          child: order.showStepper
              ? _ProgressPanel(order: order, tone: tone)
              : _OutcomePanel(order: order, tone: tone),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image});

  final String? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AppNetworkImage(
        url: image,
        fit: BoxFit.contain,
        borderRadius: BorderRadius.circular(8),
        background: Colors.white,
      ),
    );
  }
}

class _ProductCopy extends StatelessWidget {
  const _ProductCopy({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final preview = order.preview;
    final price = AppTypography.priceSmall.copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w800,
      color: OrdersPalette.price,
      height: 1.1,
    );
    final strike = AppTypography.strike.copyWith(fontSize: 11, height: 1.1);
    final qty = AppTypography.bodySmall.copyWith(
      fontSize: 11,
      color: OrdersPalette.muted,
      height: 1.1,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          preview?.name.isNotEmpty == true ? preview!.name : 'Order total',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleSmall.copyWith(
            fontSize: 13,
            height: 1.25,
            color: OrdersPalette.inkSoft,
          ),
        ),
        if (preview != null && preview.detailLine.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            preview.detailLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11,
              color: OrdersPalette.muted,
            ),
          ),
        ],
        const SizedBox(height: 4),
        if (preview == null)
          Text(Formatters.money(order.total), style: price)
        else
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: Formatters.money(preview.unitPrice),
                  style: price,
                ),
                if (preview.hasCompare)
                  TextSpan(
                    text: '  ${Formatters.money(preview.comparePrice)}',
                    style: strike,
                  ),
                TextSpan(text: '   Qty: ${preview.quantity}', style: qty),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (order.extraItemCount > 0) ...[
          const SizedBox(height: 2),
          Text(
            '+${order.extraItemCount} more',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11,
              color: OrdersPalette.muted,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.order, required this.tone});

  final CustomerOrder order;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.scheduleLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.label.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: tone.accent,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          order.scheduleText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleSmall.copyWith(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: tone.accent,
          ),
        ),
        const SizedBox(height: 8),
        OrderStepper(index: order.stepperIndex, color: tone.accent),
      ],
    );
  }
}

class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({required this.order, required this.tone});

  final CustomerOrder order;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.scheduleLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tone.accent,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                order.scheduleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleSmall.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: tone.accent,
                ),
              ),
              if (order.statusNote != null) ...[
                const SizedBox(height: 3),
                Text(
                  order.statusNote!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 10.5,
                    height: 1.25,
                    color: OrdersPalette.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 4),
        order.stage == OrderStage.delivered
            ? const DeliveredParcel()
            : const CancelledNote(),
      ],
    );
  }
}

/// Processing, Shipped, Out for Delivery, Delivered. The filled portion grows in.
class OrderStepper extends StatelessWidget {
  const OrderStepper({super.key, required this.index, required this.color});

  final int index;
  final Color color;

  static const labels = [
    'Processing',
    'Shipped',
    'Out for\nDelivery',
    'Delivered',
  ];

  double get _progress => switch (index) {
    0 => 0.16,
    1 => 1 / 3,
    2 => 2 / 3,
    _ => 1.0,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 16,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _progress),
            duration: Motion.of(context, const Duration(milliseconds: 560)),
            curve: Motion.emphasizedDecelerate,
            builder: (context, value, _) =>
                _Track(progress: value, index: index, color: color),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 62,
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        fontSize: 8.2,
                        height: 1.15,
                        fontWeight: i == index
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: i == index ? color : OrdersPalette.muted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({
    required this.progress,
    required this.index,
    required this.color,
  });

  final double progress;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / OrderStepper.labels.length;
        final start = slot / 2;
        final span = constraints.maxWidth - slot;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: start,
              right: start,
              top: 6.8,
              child: Container(
                height: 2.4,
                decoration: BoxDecoration(
                  color: OrdersPalette.track,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Positioned(
              left: start,
              top: 6.8,
              child: Container(
                width: math.max(0, span * progress),
                height: 2.4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            for (var i = 0; i < OrderStepper.labels.length; i++)
              Positioned(
                left: slot * i + slot / 2 - 6,
                top: 2,
                child: _Dot(active: i == index, done: i < index, color: color),
              ),
          ],
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active, required this.done, required this.color});

  final bool active;
  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final filled = active || done;
    final dot = Container(
      width: 12,
      height: 12,
      alignment: Alignment.center,
      child: Container(
        width: active ? 11 : 8,
        height: active ? 11 : 8,
        decoration: BoxDecoration(
          color: filled ? color : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: filled ? color : const Color(0xFFD5DAE6),
            width: filled ? 0 : 1.4,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    spreadRadius: 3,
                  ),
                ]
              : null,
        ),
      ),
    );
    if (!active || Motion.reduced(context)) return dot;
    return dot.animate().scaleXY(
      begin: 0.55,
      end: 1,
      duration: Motion.medium,
      curve: Curves.easeOutBack,
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.order,
    required this.cancelling,
    required this.buying,
    required this.onDetails,
    required this.onCancel,
    required this.onTrack,
    required this.onBuyAgain,
    required this.onReview,
  });

  final CustomerOrder order;
  final bool cancelling;
  final bool buying;
  final VoidCallback onDetails;
  final VoidCallback onCancel;
  final VoidCallback onTrack;
  final VoidCallback onBuyAgain;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final buttons = switch (order.stage) {
      OrderStage.processing => [
        if (order.canCancel)
          _ActionButton(
            label: 'Cancel Order',
            icon: PhosphorIconsRegular.xCircle,
            color: OrdersPalette.inkSoft,
            border: OrdersPalette.line,
            loading: cancelling,
            onTap: cancelling ? null : onCancel,
          ),
        _ActionButton(
          label: 'View Details',
          icon: PhosphorIconsBold.caretRight,
          trailing: true,
          color: OrdersPalette.orangeDeep,
          border: const Color(0xFFFFC48A),
          onTap: onDetails,
        ),
      ],
      OrderStage.shipped => [
        _ActionButton(
          label: 'Track Order',
          icon: PhosphorIconsFill.mapPin,
          color: OrdersPalette.blue,
          border: const Color(0xFFB9D4FF),
          onTap: onTrack,
        ),
        _ActionButton(
          label: 'View Details',
          icon: PhosphorIconsBold.caretRight,
          trailing: true,
          color: OrdersPalette.blue,
          border: const Color(0xFFB9D4FF),
          onTap: onDetails,
        ),
      ],
      OrderStage.delivered => [
        _ActionButton(
          label: 'Buy Again',
          icon: PhosphorIconsRegular.shoppingCartSimple,
          color: OrdersPalette.inkSoft,
          border: OrdersPalette.line,
          loading: buying,
          compact: true,
          onTap: buying ? null : onBuyAgain,
        ),
        _ActionButton(
          label: 'Write a Review',
          icon: PhosphorIconsRegular.star,
          color: OrdersPalette.inkSoft,
          border: OrdersPalette.line,
          compact: true,
          onTap: onReview,
        ),
        _ActionButton(
          label: 'View Details',
          icon: PhosphorIconsBold.caretRight,
          trailing: true,
          color: OrdersPalette.orangeDeep,
          border: const Color(0xFFFFC48A),
          compact: true,
          onTap: onDetails,
        ),
      ],
      OrderStage.cancelled => const <Widget>[],
    };
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.border,
    required this.onTap,
    this.trailing = false,
    this.loading = false,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color border;
  final VoidCallback? onTap;
  final bool trailing;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 13.0 : 15.0;
    final glyph = loading
        ? SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
          )
        : Icon(icon, size: size, color: color);
    return Pressable(
      pressedScale: 0.97,
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        height: 38,
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!trailing) ...[glyph, SizedBox(width: compact ? 4 : 5)],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  fontSize: compact ? 11 : 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (trailing) ...[const SizedBox(width: 3), glyph],
          ],
        ),
      ),
    );
  }
}

/// The delivered card's parcel, with a slow float.
class DeliveredParcel extends StatelessWidget {
  const DeliveredParcel({super.key});

  @override
  Widget build(BuildContext context) {
    const art = SizedBox(
      width: 54,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -2,
            top: 8,
            child: _Confetti(color: Color(0xFFFFB020), angle: -0.5),
          ),
          Positioned(
            right: 0,
            top: -2,
            child: _Spark(color: Color(0xFF3B82F6)),
          ),
          Positioned(
            left: 6,
            top: 0,
            child: _Spark(color: Color(0xFF22C55E), size: 4),
          ),
          Positioned(
            right: 8,
            top: 16,
            child: _Confetti(color: Color(0xFFF97316), angle: 0.7),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: CustomPaint(size: Size(40, 36), painter: _ParcelPainter()),
          ),
        ],
      ),
    );
    if (Motion.reduced(context)) return art;
    return art
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(
          begin: 0,
          end: -3,
          duration: const Duration(milliseconds: 1700),
          curve: Curves.easeInOut,
        );
  }
}

class _Confetti extends StatelessWidget {
  const _Confetti({required this.color, required this.angle});

  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 5,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  const _Spark({required this.color, this.size = 5});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ParcelPainter extends CustomPainter {
  const _ParcelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 12, 30, 22),
      const Radius.circular(3),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFFE8A15A));
    final lid = RRect.fromRectAndRadius(
      const Rect.fromLTWH(2, 7, 34, 9),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(lid, Paint()..color = const Color(0xFFF0B56A));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 7, 6, 27),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFFD98A45),
    );
    const badge = Offset(32, 28);
    canvas
      ..drawCircle(badge, 8, Paint()..color = Colors.white)
      ..drawCircle(badge, 6.4, Paint()..color = OrdersPalette.green);
    final check = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(28.6, 28)
        ..lineTo(31.1, 30.5)
        ..lineTo(35.6, 25.6),
      check,
    );
  }

  @override
  bool shouldRepaint(_ParcelPainter oldDelegate) => false;
}

/// The cancelled card's document with a red cross.
class CancelledNote extends StatelessWidget {
  const CancelledNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(size: Size(40, 42), painter: _NotePainter());
  }
}

class _NotePainter extends CustomPainter {
  const _NotePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final page = RRect.fromRectAndRadius(
      const Rect.fromLTWH(2, 0, 28, 34),
      const Radius.circular(4),
    );
    canvas.drawRRect(page, Paint()..color = Colors.white);
    canvas.drawRRect(
      page,
      Paint()
        ..color = const Color(0xFFE7EAF2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final line = Paint()
      ..color = const Color(0xFFD5DAE6)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(7, 8), const Offset(24, 8), line)
      ..drawLine(const Offset(7, 14), const Offset(22, 14), line)
      ..drawLine(const Offset(7, 20), const Offset(18, 20), line);
    const badge = Offset(28, 30);
    canvas
      ..drawCircle(badge, 8, Paint()..color = Colors.white)
      ..drawCircle(badge, 6.4, Paint()..color = OrdersPalette.red);
    final cross = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(25.4, 27.4), const Offset(30.6, 32.6), cross)
      ..drawLine(const Offset(30.6, 27.4), const Offset(25.4, 32.6), cross);
  }

  @override
  bool shouldRepaint(_NotePainter oldDelegate) => false;
}
