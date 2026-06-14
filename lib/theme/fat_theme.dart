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
  static const Color errorRed       = Color(0xFFB91C1C); // error text (matches iOS)
  static const Color errorBGTint    = Color(0xFFFFE6E1); // error bg tint (matches iOS)

  // MARK: - Backgrounds
  static const Color pageBG         = Color(0xFFFFFFFF);
  static const Color cardBG         = primaryGreen;

  // MARK: - Text
  static const Color textPrimary    = Color(0xFF111111);
  static const Color textSecondary  = Color(0xFF555555);

  // MARK: - Credibility / Tier Colors
  static const Color usdaApprovedBlue = Color(0xFF1D4ED8); // USDA-Reviewed tier
  static const Color tierHighest    = Color(0xFF15803D); // highest welfare
  static const Color tierHigh       = Color(0xFF4D9A2A); // high welfare
  static const Color tierMeaningful = Color(0xFF84B026); // meaningful welfare
  static const Color tierModerate   = Color(0xFFCA8A04); // moderate welfare
  static const Color tierMarginal   = Color(0xFFE67E22); // marginal welfare
  static const Color tierMisleading = Color(0xFFDC2626); // potentially misleading
  static const Color porkSmall      = Color(0xFF27AE60); // unconcentrated (chicken HHI)

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
