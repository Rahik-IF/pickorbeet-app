import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/models/paginated.dart';
import 'package:pickorbeet/features/account/model/customer_order.dart';
import 'package:pickorbeet/features/account/repositories/order_summary_repository.dart';
import 'package:pickorbeet/features/account/repositories/orders_repository.dart';

final ordersControllerProvider = AsyncNotifierProvider.autoDispose
    .family<OrdersController, OrdersState, String?>(OrdersController.new);

/// The loaded page of orders, plus the chip and search that produced it.
@immutable
class OrdersState {
  const OrdersState({
    required this.orders,
    required this.filter,
    required this.search,
    required this.page,
    required this.hasMore,
    required this.resultCount,
    this.loadingMore = false,
  });

  final List<CustomerOrder> orders;
  final OrderFilter filter;
  final String search;
  final int page;
  final bool hasMore;
  final int resultCount;
  final bool loadingMore;

  OrdersState copyWith({
    List<CustomerOrder>? orders,
    OrderFilter? filter,
    String? search,
    int? page,
    bool? hasMore,
    int? resultCount,
    bool? loadingMore,
  }) => OrdersState(
    orders: orders ?? this.orders,
    filter: filter ?? this.filter,
    search: search ?? this.search,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    resultCount: resultCount ?? this.resultCount,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Loads, filters, searches, and cancels the signed-in customer's orders.
class OrdersController
    extends AutoDisposeFamilyAsyncNotifier<OrdersState, String?> {
  OrderFilter _filter = OrderFilter.all;
  String? _pinnedStatus;
  String _search = '';
  int _generation = 0;
  bool _loadingMore = false;
  bool _disposed = false;

  bool get _alive => !_disposed;

  String? get _apiStatus => _pinnedStatus ?? _filter.apiStatus;

  @override
  Future<OrdersState> build(String? initialStatus) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _filter = OrderFilter.fromQuery(initialStatus);
    // The account screen's "still on the way" and "returned" shortcuts are narrower than a chip.
    _pinnedStatus = switch (initialStatus) {
      'open' => 'open',
      'refunded' => 'refunded',
      _ => null,
    };
    _search = '';
    final generation = ++_generation;
    return _load(page: 1, generation: generation);
  }

  Future<String?> setFilter(OrderFilter next) async {
    if (next == _filter && _pinnedStatus == null && state.hasValue) return null;
    _filter = next;
    _pinnedStatus = null;
    return _replace();
  }

  Future<String?> applySearch(String value) async {
    final next = value.trim();
    if (next == _search && state.hasValue) return null;
    _search = next;
    return _replace();
  }

  Future<void> refresh() async {
    ref.invalidate(orderSummaryProvider);
    final failure = await _replace();
    if (failure != null) throw AppFailure(failure);
  }

  Future<String?> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore || _loadingMore) {
      return null;
    }
    _loadingMore = true;
    final generation = _generation;
    state = AsyncData(current.copyWith(loadingMore: true));
    final result = await ref
        .read(ordersRepositoryProvider)
        .list(status: _apiStatus, search: _search, page: current.page + 1);
    _loadingMore = false;
    if (!_alive || generation != _generation) return null;
    return result.fold(
      (failure) {
        final latest = state.valueOrNull ?? current;
        state = AsyncData(latest.copyWith(loadingMore: false));
        return failure.message;
      },
      (page) {
        final latest = state.valueOrNull ?? current;
        state = AsyncData(
          latest.copyWith(
            orders: [...latest.orders, ...page.results],
            page: current.page + 1,
            hasMore: page.hasMore,
            resultCount: page.count,
            loadingMore: false,
          ),
        );
        return null;
      },
    );
  }

  /// Returns an error message, or null when the order was cancelled.
  Future<String?> cancel(String id) async {
    final result = await ref.read(ordersRepositoryProvider).cancel(id);
    if (!_alive) return null;
    return result.fold((failure) => failure.message, (updated) {
      final current = state.valueOrNull;
      if (current == null) return null;
      final stays = _pinnedStatus == null
          ? _keeps(current.filter, updated)
          : _matchesPin(updated);
      state = AsyncData(
        current.copyWith(
          orders: [
            for (final order in current.orders)
              if (order.id != id) order else if (stays) updated,
          ],
        ),
      );
      ref.invalidate(orderSummaryProvider);
      return null;
    });
  }

  Future<OrdersState> _load({
    required int page,
    required int generation,
  }) async {
    final result = await ref
        .read(ordersRepositoryProvider)
        .list(status: _apiStatus, search: _search, page: page);
    if (!_alive || generation != _generation) {
      final current = state.valueOrNull;
      if (current != null) return current;
    }
    return result.fold(
      (failure) => throw failure,
      (paginated) => _from(paginated, pageNumber: page),
    );
  }

  Future<String?> _replace() async {
    final generation = ++_generation;
    final previous = state;
    state = const AsyncLoading<OrdersState>().copyWithPrevious(previous);
    final result = await ref
        .read(ordersRepositoryProvider)
        .list(status: _apiStatus, search: _search);
    if (!_alive || generation != _generation) return null;
    return result.fold(
      (failure) {
        state = previous.hasValue
            ? previous
            : AsyncError<OrdersState>(failure, StackTrace.current);
        return failure.message;
      },
      (paginated) {
        state = AsyncData(_from(paginated, pageNumber: 1));
        return null;
      },
    );
  }

  OrdersState _from(
    Paginated<CustomerOrder> paginated, {
    required int pageNumber,
  }) => OrdersState(
    orders: paginated.results,
    filter: _filter,
    search: _search,
    page: pageNumber,
    hasMore: paginated.hasMore,
    resultCount: paginated.count,
  );

  bool _keeps(OrderFilter filter, CustomerOrder order) => switch (filter) {
    OrderFilter.all => true,
    OrderFilter.processing => order.stage == OrderStage.processing,
    OrderFilter.shipped => order.stage == OrderStage.shipped,
    OrderFilter.delivered => order.stage == OrderStage.delivered,
    OrderFilter.cancelled => order.stage == OrderStage.cancelled,
  };

  bool _matchesPin(CustomerOrder order) => switch (_pinnedStatus) {
    'open' =>
      order.stage == OrderStage.processing || order.stage == OrderStage.shipped,
    'refunded' => order.status == 'refunded',
    _ => true,
  };
}
