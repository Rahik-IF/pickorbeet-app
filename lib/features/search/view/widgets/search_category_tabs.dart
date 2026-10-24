import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/features/search/view/search_palette.dart';
import 'package:pickorbeet/features/search/viewmodel/search_controller.dart';

/// All, Products, Categories, and Brands. The query stays when the tab changes.
class SearchCategoryTabs extends StatelessWidget {
  const SearchCategoryTabs({super.key, required this.selected, required this.onSelected});

  final SearchTab selected;
  final ValueChanged<SearchTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            for (var i = 0; i < SearchTab.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _TabChip(
                  label: _label(SearchTab.values[i]),
                  icon: _icon(SearchTab.values[i], SearchTab.values[i] == selected),
                  selected: SearchTab.values[i] == selected,
                  colors: colors,
                  onTap: () => onSelected(SearchTab.values[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _label(SearchTab tab) => switch (tab) {
    SearchTab.all => 'All',
    SearchTab.products => 'Products',
    SearchTab.categories => 'Categories',
    SearchTab.brands => 'Brands',
  };

  IconData _icon(SearchTab tab, bool active) => switch (tab) {
    SearchTab.all => active ? PhosphorIconsFill.squaresFour : PhosphorIconsRegular.squaresFour,
    SearchTab.products => active ? PhosphorIconsFill.package : PhosphorIconsRegular.package,
    SearchTab.categories => active ? PhosphorIconsFill.folder : PhosphorIconsRegular.folder,
    SearchTab.brands => active ? PhosphorIconsFill.tag : PhosphorIconsRegular.tag,
  };
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final SearchPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : colors.ink;
    return Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? SearchPalette.accent : colors.card,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: colors.line),
        ),
        child: SizedBox(
          height: 40,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: foreground),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
