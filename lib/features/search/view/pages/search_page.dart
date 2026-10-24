import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/header_background.dart';
import 'package:pickorbeet/core/widgets/skeleton.dart';
import 'package:pickorbeet/core/widgets/state_views.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/repositories/catalog_repository.dart';
import 'package:pickorbeet/features/catalog/viewmodel/catalog_providers.dart';
import 'package:pickorbeet/features/search/view/search_palette.dart';
import 'package:pickorbeet/features/search/view/search_voice.dart';
import 'package:pickorbeet/features/search/view/widgets/popular_searches.dart';
import 'package:pickorbeet/features/search/view/widgets/recent_search_chips.dart';
import 'package:pickorbeet/features/search/view/widgets/search_category_tabs.dart';
import 'package:pickorbeet/features/search/view/widgets/search_product_tile.dart';
import 'package:pickorbeet/features/search/view/widgets/smart_search_bar.dart';
import 'package:pickorbeet/features/search/viewmodel/recent_searches.dart';
import 'package:pickorbeet/features/search/viewmodel/search_controller.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Discovery search pushed over the shop. Leaving it does not touch the cart.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _voice = SearchVoice();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFieldFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFieldFocus);
    _voice.dispose();
    _focus.dispose();
    _field.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onFieldFocus() {
    if (mounted) setState(() {});
  }

  /// Gboard draws a floating toolbar under the field when a hardware keyboard
  /// is attached. That strip is not part of the IME inset, so it covers the
  /// tabs. A docked keyboard reports a tall inset and stays at the bottom.
  double _tabClearance(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    if (!_focus.hasFocus || keyboard >= 120) return 12;
    return 84;
  }

  void _onChanged(String value) {
    if (_voice.listening) {
      unawaited(_voice.stop());
      if (mounted) setState(() {});
    }
    ref.read(searchControllerProvider.notifier).onQueryChanged(value);
  }

  void _onSubmitted(String value) => ref.read(searchControllerProvider.notifier).submit(value);

  void _clear() {
    unawaited(_voice.stop());
    _field.clear();
    ref.read(searchControllerProvider.notifier).clearQuery();
    if (mounted) setState(() {});
  }

  void _apply(String term, {SearchTab? tab}) {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    unawaited(_voice.stop());
    _field.value = TextEditingValue(text: trimmed, selection: TextSelection.collapsed(offset: trimmed.length));
    final search = ref.read(searchControllerProvider.notifier);
    if (tab != null) search.selectTab(tab);
    search.submit(trimmed);
    if (mounted) setState(() {});
  }

  void _selectTab(SearchTab tab) {
    ref.read(searchControllerProvider.notifier).selectTab(tab);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _viewAll() {
    final snapshot = ref.read(searchControllerProvider);
    final query = snapshot.query.trim();
    if (snapshot.discovery || query.isEmpty) {
      context.push(Routes.productList(title: 'Products'));
      return;
    }
    context.push(Routes.productList(title: query, query: query));
  }

  Future<void> _toggleVoice() async {
    await _voice.toggle(
      onTranscript: (words) {
        if (!mounted) return;
        _field.value = TextEditingValue(text: words, selection: TextSelection.collapsed(offset: words.length));
        ref.read(searchControllerProvider.notifier).onQueryChanged(words);
      },
      onUpdate: () {
        if (mounted) setState(() {});
      },
      onUnavailable: (message) {
        if (!mounted) return;
        setState(() {});
        showToast(context, message, kind: ToastKind.error);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SearchPalette.of(context);
    final snapshot = ref.watch(searchControllerProvider);
    final recent = ref.watch(recentSearchesProvider);
    final settings = ref.watch(storeSettingsProvider);
    final categories = ref.watch(categoriesProvider);
    final top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnDark,
      child: Scaffold(
        backgroundColor: colors.page,
        body: Column(
          children: [
            HeaderBackground(
              child: Padding(
                padding: EdgeInsets.fromLTRB(4, top + 6, 12, 14),
                child: SmartSearchBar(
                  controller: _field,
                  focusNode: _focus,
                  listening: _voice.listening,
                  onChanged: _onChanged,
                  onSubmitted: _onSubmitted,
                  onClear: _clear,
                  onVoice: _voice.available ? () => unawaited(_toggleVoice()) : null,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: _tabClearance(context),
            ),
            SearchCategoryTabs(selected: snapshot.tab, onSelected: _selectTab),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: _scroll,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
                children: _sections(snapshot, recent, settings, categories),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sections(
    SearchSnapshot snapshot,
    List<String> recent,
    AsyncValue<StoreSettings> settings,
    AsyncValue<List<CategoryModel>> categories,
  ) {
    return switch (snapshot.tab) {
      SearchTab.all => _all(snapshot, recent, settings),
      SearchTab.products => [_results(snapshot, settings)],
      SearchTab.categories => [_categories(categories, snapshot.query)],
      SearchTab.brands => [_brands(snapshot)],
    };
  }

  List<Widget> _all(SearchSnapshot snapshot, List<String> recent, AsyncValue<StoreSettings> settings) {
    final noMatch = _noMatch(snapshot);
    return [
      if (recent.isNotEmpty) ...[
        RecentSearchChips(
          terms: recent,
          onSelected: _apply,
          onRemove: (term) => ref.read(recentSearchesProvider.notifier).remove(term),
          onClear: () => ref.read(recentSearchesProvider.notifier).clear(),
        ),
        const SizedBox(height: 18),
      ],
      if (!noMatch) ..._popular(settings),
      _results(snapshot, settings),
      const SizedBox(height: 8),
      const _SearchHint(),
    ];
  }

  List<Widget> _popular(AsyncValue<StoreSettings> settings) {
    if (settings.isLoading) return const [_ChipSkeleton(), SizedBox(height: 18)];
    final visible = settings.valueOrNull?.popularSearches ?? const <String>[];
    if (visible.isEmpty) return const [];
    return [
      PopularSearches(terms: visible, onSelected: _apply),
      const SizedBox(height: 18),
    ];
  }

  Widget _results(SearchSnapshot snapshot, AsyncValue<StoreSettings> settings) {
    if (snapshot.failure != null && !snapshot.pending) {
      return ErrorState(
        failure: snapshot.failure!,
        onRetry: () => ref.read(searchControllerProvider.notifier).retry(),
        compact: true,
      );
    }
    if ((snapshot.loading || snapshot.pending) && snapshot.products.isEmpty) {
      return const _ProductSkeleton();
    }
    if (snapshot.products.isEmpty) {
      if (snapshot.discovery || snapshot.loading || snapshot.pending) return const SizedBox.shrink();
      final alternatives = _alternatives(settings.valueOrNull?.popularSearches ?? const [], snapshot.query);
      return Column(
        children: [
          const EmptyState(
            icon: PhosphorIconsRegular.magnifyingGlass,
            title: 'No matching products',
            message: 'Try another name, brand, or model.',
            compact: true,
          ),
          if (alternatives.isNotEmpty) ...[
            const SizedBox(height: 8),
            PopularSearches(terms: alternatives, onSelected: _apply),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Suggested products', action: 'View all', label: 'View all products', onAction: _viewAll),
        const SizedBox(height: 10),
        for (final product in snapshot.products)
          SearchProductTile(product: product, query: snapshot.discovery ? '' : snapshot.query),
      ],
    );
  }

  Widget _categories(AsyncValue<List<CategoryModel>> categories, String query) {
    return categories.when(
      loading: () => const _ProductSkeleton(),
      error: (error, _) => ErrorState(
        failure: error,
        onRetry: () => ref.invalidate(categoriesProvider),
        compact: true,
      ),
      data: (items) {
        final matches = matchingCategories(items, query);
        if (matches.isEmpty) {
          return const EmptyState(
            icon: PhosphorIconsRegular.folder,
            title: 'No matching categories',
            message: 'Try another category name.',
            compact: true,
          );
        }
        return Column(
          children: [
            for (final category in matches)
              _GroupRow(
                icon: PhosphorIconsRegular.folder,
                title: category.name,
                subtitle: Formatters.items(category.productCount),
                onTap: () => context.push(Routes.productList(title: category.name, categorySlug: category.slug)),
              ),
          ],
        );
      },
    );
  }

  Widget _brands(SearchSnapshot snapshot) {
    if (snapshot.failure != null && !snapshot.pending) {
      return ErrorState(
        failure: snapshot.failure!,
        onRetry: () => ref.read(searchControllerProvider.notifier).retry(),
        compact: true,
      );
    }
    if ((snapshot.loading || snapshot.pending) && snapshot.products.isEmpty) return const _ProductSkeleton();
    final labels = brandLabels(snapshot.products);
    if (labels.isEmpty) {
      return const EmptyState(
        icon: PhosphorIconsRegular.tag,
        title: 'No matching brands',
        message: 'Try another brand name.',
        compact: true,
      );
    }
    return Column(
      children: [
        for (final label in labels)
          _GroupRow(
            icon: PhosphorIconsRegular.tag,
            title: label,
            onTap: () => _apply(label, tab: SearchTab.products),
          ),
      ],
    );
  }

  bool _noMatch(SearchSnapshot snapshot) =>
      snapshot.failure == null &&
      !snapshot.loading &&
      !snapshot.pending &&
      !snapshot.discovery &&
      snapshot.products.isEmpty;
}

List<String> _alternatives(List<String> terms, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return terms;
  return [for (final term in terms) if (term.toLowerCase() != needle) term];
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action, required this.label, required this.onAction});

  final String title;
  final String action;
  final String label;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPalette.of(context);
    return Row(
      children: [
        Expanded(child: Text(title, style: colors.title)),
        Pressable(
          semanticLabel: label,
          onTap: onAction,
          child: SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(action, style: colors.action),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.icon, required this.title, required this.onTap, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.line),
        ),
        child: Pressable(
          semanticLabel: title,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: colors.iconWell, shape: BoxShape.circle),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(icon, size: 18, color: colors.iconInk),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(color: colors.ink, fontSize: 14),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge.copyWith(color: colors.muted, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Icon(PhosphorIconsRegular.caretRight, size: 16, color: colors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    final colors = SearchPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIconsRegular.magnifyingGlass, size: 14, color: colors.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Search by product name, brand, or model.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(color: colors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipSkeleton extends StatelessWidget {
  const _ChipSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppSkeletonTheme(
      child: Skeletonizer(
        child: Row(
          children: [
            SkeletonBox(width: 108, height: 36, radius: 18),
            SizedBox(width: 8),
            SkeletonBox(width: 92, height: 36, radius: 18),
            SizedBox(width: 8),
            SkeletonBox(width: 84, height: 36, radius: 18),
          ],
        ),
      ),
    );
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppSkeletonTheme(
      child: Skeletonizer(
        child: Column(
          children: [
            for (var i = 0; i < 3; i++) ...[
              const SkeletonBox(height: 92, radius: 16),
              if (i < 2) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
