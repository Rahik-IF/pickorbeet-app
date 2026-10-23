import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/models/address_model.dart';
import 'package:pickorbeet/core/network/api_client.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/features/account/repositories/address_repository.dart';

/// The order id returned by checkout, enough to open the order or start payment.
@immutable
class PlacedOrder {
  const PlacedOrder({required this.id, required this.orderNumber});

  final String id;
  final String orderNumber;

  factory PlacedOrder.fromMap(Json map) {
    final order = map.obj('order') ?? map;
    return PlacedOrder(
      id: order.str('id'),
      orderNumber: order.str('order_number'),
    );
  }
}

class CheckoutRepository {
  const CheckoutRepository(this._api);

  final ApiClient _api;

  Future<Either<AppFailure, PlacedOrder>> place(Map<String, Object?> body) =>
      guardRequest(
        () => _api.post('/orders/checkout/', body: body),
        (payload) => PlacedOrder.fromMap(asJson(payload)),
        success: const {201},
      );

  /// SSLCommerz page for bKash, Nagad, and cards.
  Future<Either<AppFailure, String>> paymentUrl(String orderId) => guardRequest(
    () => _api.post('/payments/initiate/', body: {'order_id': orderId}),
    (payload) {
      final url = asJson(payload).str('payment_url');
      if (url.isEmpty) throw const FormatException('Missing payment url');
      return url;
    },
  );
}

final checkoutRepositoryProvider = Provider<CheckoutRepository>(
  (ref) => CheckoutRepository(ref.watch(apiClientProvider)),
);

/// Saved addresses for a signed-in customer. Guests get an empty list and type an address instead.
final checkoutAddressesProvider = FutureProvider<List<AddressModel>>((
  ref,
) async {
  if (ref.watch(sessionNotifierProvider) != SessionStatus.signedIn) {
    return const [];
  }
  final result = await ref.read(addressRepositoryProvider).list();
  return result.fold((failure) => throw failure, (items) => items);
});
