/// Every location in the app. Builders take typed arguments so call sites can't misspell a path.
abstract final class Routes {
  // Tabs
  static const home = '/home';
  static const categories = '/categories';
  static const wishlist = '/wishlist';
  static const account = '/account';
  static const cart = '/cart';

  // Catalog
  static const search = '/search';
  static const products = '/products';
  static String category(String slug) => '/category/$slug';
  static String product(String slug) => '/product/$slug';

  /// A product list for a subcategory, featured products, a sale, or a search.
  static String productList({
    String? title,
    String? categorySlug,
    String? subcategorySlug,
    bool featured = false,
    bool onSale = false,
    String? query,
    String? ordering,
  }) {
    final params = <String, String>{
      'title': ?title,
      'category': ?categorySlug,
      'subcategory': ?subcategorySlug,
      if (featured) 'featured': 'true',
      if (onSale) 'sale': 'true',
      'q': ?query,
      'ordering': ?ordering,
    };
    return Uri(path: products, queryParameters: params.isEmpty ? null : params).toString();
  }

  // Checkout
  static const checkout = '/checkout';
  static String payment(String orderId) => '/payment/$orderId';
  static String orderSuccess(String orderId) => '/order-success/$orderId';

  // Orders
  static const orders = '/orders';
  static String ordersFiltered(String status) => '/orders?status=$status';
  static String order(String id) => '/orders/$id';
  static String orderDetails(String id) => '/orders/$id/details';
  static const trackOrder = '/track-order';

  // Auth
  static const login = '/login';
  static const register = '/register';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static String loginFrom(String location) => Uri(path: login, queryParameters: {'from': location}).toString();
  static String verifyEmailFor(String email) => Uri(path: verifyEmail, queryParameters: {'email': email}).toString();

  // Account
  static const profile = '/account/profile';
  static const addresses = '/account/addresses';
  static const newAddress = '/account/addresses/new';
  static String editAddress(String id) => '/account/addresses/$id';
  static const changePassword = '/account/password';
  static const privacy = '/account/privacy';
  static const help = '/help';
  static String helpFor(String orderNumber) => '/help?order=${Uri.encodeQueryComponent(orderNumber)}';
  static const settings = '/account/settings';
  static const notifications = '/notifications';
  static const vouchers = '/account/vouchers';
  static const paymentMethods = '/payment-methods';
  static const membership = '/membership';

  /// Locations that need a signed-in customer.
  static bool isProtected(String location) =>
      location == notifications ||
      location == help ||
      (location != vouchers &&
          (location.startsWith(orders) || location.startsWith('$account/') || location == membership));

  /// Sign-in screens a signed-in customer has no reason to see.
  static bool isAuthScreen(String location) =>
      location == login || location == register || location == verifyEmail || location == forgotPassword;
}
