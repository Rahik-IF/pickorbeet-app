import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/network/api_client.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/features/vouchers/model/store_voucher.dart';

final vouchersRepositoryProvider = Provider<VouchersRepository>(
  (ref) => VouchersRepository(ref.watch(apiClientProvider)),
);

/// `GET /orders/coupons/` — the shopper vouchers wallet.
class VouchersRepository {
  const VouchersRepository(this._api);

  final ApiClient _api;

  /// With [itemIds], each available voucher says whether it covers those cart lines.
  Future<Either<AppFailure, List<StoreVoucher>>> list({List<String>? itemIds}) => guardRequest(
        () => _api.get(
          '/orders/coupons/',
          query: {if (itemIds != null) 'item_ids': itemIds.join(',')},
        ),
        (body) {
          final rows = asJsonList(body);
          return [
            for (var i = 0; i < rows.length; i++) StoreVoucher.fromApi(rows[i], index: i),
          ];
        },
        success: const {200},
      );
}

final vouchersProvider = FutureProvider<List<StoreVoucher>>((ref) async {
  final result = await ref.watch(vouchersRepositoryProvider).list();
  return result.fold((failure) => throw failure, (items) => items);
});
