import 'package:flutter/material.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';

/// Light surfaces follow the search mock. Dark mode uses the theme color scheme.
class SearchPalette {
  const SearchPalette({
    required this.page,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.field,
    required this.fieldText,
    required this.highlight,
    required this.mic,
    required this.soft,
    required this.softText,
    required this.iconWell,
    required this.iconInk,
  });

  static const accent = Color(0xFFFF7A16);
  static const star = Color(0xFFF2AC1E);

  final Color page;
  final Color card;
  final Color ink;
  final Color muted;
  final Color line;
  final Color field;
  final Color fieldText;
  final Color highlight;
  final Color mic;
  final Color soft;
  final Color softText;
  final Color iconWell;
  final Color iconInk;

  factory SearchPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.light) {
      return const SearchPalette(
        page: Color(0xFFEEF5FF),
        card: Colors.white,
        ink: Color(0xFF101848),
        muted: Color(0xFF8C93A7),
        line: Color(0xFFE4E9F2),
        field: Colors.white,
        fieldText: Color(0xFF101848),
        highlight: Color(0xFF1B3FDB),
        mic: Color(0xFF2450E6),
        soft: Color(0xFFFFF1E6),
        softText: Color(0xFFE86A00),
        iconWell: Color(0xFFE7F0FF),
        iconInk: Color(0xFF2450E6),
      );
    }
    final scheme = theme.colorScheme;
    return SearchPalette(
      page: scheme.surfaceContainerLow,
      card: scheme.surface,
      ink: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      line: scheme.outline,
      field: scheme.surfaceContainerHigh,
      fieldText: scheme.onSurface,
      highlight: scheme.primary,
      mic: scheme.primary,
      soft: scheme.secondaryContainer,
      softText: scheme.onSecondaryContainer,
      iconWell: scheme.primaryContainer,
      iconInk: scheme.onPrimaryContainer,
    );
  }

  TextStyle get title => AppTypography.titleMedium.copyWith(
    color: ink,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );

  TextStyle get action =>
      AppTypography.label.copyWith(color: accent, fontSize: 13, fontWeight: FontWeight.w700);
}
