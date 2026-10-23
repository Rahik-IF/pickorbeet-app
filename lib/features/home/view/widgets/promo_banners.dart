import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/router/web_link.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/widgets/banner_image.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';

/// One promo tile. Promo artwork includes its own text, so the tile is just the image and a link.
class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key, required this.banner, required this.aspect, this.radius = 11.2});

  /// Half-width tiles under the hero (design: 188.2 x 78.7).
  static const halfAspect = 188.2 / 78.7;

  /// The full-width "everyday essentials" strip (artwork: 779 x 144).
  static const wideAspect = 779 / 144;

  final BannerModel banner;
  final double aspect;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final location = WebLink.resolve(banner.link, title: banner.title.isEmpty ? null : banner.title);
    return Pressable(
      pressedScale: 0.97,
      semanticLabel: banner.title.isEmpty ? 'Promotion' : banner.title,
      onTap: location == null ? null : () => context.push(location),
      child: AspectRatio(
        aspectRatio: aspect,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(color: AppPallete.shadow.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BannerImage(url: banner.image, slotAspect: aspect),
          ),
        ),
      ),
    );
  }
}

/// The two promo tiles side by side.
class PromoRow extends StatelessWidget {
  const PromoRow({super.key, required this.banners});

  final List<BannerModel> banners;

  @override
  Widget build(BuildContext context) {
    final pair = banners.take(2).toList();
    if (pair.isEmpty) return const SizedBox.shrink();
    if (pair.length == 1) return PromoBanner(banner: pair.first, aspect: PromoBanner.halfAspect * 2);
    return Row(
      children: [
        Expanded(child: PromoBanner(banner: pair[0], aspect: PromoBanner.halfAspect)),
        const SizedBox(width: 10.3),
        Expanded(child: PromoBanner(banner: pair[1], aspect: PromoBanner.halfAspect)),
      ],
    );
  }
}
