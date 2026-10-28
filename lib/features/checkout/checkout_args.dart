import 'package:pickorbeet/core/router/routes.dart';

/// How the customer pays. Online choices continue through SSLCommerz after the order exists.
enum CheckoutPayment {
  bkash('bkash', 'bKash', 'Pay with bKash'),
  nagad('nagad', 'Nagad', 'Pay with Nagad'),
  card('card', 'Card Payment', 'Visa, MasterCard, AMEX'),
  cod('cod', 'Cash on Delivery', 'Pay when you receive');

  const CheckoutPayment(this.apiValue, this.label, this.subtitle);

  final String apiValue;
  final String label;
  final String subtitle;

  bool get online => this != CheckoutPayment.cod;

  /// bKash, Nagad, and cards are shown but not payable yet.
  bool get available => this == CheckoutPayment.cod;
}

/// The lines and voucher carried from the cart into checkout.
///
/// Stored on the URL so a sign-in redirect can come back to the same selection.
class CheckoutArgs {
  const CheckoutArgs({this.itemIds = const [], this.couponCode});

  final List<String> itemIds;
  final String? couponCode;

  factory CheckoutArgs.fromUri(Uri uri, {Object? extra}) {
    final rawItems = uri.queryParameters['items'];
    final queryCoupon = uri.queryParameters['coupon'];
    final hasQuery =
        (rawItems != null && rawItems.isNotEmpty) ||
        (queryCoupon != null && queryCoupon.isNotEmpty);
    if (hasQuery) {
      return CheckoutArgs(
        itemIds: rawItems == null || rawItems.isEmpty
            ? const []
            : [
                for (final id in rawItems.split(','))
                  if (id.isNotEmpty) id,
              ],
        couponCode: queryCoupon == null || queryCoupon.isEmpty
            ? null
            : queryCoupon,
      );
    }
    if (extra is CheckoutArgs) return extra;
    if (extra is List) {
      return CheckoutArgs(
        itemIds: [
          for (final id in extra)
            if ('$id'.isNotEmpty) '$id',
        ],
      );
    }
    return const CheckoutArgs();
  }

  String get location {
    final params = <String, String>{
      if (itemIds.isNotEmpty) 'items': itemIds.join(','),
      if (couponCode != null && couponCode!.isNotEmpty) 'coupon': couponCode!,
    };
    return Uri(
      path: Routes.checkout,
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }
}
