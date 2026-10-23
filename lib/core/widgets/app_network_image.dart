import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/constants/server_constant.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';

/// Cached product image, decoded at its rendered size so large uploads don't bloat memory.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.background = AppPallete.surfaceMuted,
    this.placeholderIcon = PhosphorIconsLight.image,
    this.alignment = Alignment.center,
  });

  final String? url;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final Color background;
  final IconData placeholderIcon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final resolved = ServerConstant.mediaUrl(url);
    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (resolved.isEmpty) return _Fallback(icon: placeholderIcon);
            final ratio = MediaQuery.devicePixelRatioOf(context);
            final width = constraints.hasBoundedWidth ? (constraints.maxWidth * ratio).round() : null;
            final height =
                width == null && constraints.hasBoundedHeight ? (constraints.maxHeight * ratio).round() : null;
            return CachedNetworkImage(
              imageUrl: resolved,
              fit: fit,
              alignment: alignment,
              width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
              height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
              memCacheWidth: width,
              memCacheHeight: height,
              fadeInDuration: const Duration(milliseconds: 220),
              fadeOutDuration: const Duration(milliseconds: 120),
              placeholder: (_, _) => const SizedBox.expand(),
              errorWidget: (_, _, _) => _Fallback(icon: placeholderIcon),
            );
          },
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = (constraints.biggest.shortestSide * 0.32).clamp(14.0, 40.0);
          return Icon(icon, size: size, color: AppPallete.textHint.withValues(alpha: 0.7));
        },
      ),
    );
  }
}
