import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/models/paginated.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/repositories/catalog_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalog_providers.g.dart';

/// Unwraps a repository result for a provider: failures become the provider's error.
T _unwrap<T>(Either<AppFailure, T> result) => switch (result) {
      Left(value: final failure) => throw failure,
      Right(value: final value) => value,
    };

/// Keeps an auto-dispose provider's value for [duration] after its last listener leaves, so going
/// back and forth between pages doesn't refetch.
void _cacheFor(Ref ref, Duration duration) {
  final link = ref.keepAlive();
  Timer? timer;
  ref
    ..onCancel(() => timer = Timer(duration, link.close))
    ..onResume(() => timer?.cancel())
    ..onDispose(() => timer?.cancel());
}

@Riverpod(keepAlive: true)
Future<List<HomeSection>> homeSections(Ref ref) async =>
    _unwrap(await ref.watch(catalogRepositoryProvider).homepage());

@Riverpod(keepAlive: true)
Future<List<CategoryModel>> categories(Ref ref) async =>
    _unwrap(await ref.watch(catalogRepositoryProvider).categories());

/// Featured categories in their featured order, for the homepage category cards.
@riverpod
Future<List<CategoryModel>> featuredCategories(Ref ref) async {
  final all = await ref.watch(categoriesProvider.future);
  final featured = all.where((c) => c.isFeatured && c.subcategories.isNotEmpty).toList()
    ..sort((a, b) => a.featuredOrder.compareTo(b.featuredOrder));
  if (featured.isNotEmpty) return featured;
  return all.where((c) => c.subcategories.isNotEmpty).take(2).toList();
}

@riverpod
Future<CategoryModel?> categoryBySlug(Ref ref, String slug) async {
  final all = await ref.watch(categoriesProvider.future);
  for (final category in all) {
    if (category.slug == slug) return category;
  }
  return null;
}

@riverpod
Future<ProductDetail> productDetail(Ref ref, String slug) async {
  _cacheFor(ref, const Duration(minutes: 5));
  return _unwrap(await ref.watch(catalogRepositoryProvider).product(slug));
}

@Riverpod(keepAlive: true)
Future<StoreSettings> storeSettings(Ref ref) async =>
    _unwrap(await ref.watch(catalogRepositoryProvider).storeSettings());

/// A paginated product list for one [ProductQuery]. Pages append as the list scrolls.
@riverpod
class ProductList extends _$ProductList {
  bool _loadingMore = false;
  AppFailure? _moreFailure;

  /// Set when loading the next page failed; the list shows a retry row.
  AppFailure? get moreFailure => _moreFailure;

  @override
  Future<Paginated<ProductSummary>> build(ProductQuery query) async {
    _cacheFor(ref, const Duration(minutes: 3));
    _moreFailure = null;
    return _unwrap(await ref.watch(catalogRepositoryProvider).products(query));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    final nextPage = current?.nextPage;
    if (current == null || nextPage == null || _loadingMore) return;
    _loadingMore = true;
    _moreFailure = null;
    final result = await ref.read(catalogRepositoryProvider).products(query, page: nextPage);
    _loadingMore = false;
    switch (result) {
      case Left(value: final failure):
        _moreFailure = failure;
        state = AsyncData(current);
      case Right(value: final page):
        state = AsyncData(current.append(page));
    }
  }
}

/// Products related to [productId]: same subcategory when it has others, else same category.
@riverpod
Future<List<ProductSummary>> relatedProducts(
  Ref ref, {
  required String productId,
  required String categorySlug,
  String? subcategorySlug,
}) async {
  _cacheFor(ref, const Duration(minutes: 5));
  final repo = ref.watch(catalogRepositoryProvider);
  Future<List<ProductSummary>> fetch(ProductQuery query) async =>
      _unwrap(await repo.products(query)).results.where((p) => p.id != productId).take(10).toList();

  if (subcategorySlug != null) {
    final siblings = await fetch(ProductQuery(subcategorySlug: subcategorySlug));
    if (siblings.length >= 2) return siblings;
  }
  return fetch(ProductQuery(categorySlug: categorySlug));
}
