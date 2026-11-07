import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/motion/animated_values.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';

/// Minus, count, plus. The count rolls in the direction of the change.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.height = 26,
    this.buttonWidth = 26,
    this.valueWidth = 26,
    this.radius = 6,
    this.enabled = true,
    this.canIncrease = true,
    this.canDecrease = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;

  /// May sit below [value] when an item stops being available; "-" still works then.
  final int max;
  final double height;
  final double buttonWidth;
  final double valueWidth;
  final double radius;

  /// Turns both buttons off, for example while a request is in flight.
  final bool enabled;
  final bool canIncrease;
  final bool canDecrease;

  bool get _increases => enabled && canIncrease && value < max;
  bool get _decreases => enabled && canDecrease && value > min;

  void _step(int delta) {
    final next = (value + delta).clamp(min, math.max<int>(max, value));
    if (next == value) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Quantity',
      value: '$value',
      increasedValue: _increases ? '${value + 1}' : null,
      decreasedValue: _decreases ? '${value - 1}' : null,
      onIncrease: _increases ? () => _step(1) : null,
      onDecrease: _decreases ? () => _step(-1) : null,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppPallete.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppPallete.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepButton(
              icon: PhosphorIconsBold.minus,
              width: buttonWidth,
              enabled: _decreases,
              onTap: () => _step(-1),
            ),
            SizedBox(
              width: valueWidth,
              child: Center(
                child: ExcludeSemantics(
                  child: RollingNumber(
                    value,
                    style: AppTypography.label.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            _StepButton(
              icon: PhosphorIconsBold.plus,
              width: buttonWidth,
              enabled: _increases,
              onTap: () => _step(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.width, required this.enabled, required this.onTap});

  final IconData icon;
  final double width;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Pressable(
        pressedScale: 0.85,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: Icon(icon, size: 11, color: enabled ? AppPallete.ink : AppPallete.textHint),
        ),
      ),
    );
  }
}
