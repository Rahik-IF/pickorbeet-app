import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:pickorbeet/features/cart/repositories/cart_remote_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cart_notifier.g.dart';

/// The cart for the whole session; drives the badge, the cart tab, and checkout.
///
/// Quantity changes and removals apply immediately and reconcile with the server. Writes run one
/// at a time and only the newest response is applied, so fast stepper taps settle correctly.
@Riverpod(keepAlive: true)
class CartNotifier extends _$CartNotifier {
  Future<void> _tail = Future.value();
  int _revision = 0;

  CartRemoteRepository get _repo => ref.read(cartRemoteRepositoryProvider);

  @override
  Future<CartModel> build() async {
    // Signing in or out switches between the session cart and the account cart.
    ref.watch(sessionNotifierProvider);
    final result = await ref.read(cartRemoteRepositoryProvider).fetch();
    return result.getOrElse((failure) => throw failure);
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }

  Future<Either<AppFailure, CartModel>> add(CartLine line) {
    final revision = ++_revision;
    return _serial(() async {
      final result = await _repo.add(line);
      if (result case Right(value: final cart) when revision == _revision) state = AsyncData(cart);
      return result;
    });
  }

  /// Returns the failure, if any, after rolling back to the server's cart.
  Future<AppFailure?> setQuantity(String itemId, int quantity) async {
    final current = state.valueOrNull;
    final item = current?.itemById(itemId);
    if (current == null || item == null || quantity < 1 || quantity == item.quantity) return null;

    state = AsyncData(current.withItems([
      for (final line in current.items) line.id == itemId ? line.withQuantity(quantity) : line,
    ]));
    final revision = ++_revision;
    return _serial(() async {
      final result = await _repo.updateQuantity(itemId, quantity);
      return _settle(result, revision);
    });
  }

  /// Removes a line at once and returns it so the caller can offer undo.
  Future<(CartItemModel?, AppFailure?)> remove(String itemId) async {
    final current = state.valueOrNull;
    final item = current?.itemById(itemId);
    if (current == null || item == null) return (null, null);

    state = AsyncData(current.withItems([for (final line in current.items) if (line.id != itemId) line]));
    final revision = ++_revision;
    final failure = await _serial(() async => _settle(await _repo.remove(itemId), revision));
    return (item, failure);
  }

  Future<AppFailure?> undoRemove(CartItemModel item) async {
    final result = await add(CartLine.of(item));
    return result.fold((failure) => failure, (_) => null);
  }

  Future<AppFailure?> clear() async {
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return null;
    state = AsyncData(current.withItems(const []));
    final revision = ++_revision;
    return _serial<AppFailure?>(() async {
      switch (await _repo.clear()) {
        case Right():
          return null;
        case Left(value: final failure):
          if (revision == _revision) await reload();
          return failure;
      }
    });
  }

  /// Re-adds a guest's lines to the account cart after sign-in, then empties the session cart.
  Future<void> mergeGuestLines(List<CartLine> lines) async {
    if (lines.isEmpty) return;
    await _serial(() async {
      for (final line in lines) {
        await _repo.add(line);
      }
      await _repo.clear(asGuest: true);
    });
    await reload();
  }

  Future<AppFailure?> _settle(Either<AppFailure, CartModel> result, int revision) async {
    switch (result) {
      case Right(value: final cart):
        if (revision == _revision) state = AsyncData(cart);
        return null;
      case Left(value: final failure):
        if (revision == _revision) await reload();
        return failure;
    }
  }

  Future<T> _serial<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await task());
      } on Object catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }
}
