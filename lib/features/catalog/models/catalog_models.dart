import 'package:flutter/foundation.dart';

import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/utils/formatters.dart';

/// A homepage banner. Hero and promo artwork includes its own text; [title] is the accessible
/// description.
@immutable
class BannerModel {
  const BannerModel({
    required this.id,
    required this.image,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.link,
    required this.placement,
  });

  factory BannerModel.fromMap(Json map) => BannerModel(
    id: map.str('id'),
    image: map.str('image'),
    title: map.str('title'),
    subtitle: map.str('subtitle'),
    buttonLabel: map.str('button_label'),
    link: map.str('link'),
    placement: map.str('placement', 'hero'),
  );

  final String id;
  final String image;
  final String title;
  final String subtitle;
  final String buttonLabel;

  /// A web path such as `/products` or `/category/fashion`.
  final String link;
  final String placement;
}

@immutable
class SubcategoryModel {
  const SubcategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.image,
  });

  factory SubcategoryModel.fromMap(Json map) => SubcategoryModel(
    id: map.str('id'),
    name: map.str('name'),
    slug: map.str('slug'),
    description: map.str('description'),
    image: map.strOrNull('image'),
  );

  final String id;
  final String name;
  final String slug;
  final String description;
  final String? image;
}

@immutable
class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.tagline,
    required this.isFeatured,
    required this.featuredOrder,
    required this.displayOrder,
    required this.subcategories,
    required this.productCount,
    this.image,
    this.bannerImage,
  });

  factory CategoryModel.fromMap(Json map) => CategoryModel(
    id: map.str('id'),
    name: map.str('name'),
    slug: map.str('slug'),
    description: map.str('description'),
    tagline: map.str('tagline'),
    image: map.strOrNull('image'),
    bannerImage: map.strOrNull('banner_image'),
    isFeatured: map.boolean('is_featured'),
    featuredOrder: map.integer('featured_order'),
    displayOrder: map.integer('display_order'),
    subcategories: map.listOf('subcategories', SubcategoryModel.fromMap),
    productCount: map.integer('product_count'),
  );

  final String id;
  final String name;
  final String slug;
  final String description;
  final String tagline;
  final String? image;
  final String? bannerImage;
  final bool isFeatured;
  final int featuredOrder;
  final int displayOrder;
  final List<SubcategoryModel> subcategories;
  final int productCount;
}

@immutable
class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.price,
    required this.stockQuantity,
    required this.isActive,
    this.lowStockThreshold = 10,
    this.size,
    this.color,
  });

  factory ProductVariant.fromMap(Json map) => ProductVariant(
    id: map.str('id'),
    size: map.strOrNull('size'),
    color: map.strOrNull('color'),
    price: map.money('effective_price', map.money('price')),
    stockQuantity: map.integer('stock_quantity'),
    lowStockThreshold: map.integer('low_stock_threshold', 10),
    isActive: map.boolean('is_active', true),
  );

  final String id;
  final String? size;
  final String? color;
  final String price;
  final int stockQuantity;
  final int lowStockThreshold;
  final bool isActive;

  bool get inStock => isActive && stockQuantity > 0;

  bool get isLowStock => inStock && stockQuantity <= lowStockThreshold;

  String get label =>
      [size, color].whereType<String>().where((v) => v.isNotEmpty).join(' / ');
}

double? _readRating(Json map) {
  for (final key in const ['rating', 'average_rating', 'avg_rating']) {
    final value = map[key];
    final double? rating;
    if (value is num) {
      rating = value.toDouble();
    } else if (value is String) {
      rating = double.tryParse(value);
    } else {
      rating = null;
    }
    if (rating != null && rating > 0 && rating <= 5) return rating;
  }
  return null;
}

int? _readReviewCount(Json map) {
  for (final key in const ['review_count', 'reviews_count', 'total_reviews']) {
    final value = map[key];
    final int? count;
    if (value is num) {
      count = value.toInt();
    } else if (value is String) {
      count = int.tryParse(value);
    } else {
      count = null;
    }
    if (count != null && count > 0) return count;
  }
  return null;
}

/// A product as it appears in lists and rails.
@immutable
class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.shortDescription,
    required this.price,
    this.sku = '',
    required this.discountPercentage,
    required this.stockQuantity,
    required this.isOutOfStock,
    this.isLowStock = false,
    required this.isFeatured,
    required this.categoryName,
    required this.variants,
    this.comparePrice,
    this.primaryImage,
    this.subcategoryName,
    this.rating,
    this.reviewCount,
  });

  factory ProductSummary.fromMap(Json map) => ProductSummary(
    id: map.str('id'),
    name: map.str('name'),
    slug: map.str('slug'),
    shortDescription: map.str('short_description'),
    sku: map.str('sku'),
    price: map.money('price'),
    comparePrice: map.moneyOrNull('compare_price'),
    primaryImage: map.strOrNull('primary_image'),
    discountPercentage: map.integer('discount_percentage'),
    stockQuantity: map.integer('stock_quantity'),
    isOutOfStock: map.boolean('is_out_of_stock'),
    isLowStock: map.boolean('is_low_stock'),
    isFeatured: map.boolean('is_featured'),
    categoryName: map.str('category_name'),
    subcategoryName: map.strOrNull('subcategory_name'),
    variants: map.listOf('variants', ProductVariant.fromMap),
    rating: _readRating(map),
    reviewCount: _readReviewCount(map),
  );

  final String id;
  final String name;
  final String slug;
  final String shortDescription;
  final String sku;
  final String price;
  final String? comparePrice;
  final String? primaryImage;
  final int discountPercentage;
  final int stockQuantity;
  final bool isOutOfStock;
  final bool isLowStock;
  final bool isFeatured;
  final String categoryName;
  final String? subcategoryName;
  final List<ProductVariant> variants;

  /// Shopper rating on a 5-point scale, when the catalog sends one.
  final double? rating;

  /// Number of reviews behind [rating]. Absent when the catalog has no count.
  final int? reviewCount;

  bool get hasDiscount =>
      comparePrice != null &&
      Formatters.decimal(comparePrice) > Formatters.decimal(price);

  /// Products with sizes or colours need a choice on the detail page before they go in the cart.
  bool get needsVariantChoice => variants.where((v) => v.isActive).isNotEmpty;

  @override
  bool operator ==(Object other) => other is ProductSummary && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class ProductImage {
  const ProductImage({
    required this.id,
    required this.image,
    required this.altText,
    required this.isPrimary,
  });

  factory ProductImage.fromMap(Json map) => ProductImage(
    id: map.str('id'),
    image: map.str('image'),
    altText: map.str('alt_text'),
    isPrimary: map.boolean('is_primary'),
  );

  final String id;
  final String image;
  final String altText;
  final bool isPrimary;
}

@immutable
class ProductDetail {
  const ProductDetail({
    required this.summary,
    required this.description,
    required this.images,
    required this.categorySlug,
    this.subcategorySlug,
    this.size,
    this.color,
    this.material,
  });

  factory ProductDetail.fromMap(Json map) {
    final category = map.obj('category');
    final subcategory = map.obj('subcategory');
    final images = map.listOf('images', ProductImage.fromMap)
      ..sort((a, b) => a.isPrimary == b.isPrimary ? 0 : (a.isPrimary ? -1 : 1));
    return ProductDetail(
      summary: ProductSummary.fromMap({
        ...map,
        'category_name': category?.str('name') ?? '',
        'subcategory_name': subcategory?.strOrNull('name'),
      }),
      description: map.str('description'),
      images: images,
      categorySlug: category?.str('slug') ?? '',
      subcategorySlug: subcategory?.strOrNull('slug'),
      size: map.strOrNull('size'),
      color: map.strOrNull('color'),
      material: map.strOrNull('material'),
    );
  }

  final ProductSummary summary;
  final String description;
  final List<ProductImage> images;
  final String categorySlug;
  final String? subcategorySlug;
  final String? size;
  final String? color;
  final String? material;

  /// Description with HTML removed, keeping paragraph and list breaks.
  String get plainDescription => _plainProductText(description);

  /// Gallery images, falling back to the primary image when the gallery is empty.
  List<String> get gallery {
    final urls = images.map((i) => i.image).where((u) => u.isNotEmpty).toList();
    if (urls.isEmpty && summary.primaryImage != null) {
      urls.add(summary.primaryImage!);
    }
    return urls;
  }

  /// Short spec rows shown under the description.
  List<(String, String)> get specs => [
    if (color != null && color!.isNotEmpty) ('Color', color!),
    if (size != null && size!.isNotEmpty) ('Size', size!),
    if (material != null && material!.isNotEmpty) ('Material', material!),
    (
      'Category',
      [
        summary.categoryName,
        summary.subcategoryName,
      ].whereType<String>().join(' · '),
    ),
  ];
}

String _plainProductText(String raw) {
  var source = raw.replaceAll('\r\n', '\n').trim();
  if (source.isEmpty || !source.contains('<')) return source;
  source = source
      .replaceAll(
        RegExp('<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true),
        '',
      )
      .replaceAll(
        RegExp('<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true),
        '',
      );
  final withBreaks = source
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp('</p>|</div>|</h[1-6]>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp('</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp('<li[^>]*>', caseSensitive: false), '• ');
  final stripped = withBreaks.replaceAll(RegExp('<[^>]+>'), '');
  final decoded = stripped
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
  return decoded
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// "100% Authentic / Original Products" and the like.
@immutable
class BenefitItem {
  const BenefitItem({
    required this.title,
    required this.description,
    required this.icon,
  });

  factory BenefitItem.fromMap(Json map) => BenefitItem(
    title: map.str('title'),
    description: map.str('description'),
    icon: map.str('icon'),
  );

  final String title;
  final String description;

  /// One of `shield`, `truck`, `cash`, `support`; unknown names fall back to a check mark.
  final String icon;
}

/// One block of the homepage, in the order the admin arranged them.
@immutable
sealed class HomeSection {
  const HomeSection({required this.key, required this.title});

  final String key;
  final String title;

  /// Parses a section, or returns null for types this app version doesn't know.
  static HomeSection? fromMap(Json map) {
    final key = map.str('key');
    final title = map.str('title');
    return switch (map.str('type')) {
      'hero' => HeroSection(
        key: key,
        title: title,
        banners: map.listOf('banners', BannerModel.fromMap),
      ),
      'promos' => PromoSection(
        key: key,
        title: title,
        banners: map.listOf('banners', BannerModel.fromMap),
      ),
      'categories' => CategoriesSection(
        key: key,
        title: title,
        viewAllUrl: map.str('view_all_url', '/categories'),
      ),
      'benefits' => BenefitsSection(
        key: key,
        title: title,
        items: map.listOf('items', BenefitItem.fromMap),
      ),
      'products' => ProductsSection(
        key: key,
        title: title,
        viewAllLabel: map.str('view_all_label', 'View All'),
        viewAllUrl: map.str('view_all_url', '/products'),
        products: map.listOf('products', ProductSummary.fromMap),
      ),
      _ => null,
    };
  }
}

final class HeroSection extends HomeSection {
  const HeroSection({
    required super.key,
    required super.title,
    required this.banners,
  });

  final List<BannerModel> banners;
}

final class PromoSection extends HomeSection {
  const PromoSection({
    required super.key,
    required super.title,
    required this.banners,
  });

  final List<BannerModel> banners;
}

final class CategoriesSection extends HomeSection {
  const CategoriesSection({
    required super.key,
    required super.title,
    required this.viewAllUrl,
  });

  final String viewAllUrl;
}

final class BenefitsSection extends HomeSection {
  const BenefitsSection({
    required super.key,
    required super.title,
    required this.items,
  });

  final List<BenefitItem> items;
}

final class ProductsSection extends HomeSection {
  const ProductsSection({
    required super.key,
    required super.title,
    required this.viewAllLabel,
    required this.viewAllUrl,
    required this.products,
  });

  final String viewAllLabel;
  final String viewAllUrl;
  final List<ProductSummary> products;
}

/// Filters for the product list endpoint.
@immutable
class ProductQuery {
  const ProductQuery({
    this.categorySlug,
    this.subcategorySlug,
    this.search,
    this.ordering,
    this.featured = false,
    this.onSale = false,
    this.minPrice,
    this.maxPrice,
  });

  final String? categorySlug;
  final String? subcategorySlug;
  final String? search;

  /// `price`, `-price`, `-created_at` or `name`.
  final String? ordering;
  final bool featured;
  final bool onSale;
  final String? minPrice;
  final String? maxPrice;

  Map<String, String?> toQuery({int? page}) => {
    'category_slug': categorySlug,
    'subcategory_slug': subcategorySlug,
    'search': search,
    'ordering': ordering,
    if (featured) 'is_featured': 'true',
    if (onSale) 'on_sale': 'true',
    'min_price': minPrice,
    'max_price': maxPrice,
    'page': page?.toString(),
  };

  ProductQuery copyWith({
    String? ordering,
    String? search,
    bool? onSale,
    String? minPrice,
    String? maxPrice,
    bool clearPrice = false,
  }) => ProductQuery(
    categorySlug: categorySlug,
    subcategorySlug: subcategorySlug,
    search: search ?? this.search,
    ordering: ordering ?? this.ordering,
    featured: featured,
    onSale: onSale ?? this.onSale,
    minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
    maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
  );

  @override
  bool operator ==(Object other) =>
      other is ProductQuery &&
      other.categorySlug == categorySlug &&
      other.subcategorySlug == subcategorySlug &&
      other.search == search &&
      other.ordering == ordering &&
      other.featured == featured &&
      other.onSale == onSale &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice;

  @override
  int get hashCode => Object.hash(
    categorySlug,
    subcategorySlug,
    search,
    ordering,
    featured,
    onSale,
    minPrice,
    maxPrice,
  );
}
