import 'package:pickorbeet/features/catalog/models/catalog_models.dart';

final _colorName = RegExp(r'\bcolou?rs?\b', caseSensitive: false);

sealed class GallerySlide {
  const GallerySlide();
}

class GalleryImageSlide extends GallerySlide {
  const GalleryImageSlide(this.image);
  final ProductImage image;
}

class GalleryVideoSlide extends GallerySlide {
  const GalleryVideoSlide(this.video);
  final ProductVideo video;
}

List<VariantChoice> galleryVariantChoices(ProductVariant variant) {
  if (variant.options.isNotEmpty) return variant.options;
  return [
    if ((variant.size ?? '').trim().isNotEmpty)
      VariantChoice(name: 'Size', label: variant.size!.trim()),
    if ((variant.color ?? '').trim().isNotEmpty)
      VariantChoice(name: 'Color', kind: 'swatch', label: variant.color!.trim()),
  ];
}

List<ProductVariant> candidateVariantsForPicks(
  List<ProductVariant> variants,
  Map<String, String> picked,
) {
  final picks = [
    for (final entry in picked.entries)
      if (entry.value.trim().isNotEmpty) entry,
  ];
  final active = [for (final variant in variants) if (variant.isActive) variant];
  if (picks.isEmpty) return active;
  final matches = <ProductVariant>[];
  for (final variant in active) {
    final choices = galleryVariantChoices(variant);
    final ok = picks.every(
      (pick) => choices.any(
        (choice) => choice.name == pick.key && choice.label == pick.value,
      ),
    );
    if (ok) matches.add(variant);
  }
  return matches;
}

List<T> _itemsForVariantIds<T>({
  required List<T> all,
  required Set<String> ids,
  required String? Function(T item) variantOf,
}) {
  if (ids.isEmpty) return const [];
  return [
    for (final item in all)
      if ((variantOf(item) ?? '').isNotEmpty && ids.contains(variantOf(item))) item,
  ];
}

List<T> _colorLinkedItems<T>({
  required List<T> all,
  required List<ProductVariant> variants,
  required Map<String, String> picked,
  required String? Function(T item) variantOf,
}) {
  MapEntry<String, String>? colorPick;
  for (final entry in picked.entries) {
    if (entry.value.trim().isEmpty) continue;
    if (_colorName.hasMatch(entry.key)) {
      colorPick = entry;
      break;
    }
  }
  if (colorPick == null) return const [];
  final siblingIds = <String>{
    for (final variant in variants)
      if (galleryVariantChoices(variant).any(
        (choice) => choice.name == colorPick!.key && choice.label == colorPick.value,
      ))
        variant.id,
  };
  return _itemsForVariantIds(all: all, ids: siblingIds, variantOf: variantOf);
}

List<T> scopedGalleryItems<T>({
  required List<T> all,
  required ProductDetail detail,
  ProductVariant? chosen,
  Map<String, String> picked = const {},
  required String? Function(T item) variantOf,
}) {
  if (all.isEmpty) return const [];
  final shared = [for (final item in all) if ((variantOf(item) ?? '').isEmpty) item];

  if (chosen != null && chosen.id.isNotEmpty) {
    final exact = [for (final item in all) if (variantOf(item) == chosen.id) item];
    if (exact.isNotEmpty) return exact;

    final colorPicked = <String, String>{
      ...picked,
      for (final choice in galleryVariantChoices(chosen))
        if (_colorName.hasMatch(choice.name)) choice.name: choice.label,
    };
    final byColor = _colorLinkedItems(
      all: all,
      variants: detail.summary.variants,
      picked: colorPicked,
      variantOf: variantOf,
    );
    if (byColor.isNotEmpty) return byColor;
    return shared.isNotEmpty ? shared : all;
  }

  final hasPicks = picked.values.any((label) => label.trim().isNotEmpty);
  if (hasPicks) {
    final candidates = candidateVariantsForPicks(detail.summary.variants, picked);
    final forCandidates = _itemsForVariantIds(
      all: all,
      ids: {for (final variant in candidates) variant.id},
      variantOf: variantOf,
    );
    if (forCandidates.isNotEmpty) return forCandidates;

    final byColor = _colorLinkedItems(
      all: all,
      variants: detail.summary.variants,
      picked: picked,
      variantOf: variantOf,
    );
    if (byColor.isNotEmpty) return byColor;
  }

  return shared.isNotEmpty ? shared : all;
}

/// Gallery images for the current variant / option picks.
List<ProductImage> galleryImagesForSelection({
  required ProductDetail detail,
  ProductVariant? chosen,
  Map<String, String> picked = const {},
}) {
  final scoped = scopedGalleryItems<ProductImage>(
    all: detail.images,
    detail: detail,
    chosen: chosen,
    picked: picked,
    variantOf: (image) => image.variant,
  );
  if (scoped.isNotEmpty) return scoped;
  final fallback = detail.summary.primaryImage;
  if (fallback == null || fallback.isEmpty) return const [];
  return [
    ProductImage(id: 'primary', image: fallback, altText: '', isPrimary: true),
  ];
}

List<ProductVideo> galleryVideosForSelection({
  required ProductDetail detail,
  ProductVariant? chosen,
  Map<String, String> picked = const {},
}) {
  return scopedGalleryItems<ProductVideo>(
    all: detail.videos,
    detail: detail,
    chosen: chosen,
    picked: picked,
    variantOf: (video) => video.variant,
  );
}

List<String> galleryUrlsForSelection({
  required ProductDetail detail,
  ProductVariant? chosen,
  Map<String, String> picked = const {},
}) {
  final images = galleryImagesForSelection(
    detail: detail,
    chosen: chosen,
    picked: picked,
  );
  return [for (final image in images) if (image.image.isNotEmpty) image.image];
}

/// Mixed gallery slides: images first, then YouTube videos.
List<GallerySlide> galleryMediaForSelection({
  required ProductDetail detail,
  ProductVariant? chosen,
  Map<String, String> picked = const {},
}) {
  final images = galleryImagesForSelection(
    detail: detail,
    chosen: chosen,
    picked: picked,
  );
  final videos = galleryVideosForSelection(
    detail: detail,
    chosen: chosen,
    picked: picked,
  );
  return [
    for (final image in images) GalleryImageSlide(image),
    for (final video in videos)
      if (video.youtubeId.isNotEmpty) GalleryVideoSlide(video),
  ];
}
