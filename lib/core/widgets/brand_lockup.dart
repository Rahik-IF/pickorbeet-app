import 'package:flutter/material.dart';

import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';

/// The bag mark and "PickOrbeet" wordmark.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.markSize = const Size(32.7, 34.7),
    this.markLift = 1,
    this.wordmarkSize = 20.8,
    this.wordmarkDrop = 0,
    this.gap = 6.4,
    this.onDark = true,
  });

  /// Home header proportions.
  const BrandLockup.compact({super.key, this.onDark = true})
      : markSize = const Size(31.8, 32.7),
        markLift = 0.5,
        wordmarkSize = 19.85,
        wordmarkDrop = 1,
        gap = 5.5;

  /// The box the mark is centred in. The official mark is narrower than the design's drawing, so
  /// centring it keeps the wordmark where the design puts it.
  final Size markSize;

  /// How far the mark sits above the wordmark's centre line.
  final double markLift;
  final double wordmarkSize;

  /// How far the wordmark sits below the row's centre line.
  final double wordmarkDrop;
  final double gap;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.wordmarkOf(wordmarkSize);
    return Semantics(
      label: 'PickOrbeet',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: Offset(0, -markLift),
            child: SizedBox.fromSize(
              size: markSize,
              child: Image.asset(
                onDark ? 'assets/brand/bag_mark_on_dark.png' : 'assets/brand/bag_mark.png',
                fit: BoxFit.contain,
                cacheHeight: (markSize.height * 3).round(),
              ),
            ),
          ),
          SizedBox(width: gap),
          Transform.translate(
            offset: Offset(0, wordmarkDrop),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Pick', style: style.copyWith(color: onDark ? AppPallete.onDark : AppPallete.ink)),
                  TextSpan(text: 'Orbeet', style: style.copyWith(color: AppPallete.wordmarkOrange)),
                ],
              ),
              maxLines: 1,
              textScaler: TextScaler.noScaling,
            ),
          ),
        ],
      ),
    );
  }
}
