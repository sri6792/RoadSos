// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Palette
  static const Color sosRed = Color(0xFFD62828);
  static const Color sosRedLight = Color(0xFFFF4444);
  static const Color sosRedDark = Color(0xFFA01010);

  // Dark Blue
  static const Color navyDark = Color(0xFF0D1B2A);
  static const Color navyMid = Color(0xFF1B2E45);
  static const Color navyLight = Color(0xFF243B55);

  // White / Off-White
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF5F7FA);
  static const Color lightGray = Color(0xFFE8ECF0);
  static const Color midGray = Color(0xFFB0BEC5);

  // Status Colors
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFB300);
  static const Color info = Color(0xFF0288D1);

  // Surface
  static const Color cardDark = Color(0xFF162032);
  static const Color cardLight = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.offWhite,
      colorScheme: const ColorScheme.light(
        primary: AppColors.sosRed,
        secondary: AppColors.navyDark,
        surface: AppColors.white,
        error: AppColors.sosRed,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.rajdhani(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: AppColors.navyDark,
          letterSpacing: -1,
        ),
        displayMedium: GoogleFonts.rajdhani(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: AppColors.navyDark,
          letterSpacing: -0.5,
        ),
        displaySmall: GoogleFonts.rajdhani(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: AppColors.navyDark,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.navyDark,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.navyDark,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.navyDark,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.navyDark,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.navyMid,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.navyDark,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sosRed,
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightGray, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.sosRed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.midGray, fontSize: 15),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.sosRed,
        unselectedItemColor: AppColors.midGray,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
  color: AppColors.white,
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: const BorderSide(
      color: AppColors.lightGray,
      width: 1,
    ),
  ),
),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.rajdhani(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.navyDark,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: AppColors.navyDark),
        centerTitle: false,
      ),
    );
  }
}
