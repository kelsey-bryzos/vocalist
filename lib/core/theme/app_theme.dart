import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF6B4EFF); // Purple-indigo brand color

  static ThemeData light() {
    final cs = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      fontFamily: 'SF Pro Display',
    );
  }

  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      fontFamily: 'SF Pro Display',
    );
  }
}
