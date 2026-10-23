import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/home/view/widgets/category_section_card.dart';

/// "100% Authentic", "Fast Delivery" and the other store promises, in four columns.
class TrustStrip extends StatelessWidget {
  const TrustStrip({super.key, required this.items});

  final List<BenefitItem> items;

  static const height = 69.9;

  static final _titleStyle = AppTypography.label.copyWith(
    fontSize: 8.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.255,
    height: 1.2,
    color: AppPallete.ink,
  );

  static final _subtitleStyle = AppTypography.caption.copyWith(
    fontSize: 7.4,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.074,
    height: 1.2,
    color: AppPallete.benefitSubtitle,
  );

  @override
  Widget build(BuildContext context) {
    final shown = items.take(4).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    // The strip is a fixed band in the design; its labels stay legible at larger text sizes by
    // scaling a little, then ellipsizing.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15);
    return HomeCard(
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0)
                Container(width: 0.8, height: 37, color: AppPallete.divider),
              Expanded(
                flex: shown.length == _designFlex.length ? _designFlex[i] : 1,
                child: _Benefit(item: shown[i], scaler: scaler),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The design's four columns are slightly uneven (95.8, 97.7, 98.8 and 94.7 dp).
  static const _designFlex = [958, 977, 988, 947];
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.item, required this.scaler});

  final BenefitItem item;
  final TextScaler scaler;

  @override
  Widget build(BuildContext context) {
    // Phosphor draws these a little below centre; the offsets put the ink where the design has it.
    final Widget glyph = switch (item.icon) {
      'shield' => Transform.translate(
          offset: const Offset(0, -0.8),
          child: const Icon(PhosphorIconsFill.shieldCheck, size: 17.6, color: AppPallete.benefitIcon),
        ),
      'truck' => Transform.translate(
          offset: const Offset(0, -0.8),
          child: const Icon(PhosphorIconsFill.truck, size: 16.8, color: AppPallete.benefitIcon),
        ),
      'cash' => const CustomPaint(size: Size(14.7, 12.7), painter: _CashGlyphPainter()),
      'support' => Transform.translate(
          offset: const Offset(0, -0.45),
          child: const Icon(PhosphorIconsBold.headset, size: 15.8, color: AppPallete.benefitIcon),
        ),
      _ => const Icon(PhosphorIconsBold.checkCircle, size: 15, color: AppPallete.benefitIcon),
    };
    return Semantics(
      container: true,
      label: '${item.title}. ${item.description}',
      excludeSemantics: true,
      child: Column(
        children: [
          const SizedBox(height: 6.4),
          Container(
            width: 28.3,
            height: 28.3,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppPallete.benefitCircle, shape: BoxShape.circle),
            child: glyph,
          ),
          const SizedBox(height: 3.4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: scaler,
              style: TrustStrip._titleStyle,
            ),
          ),
          const SizedBox(height: 2.75),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              item.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: scaler,
              style: TrustStrip._subtitleStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// The design's cash icon: a banknote with a coin, and a second note tilted behind it.
class _CashGlyphPainter extends CustomPainter {
  const _CashGlyphPainter();

  static const _stroke = 1.45;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppPallete.benefitIcon
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    const half = _stroke / 2;
    final note = RRect.fromLTRBR(half, 3.67, size.width - half, size.height - half, const Radius.circular(1.3));
    final behind = Path()
      ..moveTo(1.95, 3.67)
      ..lineTo(2.93, 1.22)
      ..lineTo(9.29, half)
      ..lineTo(11.73, 3.67);
    canvas
      ..drawPath(behind, paint)
      ..drawRRect(note, paint)
      ..drawCircle(Offset(size.width / 2 - 0.2, 8.4), 1.95, paint);
  }

  @override
  bool shouldRepaint(_CashGlyphPainter oldDelegate) => false;
}
