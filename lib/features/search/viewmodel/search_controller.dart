import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/models/paginated.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/repositories/catalog_repository.dart';
import 'package:pickorbeet/features/search/viewmodel/recent_searches.dart';

enum SearchTab { all, products, categories, brands }

/// How many product rows the search screen shows before View all.
const searchSuggestionLimit = 8;

/// Pause after the last keystroke before a catalog request.
const searchDebounce = Duration(milliseconds: 300);

/// Categories whose names contain [query]. An empty query keeps the full list.
List<CategoryModel> matchingCategories(List<CategoryModel> categories, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return categories;
  return [
    for (final category in categories)
      if (category.name.toLowerCase().contains(needle)) category,
  ];
}

/// The catalog has no brand field. The label is the first word of the product name.
String brandLabel(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(RegExp(r'\s+')).first;
}

/// Distinct brand labels from [products], in first-seen order.
List<String> brandLabels(Iterable<ProductSummary> products) {
  final seen = <String>{};
  final labels = <String>[];
  for (final product in products) {
    final label = brandLabel(product.name);
    if (label.isEmpty) continue;
    if (seen.add(label.toLowerCase())) labels.add(label);
  }
  return labels;
}

class SearchSnapshot {
  const SearchSnapshot({
    this.query = '',
    this.tab = SearchTab.all,
    this.products = const [],
    this.loading = false,
    this.pending = false,
    this.failure,
    this.discovery = true,
  });

  final String query;
  final SearchTab tab;
  final List<ProductSummary> products;
  final bool loading;

  /// A keystroke is waiting out the debounce. Previous rows stay on screen.
  final bool pending;
  final AppFailure? failure;

  /// True when the rows are featured products for an empty query.
  final bool discovery;

  SearchSnapshot copyWith({
    String? query,
    SearchTab? tab,
    List<ProductSummary>? products,
    bool? loading,
    bool? pending,
    AppFailure? failure,
    bool clearFailure = false,
    bool? discovery,
  }) {
    return SearchSnapshot(
      query: query ?? this.query,
      tab: tab ?? this.tab,
      products: products ?? this.products,
      loading: loading ?? this.loading,
      pending: pending ?? this.pending,
      failure: clearFailure ? failure : failure ?? this.failure,
      discovery: discovery ?? this.discovery,
    );
  }
}

/// Debounced catalog search. A generation counter drops responses for an older query.
class SearchController extends AutoDisposeNotifier<SearchSnapshot> {
  Timer? _debounce;
  var _generation = 0;
  var _alive = true;

  @override
  SearchSnapshot build() {
    _alive = true;
    ref.onDispose(() {
      _alive = false;
      _debounce?.cancel();
      _generation++;
    });
    unawaited(
      Future<void>.delayed(Duration.zero, () {
        if (!_alive) return;
        if (state.query.isNotEmpty || state.pending || !state.discovery) return;
        unawaited(_fetch(query: '', remember: false, discovery: true));
      }),
    );
    return const SearchSnapshot(loading: true);
  }

  void onQueryChanged(String raw) {
    final query = raw.trim();
    if (query.isEmpty) {
      _debounce?.cancel();
      if (state.discovery && state.query.isEmpty && state.failure == null && !state.pending) return;
      unawaited(_fetch(query: '', remember: false, discovery: true));
      return;
    }
    if (query == state.query) {
      if (state.pending) return;
      if (!state.discovery && state.failure == null) return;
    }
    _debounce?.cancel();
    _generation++;
    _emit(state.copyWith(query: query, pending: true, clearFailure: true));
    _debounce = Timer(searchDebounce, () {
      unawaited(_fetch(query: query, remember: true, discovery: false));
    });
  }

  void submit(String raw) {
    final query = raw.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      unawaited(_fetch(query: '', remember: false, discovery: true));
      return;
    }
    unawaited(_fetch(query: query, remember: true, discovery: false));
  }

  /// Empties the query and returns to discovery. Recent searches stay.
  void clearQuery() {
    _debounce?.cancel();
    unawaited(_fetch(query: '', remember: false, discovery: true));
  }

  void retry() {
    final query = state.query.trim();
    if (query.isEmpty || state.discovery) {
      unawaited(_fetch(query: '', remember: false, discovery: true));
      return;
    }
    unawaited(_fetch(query: query, remember: false, discovery: false));
  }

  void selectTab(SearchTab tab) {
    if (tab == state.tab) return;
    _emit(state.copyWith(tab: tab));
  }

  Future<void> _fetch({required String query, required bool remember, required bool discovery}) async {
    if (!_alive) return;
    final generation = ++_generation;
    _debounce?.cancel();
    final keepProducts = query == state.query && discovery == state.discovery && state.failure == null;
    _emit(
      state.copyWith(
        query: query,
        loading: true,
        pending: false,
        clearFailure: true,
        discovery: discovery,
        products: keepProducts ? state.products : const [],
      ),
    );
    if (remember && query.isNotEmpty) {
      ref.read(recentSearchesProvider.notifier).remember(query);
    }
    final repo = ref.read(catalogRepositoryProvider);
    final Either<AppFailure, Paginated<ProductSummary>> result;
    try {
      result = discovery ? await _discovery(repo) : await repo.products(ProductQuery(search: query));
    } on Object catch (error) {
      if (!_alive || generation != _generation) return;
      _emit(
        state.copyWith(
          loading: false,
          pending: false,
          failure: AppFailure.fromException(error),
          products: const [],
        ),
      );
      return;
    }
    if (!_alive || generation != _generation) return;
    switch (result) {
      case Left(value: final failure):
        _emit(state.copyWith(loading: false, pending: false, failure: failure, products: const []));
      case Right(value: final page):
        _emit(
          state.copyWith(
            loading: false,
            pending: false,
            clearFailure: true,
            products: page.results.take(searchSuggestionLimit).toList(),
          ),
        );
    }
  }

  Future<Either<AppFailure, Paginated<ProductSummary>>> _discovery(CatalogRepository repo) async {
    final featured = await repo.products(const ProductQuery(featured: true));
    switch (featured) {
      case Left():
        return featured;
      case Right(value: final page) when page.results.isNotEmpty:
        return featured;
      case Right():
        return repo.products(const ProductQuery());
    }
  }

  void _emit(SearchSnapshot next) {
    if (next.query == state.query &&
        next.tab == state.tab &&
        next.loading == state.loading &&
        next.pending == state.pending &&
        next.discovery == state.discovery &&
        next.failure == state.failure &&
        _sameProducts(next.products, state.products)) {
      return;
    }
    state = next;
  }

  bool _sameProducts(List<ProductSummary> a, List<ProductSummary> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}

final searchControllerProvider = AutoDisposeNotifierProvider<SearchController, SearchSnapshot>(SearchController.new);
