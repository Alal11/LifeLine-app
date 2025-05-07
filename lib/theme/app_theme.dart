import 'package:flutter/material.dart';

class AppTheme {
  // 앱의 주요 색상
  static const Color primaryColor = Color(0xFF2196F3); // 파란색
  static const Color emergencyColor = Color(0xFFE53935); // 빨간색
  static const Color accentColor = Color(0xFF4CAF50); // 초록색
  static const Color backgroundColor = Color(0xFFF5F5F5); // 밝은 회색

  // 앱 테마 설정
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        error: emergencyColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      scaffoldBackgroundColor: backgroundColor,
      useMaterial3: true,
    );
  }
}
