// lib/theme/retro_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// RetroTheme - A unified theme class for the Kinship app
abstract class RetroTheme {
  // Colors
  static const Color primary = Color(0xFF2962FF);
  static const Color accent = Color(0xFF00B0FF);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFD32F2F);

  // Text Styles
  static TextStyle get bodyLarge => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static TextStyle get bodyMedium => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static TextStyle get bodySmall => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static TextStyle get headlineLarge => GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static TextStyle get headlineMedium => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle get headlineSmall => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle get titleLarge => GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle get titleMedium => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static TextStyle get labelLarge => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );
}
