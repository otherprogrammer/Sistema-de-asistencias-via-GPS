import 'package:flutter/material.dart';

class AppColors {
  // Color corporativo principal
  static const Color primary = Color(0xFF2D6EA4); // #2D6EA4 - RGB(45,110,164)
  
  // Variaciones del color principal
  static const Color primaryLight = Color(0xFF5B8BC4);
  static const Color primaryDark = Color(0xFF1E4A73);
  
  // Colores complementarios
  static const Color background = Color(0xFFF5F8FC);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  
  // Colores de texto
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnPrimary = Colors.white;
  
  // Material Color para usar en Theme
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF2D6EA4,
    <int, Color>{
      50: Color(0xFFE6F1F9),
      100: Color(0xFFBFDBF1),
      200: Color(0xFF95C4E8),
      300: Color(0xFF6BACDE),
      400: Color(0xFF4B9AD7),
      500: Color(0xFF2D6EA4), // Color principal
      600: Color(0xFF2864A0),
      700: Color(0xFF22579B),
      800: Color(0xFF1C4B96),
      900: Color(0xFF10388C),
    },
  );
}