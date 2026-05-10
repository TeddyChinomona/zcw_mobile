// lib/theme/app_theme.dart
//
// Centralised brand palette and MaterialTheme configuration.
// Zimbabwe flag colours: green (#006400) + gold (#FFD700)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Brand colours ──────────────────────────────────────────────────────────
  // Deep Zimbabwe green — used for app bar, buttons, primary actions
  static const Color primaryColor   = Color.fromARGB(255, 45, 57, 212);

  // Lighter green — used for selected chips and highlights
  static const Color secondaryColor = Color(0xFF388E3C);

  // Zimbabwe gold — used for accent dots, badges and warnings
  static const Color accentColor    = Color.fromARGB(255, 255, 7, 7);

  // Surface / card background
  static const Color surfaceColor   = Color(0xFFF5F5F5);

  // ── Text colours ───────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFF212121);
  static const Color textSecondary  = Color(0xFF757575);

  // ── Full MaterialTheme ─────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary:   primaryColor,
        secondary: accentColor,
        surface:   surfaceColor,
      ),

      // Google Fonts — Inter for body, used consistently across the app
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),

      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),

      // Used by FilterSheet chips
      chipTheme: ChipThemeData(
        backgroundColor: primaryColor.withOpacity(0.08),
        selectedColor: primaryColor,
        labelStyle: const TextStyle(fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
