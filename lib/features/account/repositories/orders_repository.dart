import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/models/paginated.dart';
import 'package:pickorbeet/core/network/api_client.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/features/account/model/customer_order.dart';
import 'package:pickorbeet/features/account/model/order_detail.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => OrdersRepository(ref.watch(apiClientProvider)),
);

/// `GET /orders/my-orders/` and the customer cancel action.
class OrdersRepository {
  const OrdersRepository(this._api);

  final ApiClient _api;

  Future<Either<AppFailure, Paginated<CustomerOrder>>> list({
    String? status,
    String search = '',
    int page = 1,
  }) => guardRequest(
    () => _api.get(
      '/orders/my-orders/',
      query: {'page': page, 'order_status': status, 'search': search.trim()},
    ),
    (body) => Paginated.fromBody(body, CustomerOrder.fromMap),
  );

  Future<Either<AppFailure, CustomerOrder>> cancel(String id) => guardRequest(
    () => _api.post('/orders/my-orders/$id/cancel/'),
    (body) => CustomerOrder.fromMap(asJson(body)),
  );

  Future<Either<AppFailure, OrderDetail>> detail(String id) => guardRequest(
    () => _api.get('/orders/my-orders/$id/'),
    (body) => OrderDetail.fromMap(asJson(body)),
  );

  /// Asks Steadfast for a fresh status. The server allows this once a minute.
  Future<Either<AppFailure, OrderDetail>> refreshShipment(String id) => guardRequest(
    () => _api.post('/orders/my-orders/$id/shipment/refresh/'),
    (body) => OrderDetail.fromMap(asJson(body)),
  );

  /// Public lookup by order number or Steadfast tracking code.
  Future<Either<AppFailure, TrackingResult>> track({required String query, String phone = ''}) {
    final value = query.trim();
    return guardRequest(
      () => _api.post('/orders/track/', body: {
        'order_number': value,
        'tracking_code': value,
        if (phone.trim().isNotEmpty) 'phone': phone.trim(),
      }),
      (body) => TrackingResult.fromMap(asJson(body)),
    );
  }
}
