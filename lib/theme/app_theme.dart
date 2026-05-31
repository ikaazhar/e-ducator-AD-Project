// lib/theme/app_theme.dart
//
// Tema rasmi aplikasi E-ducator.
// Warna utama: Navy Blue. Warna aksen: Teal. Latar: Putih / Slate-gray.
import 'package:flutter/material.dart';

class AppTheme {
  static const Color navy = Color(0xFF0B2545);
  static const Color navyDark = Color(0xFF071A33);
  static const Color teal = Color(0xFF0FB5A6);
  static const Color tealDark = Color(0xFF0A8F84);
  static const Color slate = Color(0xFFF4F6F8);
  static const Color slateBorder = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);

  static const Color hadir = Color(0xFF16A34A);
  static const Color tidakHadir = Color(0xFFDC2626);
  static const Color mc = Color(0xFFF59E0B);
  static const Color ck = Color(0xFFEA580C);

  static const Color severityRendah = Color(0xFF0FB5A6);
  static const Color severitySederhana = Color(0xFFF59E0B);
  static const Color severityTinggi = Color(0xFFDC2626);

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: teal,
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
          backgroundColor: teal,
          foregroundColor: Colors.white,
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
          borderSide: const BorderSide(color: teal, width: 1.5),
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
