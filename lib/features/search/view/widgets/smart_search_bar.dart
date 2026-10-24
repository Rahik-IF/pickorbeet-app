import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';
import 'package:pickorbeet/features/search/view/search_palette.dart';

/// Back, the focused query field, clear, and voice. Sits on the navy header.
class SmartSearchBar extends StatelessWidget {
  const SmartSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    this.focusNode,
    this.onVoice,
    this.listening = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback? onVoice;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    final colors = SearchPalette.of(context);
    return Row(
      children: [
        const HeaderBackButton(),
        const SizedBox(width: 2),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(color: colors.field, borderRadius: BorderRadius.circular(24)),
            child: SizedBox(
              height: 48,
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final hasText = controller.text.isNotEmpty;
                  return Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(PhosphorIconsRegular.magnifyingGlass, size: 18, color: colors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          cursorColor: SearchPalette.accent,
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.fieldText,
                          ),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: 'Search products, brands...',
                            hintStyle: AppTypography.bodyLarge.copyWith(fontSize: 14, color: colors.muted),
                          ),
                          onChanged: onChanged,
                          onSubmitted: onSubmitted,
                        ),
                      ),
                      if (hasText)
                        Pressable(
                          semanticLabel: 'Clear search',
                          onTap: onClear,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(PhosphorIconsRegular.x, size: 16, color: colors.muted),
                          ),
                        ),
                      if (onVoice != null)
                        Pressable(
                          semanticLabel: listening ? 'Stop voice search' : 'Voice search',
                          onTap: onVoice,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: listening ? SearchPalette.accent : colors.mic,
                                  shape: BoxShape.circle,
                                ),
                                child: const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Icon(PhosphorIconsFill.microphone, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 8),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
