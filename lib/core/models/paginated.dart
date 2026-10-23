import 'package:flutter/foundation.dart';

import 'package:pickorbeet/core/network/json.dart';

/// A DRF page-number page: `count`, `next`, `previous`, `results`.
@immutable
class Paginated<T> {
  const Paginated({required this.count, required this.results, this.next, this.previous});

  const Paginated.empty()
      : count = 0,
        results = const [],
        next = null,
        previous = null;

  final int count;
  final List<T> results;
  final String? next;
  final String? previous;

  bool get hasMore => next != null;

  /// The page number in `next`, for requesting it through the same repository method.
  int? get nextPage {
    final link = next;
    if (link == null) return null;
    return int.tryParse(Uri.tryParse(link)?.queryParameters['page'] ?? '');
  }

  /// Parses a paginated body. A bare list (for example `GET /products/?ids=`) becomes one page.
  factory Paginated.fromBody(Object? body, T Function(Json json) parse) {
    if (body is List) {
      final items = [for (final item in asJsonList(body)) parse(item)];
      return Paginated(count: items.length, results: items);
    }
    final map = asJson(body);
    final items = map.listOf('results', parse);
    return Paginated(
      count: map.integer('count', items.length),
      results: items,
      next: map.strOrNull('next'),
      previous: map.strOrNull('previous'),
    );
  }

  Paginated<T> append(Paginated<T> page) =>
      Paginated(count: page.count, results: [...results, ...page.results], next: page.next, previous: previous);
}
