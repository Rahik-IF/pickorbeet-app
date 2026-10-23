import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_spacing.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';

abstract final class AppTheme {
  /// Light status bar icons over the blue header, drawn edge to edge.
  static const overlayOnDark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  /// Dark status bar icons for light screens such as sign-in.
  static const overlayOnLight = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppPallete.primary).copyWith(
      primary: AppPallete.primary,
      onPrimary: AppPallete.onDark,
      primaryContainer: AppPallete.primarySoft,
      onPrimaryContainer: AppPallete.primaryText,
      secondary: AppPallete.accent,
      onSecondary: AppPallete.onDark,
      secondaryContainer: AppPallete.accentSoft,
      onSecondaryContainer: AppPallete.accentDeep,
      surface: AppPallete.surface,
      onSurface: AppPallete.ink,
      onSurfaceVariant: AppPallete.textSecondary,
      surfaceContainerLowest: AppPallete.surface,
      surfaceContainerLow: AppPallete.surfaceMuted,
      surfaceContainer: AppPallete.surfaceMuted,
      surfaceContainerHigh: AppPallete.searchFill,
      error: AppPallete.danger,
      onError: AppPallete.onDark,
      outline: AppPallete.border,
      outlineVariant: AppPallete.divider,
      shadow: AppPallete.shadow,
      scrim: AppPallete.ink,
    );
    final text = AppTypography.textTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPallete.background,
      canvasColor: AppPallete.background,
      fontFamily: AppTypography.family,
      fontFamilyFallback: AppTypography.fallback,
      textTheme: text,
      primaryTextTheme: text,
      splashFactory: InkRipple.splashFactory,
      highlightColor: AppPallete.primary.withValues(alpha: 0.04),
      splashColor: AppPallete.primary.withValues(alpha: 0.08),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
            fillColor: AppPallete.background,
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: overlayOnDark,
      ),
      iconTheme: const IconThemeData(color: AppPallete.ink, size: 22),
      dividerTheme: const DividerThemeData(color: AppPallete.divider, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppPallete.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppPallete.surface,
        modalBarrierColor: AppPallete.ink.withValues(alpha: 0.42),
        showDragHandle: true,
        dragHandleColor: AppPallete.border,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPallete.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
        titleTextStyle: AppTypography.titleMedium.copyWith(fontSize: 16),
        contentTextStyle: AppTypography.bodyLarge.copyWith(color: AppPallete.textSecondary),
        barrierColor: AppPallete.ink.withValues(alpha: 0.42),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPallete.ink,
        contentTextStyle: AppTypography.bodyLarge.copyWith(color: AppPallete.onDark, fontWeight: FontWeight.w500),
        actionTextColor: AppPallete.accent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.xlBorder),
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(color: AppPallete.ink, borderRadius: AppRadii.lgBorder),
        textStyle: AppTypography.bodyMedium.copyWith(color: AppPallete.onDark),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        preferBelow: false,
        waitDuration: Duration.zero,
        showDuration: const Duration(seconds: 3),
        triggerMode: TooltipTriggerMode.tap,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
        side: const BorderSide(color: AppPallete.border, width: 1.6),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppPallete.primary : AppPallete.surface,
        ),
        checkColor: const WidgetStatePropertyAll(AppPallete.onDark),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppPallete.primary,
        linearTrackColor: AppPallete.primarySoft,
        circularTrackColor: Colors.transparent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppPallete.primary,
        selectionColor: AppPallete.primary.withValues(alpha: 0.18),
        selectionHandleColor: AppPallete.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPallete.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: AppTypography.bodyLarge.copyWith(color: AppPallete.textHint, fontSize: 13),
        labelStyle: AppTypography.bodyLarge.copyWith(color: AppPallete.textSecondary, fontSize: 13),
        floatingLabelStyle: AppTypography.label.copyWith(color: AppPallete.primary, fontSize: 12),
        errorStyle: AppTypography.bodySmall.copyWith(color: AppPallete.danger),
        prefixIconColor: AppPallete.textTertiary,
        suffixIconColor: AppPallete.textTertiary,
        border: _outline(AppPallete.border),
        enabledBorder: _outline(AppPallete.border),
        focusedBorder: _outline(AppPallete.primary, width: 1.4),
        errorBorder: _outline(AppPallete.danger),
        focusedErrorBorder: _outline(AppPallete.danger, width: 1.4),
        disabledBorder: _outline(AppPallete.divider),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPallete.surface,
        selectedColor: AppPallete.primarySoft,
        side: const BorderSide(color: AppPallete.border),
        shape: const StadiumBorder(),
        labelStyle: AppTypography.label.copyWith(color: AppPallete.inkSoft),
        secondaryLabelStyle: AppTypography.label.copyWith(color: AppPallete.primaryText),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        showCheckmark: false,
      ),
    );
  }

  static OutlineInputBorder _outline(Color color, {double width = 1}) => OutlineInputBorder(
        borderRadius: AppRadii.xlBorder,
        borderSide: BorderSide(color: color, width: width),
      );
}
