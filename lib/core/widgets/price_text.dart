import 'package:flutter/material.dart';

import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/utils/formatters.dart';

/// Current price with the struck-through compare price when it is higher.
class PriceText extends StatelessWidget {
  const PriceText({
    super.key,
    required this.price,
    this.comparePrice,
    this.style,
    this.strikeStyle,
    this.gap = 6,
    this.axis = Axis.horizontal,
  });

  final String price;
  final String? comparePrice;
  final TextStyle? style;
  final TextStyle? strikeStyle;
  final double gap;
  final Axis axis;

  bool get showCompare {
    final compare = comparePrice;
    if (compare == null || compare.isEmpty) return false;
    return Formatters.decimal(compare) > Formatters.decimal(price);
  }

  @override
  Widget build(BuildContext context) {
    final current = Text(
      Formatters.money(price),
      style: style ?? AppTypography.price,
      maxLines: 1,
    );
    if (!showCompare) return current;
    final strike = Text(
      Formatters.money(comparePrice),
      style: strikeStyle ?? AppTypography.strike,
      maxLines: 1,
    );
    return Semantics(
      label: '${Formatters.money(price)}, was ${Formatters.money(comparePrice)}',
      excludeSemantics: true,
      child: axis == Axis.horizontal
          ? Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [current, SizedBox(width: gap), Flexible(child: strike)],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [current, SizedBox(height: gap), strike],
            ),
    );
  }
}

/// "20% OFF" pill.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({
    super.key,
    required this.percent,
    this.color = AppPallete.sale,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    this.radius = 4,
    this.suffix = ' OFF',
  });

  final num percent;
  final Color color;
  final TextStyle? textStyle;
  final EdgeInsets padding;
  final double radius;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (percent <= 0) return const SizedBox.shrink();
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
      child: Text(
        '${percent.round()}%$suffix',
        style: textStyle ??
            AppTypography.caption.copyWith(
              color: AppPallete.onDark,
              fontWeight: FontWeight.w700,
              fontSize: 8.5,
              height: 1.1,
            ),
        maxLines: 1,
      ),
    );
  }
}
