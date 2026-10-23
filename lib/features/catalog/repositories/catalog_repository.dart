import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/models/paginated.dart';
import 'package:pickorbeet/core/network/api_client.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalog_repository.g.dart';

@riverpod
CatalogRepository catalogRepository(Ref ref) => CatalogRepository(ref.watch(apiClientProvider));

/// Public catalog reads. They go out without a token, so a stale session never costs a refresh.
class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;

  Future<Either<AppFailure, List<HomeSection>>> homepage() => guardRequest(
        () => _api.get('/products/homepage/', authenticated: false),
        (body) => [
          for (final section in asJson(body).listOf('sections', (json) => json))
            ?HomeSection.fromMap(section),
        ],
      );

  /// Every active category. The server pages at 20, so this follows `next` for larger catalogs.
  Future<Either<AppFailure, List<CategoryModel>>> categories() async {
    final items = <CategoryModel>[];
    int? page = 1;
    while (page != null && page <= 10) {
      final requested = page;
      final result = await guardRequest(
        () => _api.get('/products/categories/', query: {'page': '$requested'}, authenticated: false),
        (body) => Paginated.fromBody(body, CategoryModel.fromMap),
      );
      switch (result) {
        case Left(value: final failure):
          return Left(failure);
        case Right(value: final current):
          items.addAll(current.results);
          page = current.nextPage;
      }
    }
    items.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return Right(items);
  }

  Future<Either<AppFailure, Paginated<ProductSummary>>> products(ProductQuery query, {int page = 1}) =>
      guardRequest(
        () => _api.get('/products/', query: query.toQuery(page: page), authenticated: false),
        (body) => Paginated.fromBody(body, ProductSummary.fromMap),
      );

  /// Products by id, in the order given. Used for the wishlist; the server caps the list at 50.
  Future<Either<AppFailure, List<ProductSummary>>> productsByIds(List<String> ids) async {
    if (ids.isEmpty) return const Right([]);
    final result = await guardRequest(
      () => _api.get('/products/', query: {'ids': ids.take(50).join(',')}, authenticated: false),
      (body) => Paginated.fromBody(body, ProductSummary.fromMap).results,
    );
    return result.map((items) {
      final byId = {for (final item in items) item.id: item};
      return [for (final id in ids) ?byId[id]];
    });
  }

  Future<Either<AppFailure, ProductDetail>> product(String slug) => guardRequest(
        () => _api.get('/products/${Uri.encodeComponent(slug)}/', authenticated: false),
        (body) => ProductDetail.fromMap(asJson(body)),
      );

  Future<Either<AppFailure, StoreSettings>> storeSettings() => guardRequest(
        () => _api.get('/products/settings/public/', authenticated: false),
        (body) => StoreSettings.fromMap(asJson(body)),
      );
}

/// Contact details and search suggestions from the store settings.
class StoreSettings {
  const StoreSettings({
    required this.popularSearches,
    required this.address,
    required this.phones,
    required this.emails,
    required this.businessHours,
  });

  factory StoreSettings.fromMap(Json map) => StoreSettings(
        popularSearches: map
            .str('popular_searches')
            .split(',')
            .map((term) => term.trim())
            .where((term) => term.isNotEmpty)
            .toList(),
        address: map.str('contact_address'),
        phones: [map.str('contact_phone_1'), map.str('contact_phone_2')].where((v) => v.isNotEmpty).toList(),
        emails: [map.str('contact_email_1'), map.str('contact_email_2')].where((v) => v.isNotEmpty).toList(),
        businessHours: map.str('business_hours'),
      );

  final List<String> popularSearches;
  final String address;
  final List<String> phones;
  final List<String> emails;
  final String businessHours;
}
