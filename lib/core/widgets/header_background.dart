import 'package:flutter/material.dart';

import 'package:pickorbeet/core/theme/app_pallete.dart';

/// The header's blue gradient with the soft glow in the lower right, sampled from the designs.
class HeaderBackground extends StatelessWidget {
  const HeaderBackground({super.key, required this.child, this.borderRadius = BorderRadius.zero});

  final Widget child;
  final BorderRadius borderRadius;

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppPallete.headerStart, AppPallete.headerMid, AppPallete.headerEnd],
    stops: [0, 0.55, 1],
  );

  static const glow = RadialGradient(
    center: Alignment(0.95, 1.05),
    radius: 0.85,
    colors: [Color(0x660A3AAE), Color(0x000A3AAE)],
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: gradient),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: glow),
          child: child,
        ),
      ),
    );
  }
}
