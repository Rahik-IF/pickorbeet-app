import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:pickorbeet/core/motion/motion.dart';

extension EntranceAnimation on Widget {
  /// Fades and rises into place, staggered by [index]. Plays once, when the widget is first built,
  /// so tab switches and data refreshes don't replay it.
  Widget entrance({int index = 0, Duration delay = Duration.zero, double rise = 14, bool enabled = true}) =>
      _Entrance(index: index, delay: delay, rise: rise, enabled: enabled, child: this);
}

class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.index,
    required this.delay,
    required this.rise,
    required this.enabled,
    required this.child,
  });

  final int index;
  final Duration delay;
  final double rise;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled || Motion.reduced(context)) return child;
    return child
        .animate(delay: Motion.staggerDelay(index) + delay)
        .fadeIn(duration: Motion.entrance, curve: Motion.emphasizedDecelerate)
        .moveY(begin: rise, end: 0, duration: Motion.entrance, curve: Motion.emphasizedDecelerate);
  }
}
