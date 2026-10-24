import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';

/// The tappable search field in the headers. It opens the search page, where typing happens.
class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.onTap,
    this.hint = 'Search products, brands...',
    this.height = 35.7,
    this.radius = 11,
    this.iconLeft = 11.1,
    this.iconSize = 15.6,
    this.textLeft = 39.1,
    this.heroTag = 'search-field',
  }) : _compact = false;

  /// Home header proportions.
  const SearchPill.compact({super.key, required this.onTap, this.heroTag = 'search-field'})
      : hint = 'Search products...',
        height = 36,
        radius = 11.7,
        iconLeft = 13.95,
        iconSize = 15.5,
        textLeft = 41,
        _compact = true;

  final VoidCallback onTap;
  final String hint;
  final double height;
  final double radius;
  final double iconLeft;
  final double iconSize;
  final double textLeft;
  final Object heroTag;
  final bool _compact;

  static final hintStyle = AppTypography.bodyLarge.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.22,
    color: AppPallete.searchHint,
    height: 1.2,
  );

  static final compactHintStyle = hintStyle.copyWith(fontSize: 10.9, letterSpacing: -0.44);

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.98,
      semanticLabel: 'Search products',
      onTap: onTap,
      child: Hero(
        tag: heroTag,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: AppPallete.searchFill,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(color: const Color(0xFF000A3C).withValues(alpha: 0.22), blurRadius: 3),
              ],
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: iconLeft,
                  child: Icon(PhosphorIconsBold.magnifyingGlass, size: iconSize, color: AppPallete.searchIcon),
                ),
                Positioned(
                  left: textLeft,
                  right: 12,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      hint,
                      style: _compact ? compactHintStyle : hintStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
