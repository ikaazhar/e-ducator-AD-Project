// lib/widgets/severity_badge.dart
//
// Lencana warna mengikut tahap keseriusan laporan disiplin.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SeverityBadge extends StatelessWidget {
  final String severity;
  const SeverityBadge({super.key, required this.severity});

  Color get _color {
    switch (severity) {
      case 'Tinggi':
        return AppTheme.severityTinggi;
      case 'Sederhana':
        return AppTheme.severitySederhana;
      case 'Rendah':
      default:
        return AppTheme.severityRendah;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color),
      ),
      child: Text(
        severity,
        style: TextStyle(color: _color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
