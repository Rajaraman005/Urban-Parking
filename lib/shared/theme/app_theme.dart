import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0B0B0C),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFC9A76A),
    onSecondary: Color(0xFF0B0B0C),
    error: Color(0xFFB42318),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0B0B0C),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF0B0B0C),
    secondary: Color(0xFFC9A76A),
    onSecondary: Color(0xFF0B0B0C),
    error: Color(0xFFFF8A80),
    onError: Color(0xFF0B0B0C),
    surface: Color(0xFF151517),
    onSurface: Color(0xFFFFFFFF),
  );

  static ThemeData get light => _theme(_lightScheme);
  static ThemeData get dark => _theme(_darkScheme);

  static ThemeData _theme(ColorScheme colorScheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
      ),
    );
  }
}
