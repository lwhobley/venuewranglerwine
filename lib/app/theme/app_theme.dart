import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: dark ? AppColors.ivory : AppColors.ink,
      onPrimary: dark ? AppColors.ink : AppColors.ivory,
      secondary: AppColors.brass,
      onSecondary: AppColors.ink,
      error: AppColors.burgundy,
      onError: AppColors.ivory,
      surface: dark ? AppColors.graphite : const Color(0xFFFFFDF8),
      onSurface: dark ? AppColors.ivory : AppColors.ink,
    );
    final base = ThemeData(brightness: brightness, useMaterial3: true, colorScheme: scheme);
    final text = GoogleFonts.sourceSans3TextTheme(base.textTheme).copyWith(
      headlineMedium: GoogleFonts.fraunces(
        textStyle: base.textTheme.headlineMedium,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleLarge: GoogleFonts.fraunces(
        textStyle: base.textTheme.titleLarge,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: dark ? AppColors.ink : const Color(0xFFF3EEE4),
      textTheme: text,
      dividerColor: dark ? AppColors.lineDark : AppColors.line,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.graphiteRaised : AppColors.ivory,
        labelStyle: TextStyle(color: dark ? AppColors.ivoryDeep : AppColors.brassDeep),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dark ? AppColors.lineDark : AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dark ? AppColors.lineDark : AppColors.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: dark ? AppColors.graphite : AppColors.ivory,
        selectedIconTheme: IconThemeData(color: dark ? AppColors.brass : AppColors.brassDeep),
        indicatorColor: dark ? AppColors.graphiteRaised : AppColors.ivoryDeep,
      ),
    );
  }
}
