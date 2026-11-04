import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/network/api_client.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';

@immutable
class BdDivision {
  const BdDivision({required this.id, required this.name, required this.slug});

  final String id;
  final String name;
  final String slug;

  factory BdDivision.fromMap(Json map) => BdDivision(
        id: map.str('id'),
        name: map.str('name'),
        slug: map.str('slug'),
      );
}

@immutable
class BdDistrict {
  const BdDistrict({required this.id, required this.name, required this.slug});

  final String id;
  final String name;
  final String slug;

  factory BdDistrict.fromMap(Json map) => BdDistrict(
        id: map.str('id'),
        name: map.str('name'),
        slug: map.str('slug'),
      );
}

@immutable
class BdPostOffice {
  const BdPostOffice({
    required this.id,
    required this.name,
    required this.postalCode,
  });

  final String id;
  final String name;
  final String postalCode;

  factory BdPostOffice.fromMap(Json map) => BdPostOffice(
        id: map.str('id'),
        name: map.str('name'),
        postalCode: map.str('postal_code'),
      );
}

class GeoRepository {
  const GeoRepository(this._api);

  final ApiClient _api;

  Future<Either<AppFailure, List<BdDivision>>> divisions() => guardRequest(
        () => _api.get('/geo/divisions/', authenticated: false),
        (body) => [for (final item in asJsonList(body)) BdDivision.fromMap(item)],
        success: const {200},
      );

  Future<Either<AppFailure, List<BdDistrict>>> districts(String division) => guardRequest(
        () => _api.get('/geo/districts/', query: {'division': division}, authenticated: false),
        (body) => [for (final item in asJsonList(body)) BdDistrict.fromMap(item)],
        success: const {200},
      );

  Future<Either<AppFailure, List<BdPostOffice>>> postOffices(String district) => guardRequest(
        () => _api.get('/geo/post-offices/', query: {'district': district}, authenticated: false),
        (body) => [for (final item in asJsonList(body)) BdPostOffice.fromMap(item)],
        success: const {200},
      );
}

final geoRepositoryProvider = Provider<GeoRepository>(
  (ref) => GeoRepository(ref.watch(apiClientProvider)),
);

final bdDivisionsProvider = FutureProvider<List<BdDivision>>((ref) async {
  final result = await ref.watch(geoRepositoryProvider).divisions();
  return result.fold((failure) => throw failure, (items) => items);
});

final bdDistrictsProvider = FutureProvider.family<List<BdDistrict>, String>((ref, division) async {
  if (division.trim().isEmpty) return const [];
  final result = await ref.watch(geoRepositoryProvider).districts(division);
  return result.fold((failure) => throw failure, (items) => items);
});

final bdPostOfficesProvider = FutureProvider.family<List<BdPostOffice>, String>((ref, district) async {
  if (district.trim().isEmpty) return const [];
  final result = await ref.watch(geoRepositoryProvider).postOffices(district);
  return result.fold((failure) => throw failure, (items) => items);
});
