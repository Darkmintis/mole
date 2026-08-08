import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const seed = Color(0xFF1B6B4A);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3DDC97),
        brightness: Brightness.dark,
      ),
    );
  }
}
