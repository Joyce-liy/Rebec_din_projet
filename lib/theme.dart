import 'package:flutter/material.dart';

class PharmaTheme {
  static const Color emeraldGreen = Color(0xFF50C878);
  static const Color white = Colors.white;
  static const Color darkGrey = Color(0xFF2D3436);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: emeraldGreen,
      scaffoldBackgroundColor: white,
      appBarTheme: AppBarTheme(
        backgroundColor: emeraldGreen,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emeraldGreen,
          foregroundColor: white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}