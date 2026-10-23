// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$homeSectionsHash() => r'af455698dbe9e4532775f323cd7dba3377f7ae48';

/// See also [homeSections].
@ProviderFor(homeSections)
final homeSectionsProvider = FutureProvider<List<HomeSection>>.internal(
  homeSections,
  name: r'homeSectionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$homeSectionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HomeSectionsRef = FutureProviderRef<List<HomeSection>>;
String _$categoriesHash() => r'315dcca1499a16b112cb8d6c2c0b627e3c816a3e';

/// See also [categories].
@ProviderFor(categories)
final categoriesProvider = FutureProvider<List<CategoryModel>>.internal(
  categories,
  name: r'categoriesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$categoriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CategoriesRef = FutureProviderRef<List<CategoryModel>>;
String _$featuredCategoriesHash() =>
    r'379fb2f1cd1d588f15d77f184da813b799f24668';

/// Featured categories in their featured order, for the homepage category cards.
///
/// Copied from [featuredCategories].
@ProviderFor(featuredCategories)
final featuredCategoriesProvider =
    AutoDisposeFutureProvider<List<CategoryModel>>.internal(
      featuredCategories,
      name: r'featuredCategoriesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$featuredCategoriesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FeaturedCategoriesRef =
    AutoDisposeFutureProviderRef<List<CategoryModel>>;
String _$categoryBySlugHash() => r'641a4cca6beea588592c1e13757ef084530f7eb0';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [categoryBySlug].
@ProviderFor(categoryBySlug)
const categoryBySlugProvider = CategoryBySlugFamily();

/// See also [categoryBySlug].
class CategoryBySlugFamily extends Family<AsyncValue<CategoryModel?>> {
  /// See also [categoryBySlug].
  const CategoryBySlugFamily();

  /// See also [categoryBySlug].
  CategoryBySlugProvider call(String slug) {
    return CategoryBySlugProvider(slug);
  }

  @override
  CategoryBySlugProvider getProviderOverride(
    covariant CategoryBySlugProvider provider,
  ) {
    return call(provider.slug);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'categoryBySlugProvider';
}

/// See also [categoryBySlug].
class CategoryBySlugProvider extends AutoDisposeFutureProvider<CategoryModel?> {
  /// See also [categoryBySlug].
  CategoryBySlugProvider(String slug)
    : this._internal(
        (ref) => categoryBySlug(ref as CategoryBySlugRef, slug),
        from: categoryBySlugProvider,
        name: r'categoryBySlugProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$categoryBySlugHash,
        dependencies: CategoryBySlugFamily._dependencies,
        allTransitiveDependencies:
            CategoryBySlugFamily._allTransitiveDependencies,
        slug: slug,
      );

  CategoryBySlugProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.slug,
  }) : super.internal();

  final String slug;

  @override
  Override overrideWith(
    FutureOr<CategoryModel?> Function(CategoryBySlugRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CategoryBySlugProvider._internal(
        (ref) => create(ref as CategoryBySlugRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        slug: slug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<CategoryModel?> createElement() {
    return _CategoryBySlugProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CategoryBySlugProvider && other.slug == slug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, slug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CategoryBySlugRef on AutoDisposeFutureProviderRef<CategoryModel?> {
  /// The parameter `slug` of this provider.
  String get slug;
}

class _CategoryBySlugProviderElement
    extends AutoDisposeFutureProviderElement<CategoryModel?>
    with CategoryBySlugRef {
  _CategoryBySlugProviderElement(super.provider);

  @override
  String get slug => (origin as CategoryBySlugProvider).slug;
}

String _$productDetailHash() => r'96190328f46f346d2ed5df884de64d63ecca7169';

/// See also [productDetail].
@ProviderFor(productDetail)
const productDetailProvider = ProductDetailFamily();

/// See also [productDetail].
class ProductDetailFamily extends Family<AsyncValue<ProductDetail>> {
  /// See also [productDetail].
  const ProductDetailFamily();

  /// See also [productDetail].
  ProductDetailProvider call(String slug) {
    return ProductDetailProvider(slug);
  }

  @override
  ProductDetailProvider getProviderOverride(
    covariant ProductDetailProvider provider,
  ) {
    return call(provider.slug);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'productDetailProvider';
}

/// See also [productDetail].
class ProductDetailProvider extends AutoDisposeFutureProvider<ProductDetail> {
  /// See also [productDetail].
  ProductDetailProvider(String slug)
    : this._internal(
        (ref) => productDetail(ref as ProductDetailRef, slug),
        from: productDetailProvider,
        name: r'productDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$productDetailHash,
        dependencies: ProductDetailFamily._dependencies,
        allTransitiveDependencies:
            ProductDetailFamily._allTransitiveDependencies,
        slug: slug,
      );

  ProductDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.slug,
  }) : super.internal();

  final String slug;

  @override
  Override overrideWith(
    FutureOr<ProductDetail> Function(ProductDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ProductDetailProvider._internal(
        (ref) => create(ref as ProductDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        slug: slug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ProductDetail> createElement() {
    return _ProductDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductDetailProvider && other.slug == slug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, slug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ProductDetailRef on AutoDisposeFutureProviderRef<ProductDetail> {
  /// The parameter `slug` of this provider.
  String get slug;
}

class _ProductDetailProviderElement
    extends AutoDisposeFutureProviderElement<ProductDetail>
    with ProductDetailRef {
  _ProductDetailProviderElement(super.provider);

  @override
  String get slug => (origin as ProductDetailProvider).slug;
}

String _$storeSettingsHash() => r'6521a570cb90485c96a6ea882178bff7357fd7ce';

/// See also [storeSettings].
@ProviderFor(storeSettings)
final storeSettingsProvider = FutureProvider<StoreSettings>.internal(
  storeSettings,
  name: r'storeSettingsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$storeSettingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StoreSettingsRef = FutureProviderRef<StoreSettings>;
String _$relatedProductsHash() => r'87d7f4ec37f8dd2216ca164123ca6da3aadab6be';

/// Products related to [productId]: same subcategory when it has others, else same category.
///
/// Copied from [relatedProducts].
@ProviderFor(relatedProducts)
const relatedProductsProvider = RelatedProductsFamily();

/// Products related to [productId]: same subcategory when it has others, else same category.
///
/// Copied from [relatedProducts].
class RelatedProductsFamily extends Family<AsyncValue<List<ProductSummary>>> {
  /// Products related to [productId]: same subcategory when it has others, else same category.
  ///
  /// Copied from [relatedProducts].
  const RelatedProductsFamily();

  /// Products related to [productId]: same subcategory when it has others, else same category.
  ///
  /// Copied from [relatedProducts].
  RelatedProductsProvider call({
    required String productId,
    required String categorySlug,
    String? subcategorySlug,
  }) {
    return RelatedProductsProvider(
      productId: productId,
      categorySlug: categorySlug,
      subcategorySlug: subcategorySlug,
    );
  }

  @override
  RelatedProductsProvider getProviderOverride(
    covariant RelatedProductsProvider provider,
  ) {
    return call(
      productId: provider.productId,
      categorySlug: provider.categorySlug,
      subcategorySlug: provider.subcategorySlug,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'relatedProductsProvider';
}

/// Products related to [productId]: same subcategory when it has others, else same category.
///
/// Copied from [relatedProducts].
class RelatedProductsProvider
    extends AutoDisposeFutureProvider<List<ProductSummary>> {
  /// Products related to [productId]: same subcategory when it has others, else same category.
  ///
  /// Copied from [relatedProducts].
  RelatedProductsProvider({
    required String productId,
    required String categorySlug,
    String? subcategorySlug,
  }) : this._internal(
         (ref) => relatedProducts(
           ref as RelatedProductsRef,
           productId: productId,
           categorySlug: categorySlug,
           subcategorySlug: subcategorySlug,
         ),
         from: relatedProductsProvider,
         name: r'relatedProductsProvider',
         debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
             ? null
             : _$relatedProductsHash,
         dependencies: RelatedProductsFamily._dependencies,
         allTransitiveDependencies:
             RelatedProductsFamily._allTransitiveDependencies,
         productId: productId,
         categorySlug: categorySlug,
         subcategorySlug: subcategorySlug,
       );

  RelatedProductsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.productId,
    required this.categorySlug,
    required this.subcategorySlug,
  }) : super.internal();

  final String productId;
  final String categorySlug;
  final String? subcategorySlug;

  @override
  Override overrideWith(
    FutureOr<List<ProductSummary>> Function(RelatedProductsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RelatedProductsProvider._internal(
        (ref) => create(ref as RelatedProductsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        productId: productId,
        categorySlug: categorySlug,
        subcategorySlug: subcategorySlug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<ProductSummary>> createElement() {
    return _RelatedProductsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RelatedProductsProvider &&
        other.productId == productId &&
        other.categorySlug == categorySlug &&
        other.subcategorySlug == subcategorySlug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, productId.hashCode);
    hash = _SystemHash.combine(hash, categorySlug.hashCode);
    hash = _SystemHash.combine(hash, subcategorySlug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RelatedProductsRef on AutoDisposeFutureProviderRef<List<ProductSummary>> {
  /// The parameter `productId` of this provider.
  String get productId;

  /// The parameter `categorySlug` of this provider.
  String get categorySlug;

  /// The parameter `subcategorySlug` of this provider.
  String? get subcategorySlug;
}

class _RelatedProductsProviderElement
    extends AutoDisposeFutureProviderElement<List<ProductSummary>>
    with RelatedProductsRef {
  _RelatedProductsProviderElement(super.provider);

  @override
  String get productId => (origin as RelatedProductsProvider).productId;
  @override
  String get categorySlug => (origin as RelatedProductsProvider).categorySlug;
  @override
  String? get subcategorySlug =>
      (origin as RelatedProductsProvider).subcategorySlug;
}

String _$productListHash() => r'7de3a017b0598bd7dc58ab360df462325b00e474';

abstract class _$ProductList
    extends BuildlessAutoDisposeAsyncNotifier<Paginated<ProductSummary>> {
  late final ProductQuery query;

  FutureOr<Paginated<ProductSummary>> build(ProductQuery query);
}

/// A paginated product list for one [ProductQuery]. Pages append as the list scrolls.
///
/// Copied from [ProductList].
@ProviderFor(ProductList)
const productListProvider = ProductListFamily();

/// A paginated product list for one [ProductQuery]. Pages append as the list scrolls.
///
/// Copied from [ProductList].
class ProductListFamily extends Family<AsyncValue<Paginated<ProductSummary>>> {
  /// A paginated product list for one [ProductQuery]. Pages append as the list scrolls.
  ///
  /// Copied from [ProductList].
  const ProductListFamily();

  /// A paginated product list for one [ProductQuery]. Pages append as the list scrolls.
  ///
  /// Copied from [ProductList].
  ProductListProvider call(ProductQuery query) {
    return ProductListProvider(query);
  }

  @override
  ProductListProvider getProviderOverride(
    covariant ProductListProvider provider,
  ) {
    return call(provider.query);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'productListProvider';
}

/// A paginated product list for one [ProductQuery]. Pages append as the list scrolls.
///
/// Copied from [ProductList].
class ProductListProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          ProductList,
          Paginated<ProductSummary>
        > {
  /// A paginated product list for one [ProductQuery]. Pages append as the list scrolls.
  ///
  /// Copied from [ProductList].
  ProductListProvider(ProductQuery query)
    : this._internal(
        () => ProductList()..query = query,
        from: productListProvider,
        name: r'productListProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$productListHash,
        dependencies: ProductListFamily._dependencies,
        allTransitiveDependencies: ProductListFamily._allTransitiveDependencies,
        query: query,
      );

  ProductListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.query,
  }) : super.internal();

  final ProductQuery query;

  @override
  FutureOr<Paginated<ProductSummary>> runNotifierBuild(
    covariant ProductList notifier,
  ) {
    return notifier.build(query);
  }

  @override
  Override overrideWith(ProductList Function() create) {
    return ProviderOverride(
      origin: this,
      override: ProductListProvider._internal(
        () => create()..query = query,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        query: query,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<
    ProductList,
    Paginated<ProductSummary>
  >
  createElement() {
    return _ProductListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductListProvider && other.query == query;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ProductListRef
    on AutoDisposeAsyncNotifierProviderRef<Paginated<ProductSummary>> {
  /// The parameter `query` of this provider.
  ProductQuery get query;
}

class _ProductListProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          ProductList,
          Paginated<ProductSummary>
        >
    with ProductListRef {
  _ProductListProviderElement(super.provider);

  @override
  ProductQuery get query => (origin as ProductListProvider).query;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
