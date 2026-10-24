import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/features/search/view/search_palette.dart';

/// Recent terms as removable chips, with Clear all.
class RecentSearchChips extends StatelessWidget {
  const RecentSearchChips({
    super.key,
    required this.terms,
    required this.onSelected,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> terms;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) return const SizedBox.shrink();
    final colors = SearchPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Recent searches', style: colors.title)),
            Pressable(
              semanticLabel: 'Clear all recent searches',
              onTap: onClear,
              child: SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Clear all', style: colors.action),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final term in terms)
              _RecentChip(term: term, onSelected: () => onSelected(term), onRemove: () => onRemove(term)),
          ],
        ),
      ],
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.term, required this.onSelected, required this.onRemove});

  final String term;
  final VoidCallback onSelected;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pressable(
            semanticLabel: term,
            onTap: onSelected,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 2, 0),
              child: SizedBox(
                height: 40,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsRegular.clock, size: 14, color: colors.muted),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        term,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Pressable(
            semanticLabel: 'Remove $term from recent searches',
            onTap: onRemove,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(PhosphorIconsRegular.x, size: 14, color: colors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
