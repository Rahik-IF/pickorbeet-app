import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/models/address_model.dart';
import 'package:pickorbeet/core/models/paginated.dart';
import 'package:pickorbeet/core/network/api_client.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';

class AddressRepository {
  const AddressRepository(this._api);

  final ApiClient _api;

  Future<Either<AppFailure, List<AddressModel>>> list() => guardRequest(
        () => _api.get('/auth/addresses/'),
        (body) {
          if (body is List) return [for (final item in asJsonList(body)) AddressModel.fromMap(item)];
          return Paginated.fromBody(body, AddressModel.fromMap).results;
        },
        success: const {200},
      );

  Future<Either<AppFailure, AddressModel>> save(AddressModel address, {String? id}) => guardRequest(
        () => id == null
            ? _api.post('/auth/addresses/', body: address.toMap())
            : _api.patch('/auth/addresses/$id/', body: address.toMap()),
        (body) => AddressModel.fromMap(asJson(body)),
      );

  Future<Either<AppFailure, Unit>> remove(String id) => guardRequest(
        () => _api.delete('/auth/addresses/$id/'),
        (_) => unit,
        success: const {204},
      );
}

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => AddressRepository(ref.watch(apiClientProvider)),
);

final addressesProvider = FutureProvider<List<AddressModel>>((ref) async {
  final result = await ref.watch(addressRepositoryProvider).list();
  return result.fold((failure) => throw failure, (items) => items);
});
