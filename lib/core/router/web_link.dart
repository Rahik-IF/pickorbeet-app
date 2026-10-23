import 'package:pickorbeet/core/router/routes.dart';

/// Banner and section links are website paths, such as `/category/fashion` or
/// `/products?on_sale=true`. This maps them to app locations.
abstract final class WebLink {
  /// The app location for [link], or null for external URLs and paths the app doesn't have.
  static String? resolve(String link, {String? title}) {
    final trimmed = link.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || (uri.hasScheme && !_isOwnSite(uri))) return null;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final query = uri.queryParameters;
    if (segments.isEmpty) return Routes.home;

    return switch (segments) {
      ['products'] => Routes.productList(
          title: title ?? query['title'],
          categorySlug: query['category_slug'],
          subcategorySlug: query['subcategory_slug'],
          featured: _flag(query['is_featured']) || _flag(query['featured']),
          onSale: _flag(query['on_sale']) || _flag(query['sale']),
          query: query['search'] ?? query['q'],
          ordering: query['ordering'],
        ),
      ['categories'] => Routes.categories,
      ['category', final slug] => Routes.category(slug),
      ['product', final slug] => Routes.product(slug),
      ['cart'] => Routes.cart,
      ['wishlist'] => Routes.wishlist,
      ['account'] || ['profile', ...] => Routes.account,
      ['orders'] => Routes.orders,
      ['track-order'] => Routes.trackOrder,
      ['contact'] => Routes.help,
      _ => null,
    };
  }

  static bool _flag(String? value) => value == '1' || value == 'true' || value == 'True';

  static bool _isOwnSite(Uri uri) => uri.host.endsWith('pickorbeet.com');
}
