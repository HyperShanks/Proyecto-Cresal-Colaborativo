import 'package:flutter/material.dart';

// Creamos una clase abtracta AppPalette para guardar constantes de colores, esto debido a que los static los podemos llamar
// sin tener que instanciar la clase.
abstract class AppPalette {
  // Fondos (Dark Mode)
  static const Color background = Color(0xFF0F1416);
  static const Color surface = Color(0xFF1A2226); // Ligeramente más claro para que las tarjetas resalten

  // Fondos (Light Mode)
  static const Color backgroundLight = Color(0xFFF4F6F8);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // Marca y Acentos
  static const Color primary = Color(0xFF2596BE); // Azul Cresal
  static const Color secondary = Color(0xFFFFB800); // Ámbar para alertas/prioridades
  static const Color tertiary = Color(0xFF004C89); // Azul corporativo sidebar / acentos
  static const Color neutral = Color(0xFF73787B); // Gris para elementos inactivos


  // Textos (Alto contraste para legibilidad al sol)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF90A4AE);

  // Textos (Light Mode)
  static const Color textPrimaryLight = Color(0xFF0F1416);
  static const Color textSecondaryLight = Color(0xFF546E7A);

  // Estados de Operación
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFFFB800);
}
