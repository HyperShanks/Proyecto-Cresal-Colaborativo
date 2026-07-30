import 'package:flutter/material.dart';
import 'tokens/app_palette.dart';
import 'tokens/app_typography.dart';

class AppComponents {
  // REGLA W3C: Touch target mínimo para operarios con guantes
  static const double minTouchTarget = 44.0;
  static const double defaultBorderRadius = 8.0;

  static ElevatedButtonThemeData get elevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, minTouchTarget), // Infinito para que ocupe el ancho por defecto, o se adapte
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        backgroundColor: AppPalette.primary,
        foregroundColor: AppPalette.textPrimary,
        textStyle: AppTypography.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(defaultBorderRadius),
        ),
      ),
    );
  }

  static CardTheme get cardTheme {
    return cardThemeWithSurface(AppPalette.surface);
  }

  static CardTheme get cardThemeLight {
    return cardThemeWithSurface(AppPalette.surfaceLight);
  }

  static CardTheme cardThemeWithSurface(Color surfaceColor) {
    return CardTheme(
      color: surfaceColor,
      elevation: 0, // En Dark Mode puro es mejor usar el color de superficie que sombras
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      margin: const EdgeInsets.only(bottom: 16.0),
    );
  }

  static InputDecorationTheme get inputDecorationTheme {
    return inputDecorationThemeWithFill(AppPalette.surface);
  }

  static InputDecorationTheme get inputDecorationThemeLight {
    return inputDecorationThemeWithFill(AppPalette.surfaceLight);
  }

  static InputDecorationTheme inputDecorationThemeWithFill(Color fillColor) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.all(16.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(defaultBorderRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(defaultBorderRadius),
        borderSide: const BorderSide(color: AppPalette.primary, width: 2),
      ),
    );
  }
}
