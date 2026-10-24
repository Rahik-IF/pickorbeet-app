import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';

/// Recent search terms, newest first. Stored on the device, like the wishlist.
class RecentSearches extends Notifier<List<String>> {
  static const storageKey = 'search_recent';
  static const capacity = 10;

  @override
  List<String> build() => ref.watch(sharedPreferencesProvider).getStringList(storageKey) ?? const [];

  /// Remembers [term] when a search actually runs. Case-insensitive duplicates move to the front.
  void remember(String term) {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    final lower = trimmed.toLowerCase();
    final next = <String>[
      trimmed,
      for (final existing in state)
        if (existing.toLowerCase() != lower) existing,
    ].take(capacity).toList();
    if (_same(next, state)) return;
    _save(next);
  }

  void remove(String term) {
    final lower = term.trim().toLowerCase();
    final next = [for (final existing in state) if (existing.toLowerCase() != lower) existing];
    if (next.length == state.length) return;
    _save(next);
  }

  void clear() {
    if (state.isEmpty) return;
    _save(const []);
  }

  void _save(List<String> terms) {
    state = terms;
    unawaited(ref.read(sharedPreferencesProvider).setStringList(storageKey, terms));
  }

  bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);
