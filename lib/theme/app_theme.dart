// lib/theme/app_theme.dart
//
// Tema rasmi aplikasi E-ducator — TVET MARA Visual Identity.
// Warna utama: TVET MARA Blue (#004C97). Aksen: Bright Yellow (#FFCD00).
// Fon: Poiret One (heading/display) + Roboto (body) — mengikut moodboard.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Primary brand colours ──────────────────────────────────────────────────
  static const Color navy     = Color(0xFF004C97); // TVET MARA Blue
  static const Color navyDark = Color(0xFF003570); // darker shade for sidebar/hover

  // ── Accent colour ─────────────────────────────────────────────────────────
  static const Color teal     = Color(0xFFFFCD00); // Bright Yellow (buttons, active)
  static const Color tealDark = Color(0xFFE6B800); // darker yellow for pressed state

  // ── Neutral surfaces ───────────────────────────────────────────────────────
  static const Color slate       = Color(0xFFF4F6F8);
  static const Color slateBorder = Color(0xFFE2E8F0);

  // ── Text colours ──────────────────────────────────────────────────────────
  static const Color textDark  = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);

  // ── Attendance status colours (unchanged) ─────────────────────────────────
  static const Color hadir      = Color(0xFF16A34A);
  static const Color tidakHadir = Color(0xFFDC2626);
  static const Color mc         = Color(0xFFF59E0B);
  static const Color ck         = Color(0xFFEA580C);

  // ── Discipline severity colours (unchanged) ───────────────────────────────
  static const Color severityRendah    = Color(0xFF0FB5A6);
  static const Color severitySederhana = Color(0xFFF59E0B);
  static const Color severityTinggi    = Color(0xFFDC2626);

  // ── Light theme ───────────────────────────────────────────────────────────
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);

    // Roboto base text theme (body)
    final robotoTextTheme = GoogleFonts.robotoTextTheme(base.textTheme).apply(
      bodyColor: textDark,
      displayColor: textDark,
    );

    // Override display/headline styles with Poiret One
    final mergedTextTheme = robotoTextTheme.copyWith(
      displayLarge:  GoogleFonts.poiretOne(textStyle: robotoTextTheme.displayLarge),
      displayMedium: GoogleFonts.poiretOne(textStyle: robotoTextTheme.displayMedium),
      displaySmall:  GoogleFonts.poiretOne(textStyle: robotoTextTheme.displaySmall),
      headlineLarge: GoogleFonts.poiretOne(textStyle: robotoTextTheme.headlineLarge),
      headlineMedium: GoogleFonts.poiretOne(textStyle: robotoTextTheme.headlineMedium),
      headlineSmall:  GoogleFonts.poiretOne(textStyle: robotoTextTheme.headlineSmall),
      titleLarge:    GoogleFonts.poiretOne(textStyle: robotoTextTheme.titleLarge),
      // titleMedium, titleSmall, body*, label* → Roboto (readable at small sizes)
    );

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: teal,
        surface: Colors.white,
      ),
      textTheme: mergedTextTheme,
      scaffoldBackgroundColor: slate,
      appBarTheme: AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poiretOne(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: slateBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Color(0xFF1E293B),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(color: slateBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: slateBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: slateBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: navy, width: 1.5),
        ),
        hintStyle: GoogleFonts.roboto(color: textMuted, fontSize: 14),
        labelStyle: GoogleFonts.roboto(color: textMuted, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(color: slateBorder, thickness: 1),
    );
  }
}

/// Senarai rasmi Jabatan / Unit Program di IKM Johor Bahru.
const List<String> kJabatanList = [
  'DGS', 'DPP', 'DED', 'DEK', 'DCP', 'DCB', 'ITW',
  'DGM', 'IMF', 'SLR', 'SMI', 'SMK', 'SMM', 'DMM',
];

/// Senarai rasmi peranan pengguna mengikut hierarki.
const List<String> kRoleList = [
  'Admin',
  'Timbalan Pengarah Akademik',
  'Ketua Jabatan',
  'Ketua Program',
  'Lecturer',
];

/// Senarai hari kuliah.
const List<String> kHariList = ['Isnin', 'Selasa', 'Rabu', 'Khamis', 'Jumaat'];
