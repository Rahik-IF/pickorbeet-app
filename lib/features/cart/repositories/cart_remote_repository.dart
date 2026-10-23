import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/network/api_client.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cart_remote_repository.g.dart';

@riverpod
CartRemoteRepository cartRemoteRepository(Ref ref) => CartRemoteRepository(ref.watch(apiClientProvider));

/// `/orders/cart/` endpoints. Every call returns the whole cart.
class CartRemoteRepository {
  CartRemoteRepository(this._api);

  final ApiClient _api;

  Future<Either<AppFailure, CartModel>> fetch({bool asGuest = false}) => guardRequest(
        () => _api.get('/orders/cart/', authenticated: !asGuest),
        _parse,
        success: const {200},
      );

  Future<Either<AppFailure, CartModel>> add(CartLine line) => guardRequest(
        () => _api.post('/orders/cart/add/', body: {
          'product_id': line.productId,
          'variant_id': ?line.variantId,
          'quantity': line.quantity,
        }),
        _parse,
      );

  Future<Either<AppFailure, CartModel>> updateQuantity(String itemId, int quantity) => guardRequest(
        () => _api.patch('/orders/cart/item/$itemId/', body: {'quantity': quantity}),
        _parse,
        success: const {200},
      );

  Future<Either<AppFailure, CartModel>> remove(String itemId) => guardRequest(
        () => _api.delete('/orders/cart/item/$itemId/'),
        _parse,
        success: const {200},
      );

  /// Checks a voucher against [subtotal] without changing the cart.
  Future<Either<AppFailure, CouponQuote>> validateCoupon({required String code, required String subtotal}) =>
      guardRequest(
        () => _api.post('/orders/coupons/validate/', body: {'code': code, 'subtotal': subtotal}),
        (body) => CouponQuote.fromMap(asJson(body)),
      );

  /// Empties the cart. [asGuest] targets the session cart even while signed in.
  Future<Either<AppFailure, Unit>> clear({bool asGuest = false}) => guardRequest(
        () => _api.delete('/orders/cart/clear/', authenticated: !asGuest),
        (_) => unit,
        success: const {200},
      );

  static CartModel _parse(Object? body) => CartModel.fromMap(asJson(body));
}
