import 'package:flutter/material.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// App-wide skeleton look: a soft blue-grey shimmer, or a still tint when motion is reduced.
class AppSkeletonTheme extends StatelessWidget {
  const AppSkeletonTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SkeletonizerConfig(
      data: SkeletonizerConfigData(
        effectResolver: (_) => Motion.reduced(context)
            ? const SolidColorEffect(color: AppPallete.skeleton)
            : const ShimmerEffect(
                baseColor: AppPallete.skeleton,
                highlightColor: Color(0xFFF5F8FD),
                duration: Duration(milliseconds: 1300),
              ),
        justifyMultiLineText: false,
        containersColor: AppPallete.skeleton,
      ),
      child: child,
    );
  }
}

/// A plain rounded block for hand-built skeleton layouts.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height, this.radius = 6});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Skeleton.leaf(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: AppPallete.skeleton, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}
