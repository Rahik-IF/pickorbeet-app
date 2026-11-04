import 'package:flutter_test/flutter_test.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/product_gallery.dart';

ProductDetail _detail({
  required List<ProductImage> images,
  required List<ProductVariant> variants,
  List<OptionGroup> optionGroups = const [],
}) {
  return ProductDetail(
    summary: ProductSummary(
      id: 'p1',
      name: 'Tee',
      slug: 'tee',
      shortDescription: '',
      price: '100.00',
      discountPercentage: 0,
      stockQuantity: 5,
      isOutOfStock: false,
      isFeatured: false,
      categoryName: 'Apparel',
      variants: variants,
      primaryImage: '/media/primary.png',
    ),
    description: '',
    images: images,
    categorySlug: 'apparel',
    optionGroups: optionGroups,
  );
}

void main() {
  test('ProductImage parses optional variant id', () {
    final linked = ProductImage.fromMap({
      'id': 'i1',
      'image': '/media/white.png',
      'alt_text': '',
      'is_primary': false,
      'variant': 'v-white',
    });
    final shared = ProductImage.fromMap({
      'id': 'i2',
      'image': '/media/shared.png',
      'alt_text': '',
      'is_primary': true,
      'variant': null,
    });
    expect(linked.variant, 'v-white');
    expect(shared.variant, isNull);
  });

  test('gallery switches to the exact linked variant image', () {
    const white = ProductVariant(
      id: 'v-white',
      price: '100.00',
      stockQuantity: 2,
      isActive: true,
      color: 'White',
      options: [VariantChoice(name: 'Color', kind: 'swatch', label: 'White')],
    );
    const black = ProductVariant(
      id: 'v-black',
      price: '100.00',
      stockQuantity: 2,
      isActive: true,
      color: 'Black',
      options: [VariantChoice(name: 'Color', kind: 'swatch', label: 'Black')],
    );
    final detail = _detail(
      images: const [
        ProductImage(id: 'shared', image: '/shared.png', altText: '', isPrimary: true),
        ProductImage(
          id: 'white',
          image: '/white.png',
          altText: '',
          isPrimary: false,
          variant: 'v-white',
        ),
        ProductImage(
          id: 'black',
          image: '/black.png',
          altText: '',
          isPrimary: false,
          variant: 'v-black',
        ),
      ],
      variants: [white, black],
    );

    final urls = galleryUrlsForSelection(
      detail: detail,
      chosen: white,
      picked: const {'Color': 'White'},
    );
    expect(urls, ['/white.png']);
  });

  test('gallery uses color-linked images for a partial Size+Color pick', () {
    const whiteM = ProductVariant(
      id: 'v-white-m',
      price: '100.00',
      stockQuantity: 2,
      isActive: true,
      options: [
        VariantChoice(name: 'Size', label: 'M'),
        VariantChoice(name: 'Color', kind: 'swatch', label: 'White'),
      ],
    );
    const whiteL = ProductVariant(
      id: 'v-white-l',
      price: '100.00',
      stockQuantity: 2,
      isActive: true,
      options: [
        VariantChoice(name: 'Size', label: 'L'),
        VariantChoice(name: 'Color', kind: 'swatch', label: 'White'),
      ],
    );
    const blackM = ProductVariant(
      id: 'v-black-m',
      price: '100.00',
      stockQuantity: 2,
      isActive: true,
      options: [
        VariantChoice(name: 'Size', label: 'M'),
        VariantChoice(name: 'Color', kind: 'swatch', label: 'Black'),
      ],
    );
    final detail = _detail(
      images: const [
        ProductImage(id: 'shared', image: '/shared.png', altText: '', isPrimary: true),
        ProductImage(
          id: 'wm',
          image: '/white-m.png',
          altText: '',
          isPrimary: false,
          variant: 'v-white-m',
        ),
        ProductImage(
          id: 'wl',
          image: '/white-l.png',
          altText: '',
          isPrimary: false,
          variant: 'v-white-l',
        ),
        ProductImage(
          id: 'bm',
          image: '/black-m.png',
          altText: '',
          isPrimary: false,
          variant: 'v-black-m',
        ),
      ],
      variants: [whiteM, whiteL, blackM],
    );

    final urls = galleryUrlsForSelection(
      detail: detail,
      picked: const {'Color': 'White'},
    )..sort();
    expect(urls, ['/white-l.png', '/white-m.png']);
  });

  test('unlinked variants keep the shared gallery', () {
    const white = ProductVariant(
      id: 'v-white',
      price: '100.00',
      stockQuantity: 2,
      isActive: true,
      color: 'White',
      options: [VariantChoice(name: 'Color', kind: 'swatch', label: 'White')],
    );
    final detail = _detail(
      images: const [
        ProductImage(id: 'shared', image: '/shared.png', altText: '', isPrimary: true),
        ProductImage(id: 'extra', image: '/extra.png', altText: '', isPrimary: false),
      ],
      variants: [white],
    );

    expect(
      galleryUrlsForSelection(
        detail: detail,
        chosen: white,
        picked: const {'Color': 'White'},
      ),
      ['/shared.png', '/extra.png'],
    );
    expect(
      galleryUrlsForSelection(detail: detail),
      ['/shared.png', '/extra.png'],
    );
  });

  test('gallery media appends YouTube slides after images', () {
    const white = ProductVariant(
      id: 'v-white',
      price: '100.00',
      stockQuantity: 2,
      isActive: true,
      color: 'White',
      options: [VariantChoice(name: 'Color', kind: 'swatch', label: 'White')],
    );
    const detail = ProductDetail(
      summary: ProductSummary(
        id: 'p1',
        name: 'Tee',
        slug: 'tee',
        shortDescription: '',
        price: '100.00',
        discountPercentage: 0,
        stockQuantity: 5,
        isOutOfStock: false,
        isFeatured: false,
        categoryName: 'Apparel',
        variants: [white],
      ),
      description: '',
      images: [
        ProductImage(
          id: 'white',
          image: '/white.png',
          altText: '',
          isPrimary: true,
          variant: 'v-white',
        ),
      ],
      videos: [
        ProductVideo(
          id: 'vid-shared',
          youtubeUrl: 'https://youtu.be/dQw4w9WgXcQ',
          youtubeId: 'dQw4w9WgXcQ',
        ),
        ProductVideo(
          id: 'vid-white',
          youtubeUrl: 'https://youtu.be/abcdefghijk',
          youtubeId: 'abcdefghijk',
          variant: 'v-white',
        ),
      ],
      categorySlug: 'apparel',
    );

    final media = galleryMediaForSelection(
      detail: detail,
      chosen: white,
      picked: const {'Color': 'White'},
    );
    expect(media, hasLength(2));
    expect(media[0], isA<GalleryImageSlide>());
    expect((media[0] as GalleryImageSlide).image.image, '/white.png');
    expect(media[1], isA<GalleryVideoSlide>());
    expect((media[1] as GalleryVideoSlide).video.youtubeId, 'abcdefghijk');
  });
}
