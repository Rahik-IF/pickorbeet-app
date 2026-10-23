import 'package:flutter/material.dart';

import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/utils/formatters.dart';

/// A money amount that counts from its previous value to the new one.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(
    this.value, {
    super.key,
    required this.style,
    this.deduction = false,
    this.duration = const Duration(milliseconds: 550),
    this.textAlign,
  });

  /// API money string, such as `"5657.00"`.
  final String value;
  final TextStyle style;

  /// Shows `- ৳ 800`.
  final bool deduction;
  final Duration duration;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final target = Formatters.decimal(value).toDouble();
    final hasFraction = target != target.roundToDouble();
    String format(double amount) {
      final rounded = hasFraction ? (amount * 100).round() / 100 : amount.roundToDouble();
      return deduction ? Formatters.deduction(rounded) : Formatters.money(rounded);
    }

    return Semantics(
      label: format(target),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: Motion.of(context, duration),
        curve: Motion.emphasizedDecelerate,
        builder: (context, amount, _) => Text(format(amount), style: style, textAlign: textAlign, maxLines: 1),
      ),
    );
  }
}

/// A number that rolls up or down when it changes, as in a quantity stepper.
class RollingNumber extends StatefulWidget {
  const RollingNumber(this.value, {super.key, required this.style});

  final int value;
  final TextStyle style;

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber> {
  late int _previous = widget.value;

  @override
  void didUpdateWidget(RollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _previous = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    // Increasing values enter from below and push the old value up; decreasing values the reverse.
    final direction = widget.value >= _previous ? 1.0 : -1.0;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: Motion.of(context, Motion.short),
        switchInCurve: Motion.emphasizedDecelerate,
        switchOutCurve: Motion.emphasizedAccelerate,
        transitionBuilder: (child, animation) {
          final entering = child.key == ValueKey(widget.value);
          final from = Offset(0, (entering ? 0.9 : -0.9) * direction);
          return SlideTransition(
            position: Tween(begin: from, end: Offset.zero).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Text('${widget.value}', key: ValueKey(widget.value), style: widget.style),
      ),
    );
  }
}
