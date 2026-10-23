import 'package:flutter/widgets.dart';

/// Shared duration and curve tokens. Every effect reads [reduced] and becomes instant when the
/// platform asks for less motion.
abstract final class Motion {
  static const micro = Duration(milliseconds: 120);
  static const short = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 300);
  static const long = Duration(milliseconds: 450);
  static const entrance = Duration(milliseconds: 420);
  static const page = Duration(milliseconds: 320);

  /// Delay between items in a staggered entrance, capped so long lists don't drag.
  static const stagger = Duration(milliseconds: 40);
  static const staggerCap = 8;

  /// Material 3 emphasized easing.
  static const emphasized = Curves.easeInOutCubicEmphasized;
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);
  static const emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);
  static const standard = Cubic(0.2, 0, 0, 1);

  /// Snappy spring for press feedback and small pops.
  static const pressSpring = SpringDescription(mass: 1, stiffness: 520, damping: 28);

  /// Bouncier spring for badges and hearts.
  static const popSpring = SpringDescription(mass: 1, stiffness: 380, damping: 14);

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when motion is reduced.
  static Duration of(BuildContext context, Duration duration) => reduced(context) ? Duration.zero : duration;

  static Duration staggerDelay(int index) => stagger * index.clamp(0, staggerCap);
}
