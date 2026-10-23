import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/network/api_client.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';

/// Counts for the account dashboard, from `GET /orders/my-orders/summary/`.
@immutable
class OrderSummary {
  const OrderSummary({
    required this.pending,
    required this.delivered,
    required this.cancelled,
    required this.returned,
  });

  /// Orders still on the way: pending through out for delivery.
  final int pending;
  final int delivered;
  final int cancelled;
  final int returned;

  factory OrderSummary.fromMap(Json map) => OrderSummary(
        pending: map.integer('open'),
        delivered: map.integer('delivered'),
        cancelled: map.integer('cancelled'),
        returned: map.integer('returned'),
      );
}

class OrderSummaryRepository {
  const OrderSummaryRepository(this._api);

  final ApiClient _api;

  Future<Either<AppFailure, OrderSummary>> fetch() => guardRequest(
        () => _api.get('/orders/my-orders/summary/'),
        (body) => OrderSummary.fromMap(asJson(body)),
        success: const {200},
      );
}

final orderSummaryRepositoryProvider = Provider<OrderSummaryRepository>(
  (ref) => OrderSummaryRepository(ref.watch(apiClientProvider)),
);

/// `null` while signed out. Failures stay on the provider so the rest of the dashboard still shows.
final orderSummaryProvider = FutureProvider<OrderSummary?>((ref) async {
  if (ref.watch(sessionNotifierProvider) != SessionStatus.signedIn) return null;
  final result = await ref.watch(orderSummaryRepositoryProvider).fetch();
  return result.fold((failure) => throw failure, (summary) => summary);
});
