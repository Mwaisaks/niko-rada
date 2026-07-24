import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Niko Rada design system.
/// AMOLED dark, amber/gold accent, calm and high-contrast for stress use.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Colour palette
  // ---------------------------------------------------------------------------
  static const Color background = Color(0xFF000000);      // true AMOLED black
  static const Color surface = Color(0xFF0D0D0D);         // card surface
  static const Color surfaceVariant = Color(0xFF1A1A1A);  // elevated surface
  static const Color surfaceHigh = Color(0xFF242424);     // chips, dividers

  static const Color primary = Color(0xFFFFB300);         // amber gold
  static const Color primaryDark = Color(0xFFFF8F00);     // darker amber
  static const Color onPrimary = Color(0xFF000000);       // text on amber

  static const Color danger = Color(0xFFE53935);          // alert red
  static const Color safe = Color(0xFF43A047);            // confirmed safe green
  static const Color info = Color(0xFF1E88E5);            // info blue

  static const Color onBackground = Color(0xFFF5F5F5);   // primary text
  static const Color onSurface = Color(0xFFE0E0E0);      // secondary text
  static const Color onSurfaceDim = Color(0xFF9E9E9E);   // dimmed text / hint

  static const Color divider = Color(0xFF2A2A2A);

  // ---------------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------------
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        secondary: primaryDark,
        surface: surface,
        onSurface: onBackground,
        error: danger,
      ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.w700, color: onBackground),
        displayMedium: GoogleFonts.outfit(
          fontSize: 28, fontWeight: FontWeight.w700, color: onBackground),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.w600, color: onBackground),
        titleMedium: GoogleFonts.outfit(
          fontSize: 17, fontWeight: FontWeight.w500, color: onBackground),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w400, color: onSurface),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w400, color: onSurface),
        labelSmall: GoogleFonts.outfit(
          fontSize: 11, fontWeight: FontWeight.w400, color: onSurfaceDim),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.w700, color: onBackground),
        iconTheme: const IconThemeData(color: onBackground),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(
            fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: GoogleFonts.outfit(color: onSurfaceDim, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: GoogleFonts.outfit(color: onBackground),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: onSurfaceDim,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: divider,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Panic button styles — domain-specific accent colours
  // ---------------------------------------------------------------------------
  static BoxDecoration panicButtonDecoration(Color accent) => BoxDecoration(
    gradient: LinearGradient(
      colors: [accent.withValues(alpha: 0.18), accent.withValues(alpha: 0.06)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
  );
}
