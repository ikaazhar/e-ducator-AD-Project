// lib/theme/app_theme.dart
//
// Tema rasmi aplikasi E-ducator — TVET MARA Visual Identity.
// Warna utama: TVET MARA Blue (#004C97). Aksen: Bright Yellow (#FFCD00).
import 'package:flutter/material.dart';

class AppTheme {
  // ── Primary brand colours ──────────────────────────────────────────────────
  static const Color navy     = Color(0xFF004C97); // TVET MARA Blue
  static const Color navyDark = Color(0xFF003570); // darker shade for sidebar/hover

  // ── Accent colour (replaces teal) ─────────────────────────────────────────
  static const Color teal     = Color(0xFFFFCD00); // Bright Yellow (buttons, active)
  static const Color tealDark = Color(0xFFE6B800); // darker yellow for pressed state

  // ── Neutral surfaces ───────────────────────────────────────────────────────
  static const Color slate       = Color(0xFFF4F6F8); // page background
  static const Color slateBorder = Color(0xFFE2E8F0); // card/divider borders

  // ── Text colours ──────────────────────────────────────────────────────────
  static const Color textDark  = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);

  // ── Attendance status colours (unchanged) ─────────────────────────────────
  static const Color hadir      = Color(0xFF16A34A); // present  – green
  static const Color tidakHadir = Color(0xFFDC2626); // absent   – red
  static const Color mc         = Color(0xFFF59E0B); // MC       – amber
  static const Color ck         = Color(0xFFEA580C); // CK       – orange

  // ── Discipline severity colours (unchanged) ───────────────────────────────
  static const Color severityRendah    = Color(0xFF0FB5A6);
  static const Color severitySederhana = Color(0xFFF59E0B);
  static const Color severityTinggi    = Color(0xFFDC2626);

  // ── Light theme ───────────────────────────────────────────────────────────
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: teal,       // yellow accent
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: slate,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
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
          backgroundColor: teal,            // Yellow buttons
          foregroundColor: Color(0xFF1E293B), // dark text on yellow
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(color: slateBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          borderSide: const BorderSide(color: navy, width: 1.5), // blue focus ring
        ),
      ),
      dividerTheme: const DividerThemeData(color: slateBorder, thickness: 1),
      textTheme: base.textTheme.apply(bodyColor: textDark, displayColor: textDark),
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
