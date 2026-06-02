import 'package:flutter/material.dart';

/// Single source of truth for FAT App colors — mirrors FATTheme.swift
class FATTheme {
  FATTheme._();

  // MARK: - Brand Colors
  static const Color primaryGreen   = Color(0xFFC5C9BF); // sage green — card backgrounds
  static const Color successGreen   = Color(0xFF27AE60); // confirmed disclosure
  static const Color scanGreen      = Color(0xFF225522); // dark forest green — CTAs
  static const Color fatAmber       = Color(0xFFCA8A04); // partial / warnings
  static const Color fatRed         = Color(0xFFDC2626); // missing / danger
  static const Color fatOrange      = Color(0xFFE67E22);

  // MARK: - Backgrounds
  static const Color pageBG         = Color(0xFFFFFFFF);
  static const Color cardBG         = primaryGreen;

  // MARK: - Text
  static const Color textPrimary    = Color(0xFF111111);
  static const Color textSecondary  = Color(0xFF555555);

  // MARK: - ThemeData
  static ThemeData get themeData => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: pageBG,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: scanGreen,
      unselectedItemColor: Color(0xFF888888),
      backgroundColor: pageBG,
      type: BottomNavigationBarType.fixed,
    ),
    cardTheme: const CardThemeData(
      color: primaryGreen,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scanGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    useMaterial3: true,
  );
}
