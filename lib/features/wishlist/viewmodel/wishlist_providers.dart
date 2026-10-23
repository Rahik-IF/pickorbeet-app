import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pickorbeet/core/providers/wishlist_notifier.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/repositories/catalog_repository.dart';

/// Saved products, newest first. An empty wishlist does not hit the network.
final wishlistProductsProvider = FutureProvider<List<ProductSummary>>((ref) async {
  final ids = ref.watch(wishlistNotifierProvider);
  if (ids.isEmpty) return const [];
  final result = await ref.watch(catalogRepositoryProvider).productsByIds(ids);
  return result.fold((failure) => throw failure, (items) => items);
});
