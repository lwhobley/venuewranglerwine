import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.burgundy,
      brightness: brightness,
      primary: dark ? const Color(0xFFE8B7C0) : const Color(0xFF71384B),
      onPrimary: dark ? AppColors.ink : Colors.white,
      secondary: dark ? AppColors.brass : AppColors.brassDeep,
      surface: dark ? AppColors.graphite : const Color(0xFFFFFCF6),
      onSurface: dark ? AppColors.ivory : AppColors.ink,
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final sans = base.textTheme.apply(fontFamily: 'SourceSans3');
    TextStyle editorial(TextStyle? style) =>
        (style ?? const TextStyle()).copyWith(
          fontFamily: 'Fraunces',
          fontWeight: FontWeight.w500,
          letterSpacing: -0.8,
          color: scheme.onSurface,
        );
    final text = sans.copyWith(
      displaySmall: editorial(sans.displaySmall),
      headlineLarge: editorial(sans.headlineLarge),
      headlineMedium: editorial(sans.headlineMedium),
      headlineSmall: editorial(sans.headlineSmall),
      titleLarge: editorial(sans.titleLarge),
      bodyLarge: sans.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: sans.bodyMedium?.copyWith(height: 1.45),
      labelLarge: sans.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
    final line = dark ? AppColors.lineDark : AppColors.line;
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    return base.copyWith(
      scaffoldBackgroundColor: dark ? AppColors.ink : const Color(0xFFF5F1E9),
      textTheme: text,
      dividerColor: line,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: dark ? 0 : 1,
        shadowColor: AppColors.brassDeep.withValues(alpha: 0.12),
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: line.withValues(alpha: 0.55)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.graphiteRaised : const Color(0xFFFBF8F2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(48, 50),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              elevation: 2,
              shadowColor: scheme.primary.withValues(alpha: 0.25),
              shape: rounded,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.pressed)
                    ? AppColors.brass.withValues(alpha: 0.24)
                    : null,
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          side: BorderSide(color: line),
          shape: rounded,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: rounded,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: line),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconColor: scheme.secondary,
      ),
      dialogTheme: DialogThemeData(
        shape: rounded,
        backgroundColor: scheme.surface,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: dark ? 0.2 : 0.1),
        labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.1),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: text.labelLarge?.copyWith(
          color: scheme.primary,
        ),
        unselectedLabelTextStyle: text.labelLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
