import 'dart:async';

import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'wishlist_notifier.g.dart';

/// Wishlisted product ids, newest first. Like the website, the list lives on the device.
@Riverpod(keepAlive: true)
class WishlistNotifier extends _$WishlistNotifier {
  static const _key = 'wishlist_ids';

  /// The products endpoint looks up at most this many ids at once.
  static const capacity = 50;

  @override
  List<String> build() => ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const [];

  /// Adds or removes [productId]. Returns whether it is now wishlisted, or null when the list is
  /// full and nothing changed.
  bool? toggle(String productId) {
    final current = state;
    if (current.contains(productId)) {
      _save([for (final id in current) if (id != productId) id]);
      return false;
    }
    if (current.length >= capacity) return null;
    _save([productId, ...current]);
    return true;
  }

  void remove(String productId) {
    if (!state.contains(productId)) return;
    _save([for (final id in state) if (id != productId) id]);
  }

  /// Removes every id in [productIds] with one write. Unknown ids are ignored.
  void removeMany(Iterable<String> productIds) {
    final drop = productIds.toSet();
    if (drop.isEmpty) return;
    final next = [for (final id in state) if (!drop.contains(id)) id];
    if (next.length != state.length) _save(next);
  }

  /// Restores an item at its old position, for undo.
  void restore(String productId, int index) {
    if (state.contains(productId)) return;
    final next = [...state]..insert(index.clamp(0, state.length), productId);
    _save(next);
  }

  void clear() => _save(const []);

  /// Drops ids the server no longer knows about, such as deleted products.
  void retainOnly(Set<String> knownIds) {
    final next = [for (final id in state) if (knownIds.contains(id)) id];
    if (next.length != state.length) _save(next);
  }

  void _save(List<String> ids) {
    state = ids;
    unawaited(ref.read(sharedPreferencesProvider).setStringList(_key, ids));
  }
}

/// Whether one product is wishlisted; rebuilds only that product's heart.
final isWishlistedProvider = Provider.family<bool, String>(
  (ref, productId) => ref.watch(wishlistNotifierProvider.select((ids) => ids.contains(productId))),
);
