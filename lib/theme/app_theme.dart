import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0B132B); 
  static const Color accentColor = Color(0xFF00C853); // Success Green
  static const Color darkSecondaryColor = Color(0xFF1C2541); 
  static const Color darkBackgroundColor = Color(0xFF0B132B);
  
  static const Color lightBackgroundColor = Color(0xFFF8F9FA); // Premium Off-White
  static const Color lightSurfaceColor = Colors.white;
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightAccentColor = Color(0xFF008E3C); // Darker Success Green for light mode

  // Legacy constants for backwards compatibility with existing screens
  static const Color secondaryColor = Color(0xFF1C2541); 
  static const Color backgroundColor = Color(0xFF0B132B);
  static const Color textPrimaryColor = Colors.white;
  static const Color textSecondaryColor = Colors.white70;

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackgroundColor,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: lightAccentColor,
        secondary: lightAccentColor,
        surface: lightSurfaceColor,
        error: Colors.redAccent,
        onPrimary: Colors.white,
        onSurface: lightTextPrimary,
        onSecondary: Colors.white,
      ),
      iconTheme: const IconThemeData(color: lightTextPrimary),
      textTheme: GoogleFonts.carlitoTextTheme(
        ThemeData(brightness: Brightness.light).textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.carlito(fontSize: 32, fontWeight: FontWeight.bold, color: lightTextPrimary),
        displayMedium: GoogleFonts.carlito(fontSize: 28, fontWeight: FontWeight.bold, color: lightTextPrimary),
        titleLarge: GoogleFonts.carlito(fontSize: 22, fontWeight: FontWeight.w600, color: lightTextPrimary),
        titleMedium: GoogleFonts.carlito(fontSize: 18, fontWeight: FontWeight.w500, color: lightTextPrimary),
        bodyLarge: GoogleFonts.carlito(fontSize: 16, color: lightTextPrimary),
        bodyMedium: GoogleFonts.carlito(fontSize: 14, color: lightTextSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(color: lightTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightAccentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.carlito(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withAlpha(20), // darker fill in light mode
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withAlpha(30)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withAlpha(30)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightAccentColor),
        ),
        labelStyle: const TextStyle(color: lightTextSecondary),
        hintStyle: const TextStyle(color: lightTextSecondary),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withAlpha(25),
        thickness: 1,
        space: 32,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackgroundColor,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        secondary: accentColor,
        surface: darkSecondaryColor,
        error: Colors.redAccent,
        onPrimary: Colors.white,
        onSurface: Colors.white,
        onSecondary: Colors.white,
      ),
      textTheme: GoogleFonts.carlitoTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.carlito(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        displayMedium: GoogleFonts.carlito(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: GoogleFonts.carlito(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
        titleMedium: GoogleFonts.carlito(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
        bodyLarge: GoogleFonts.carlito(fontSize: 16, color: Colors.white),
        bodyMedium: GoogleFonts.carlito(fontSize: 14, color: Colors.white70),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.carlito(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withAlpha(12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withAlpha(25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentColor),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withAlpha(25),
        thickness: 1,
        space: 32,
      ),
    );
  }
}
