// lib/widgets/status_badge.dart
//
// Lencana status umum (digunakan oleh kad jadual waktu dan kehadiran).
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const StatusBadge({super.key, required this.text, required this.color});

  factory StatusBadge.attendance(String status) {
    Color c;
    switch (status) {
      case 'Hadir':
        c = AppTheme.hadir;
        break;
      case 'Tak Hadir':
        c = AppTheme.tidakHadir;
        break;
      case 'MC':
        c = AppTheme.mc;
        break;
      case 'CK':
        c = AppTheme.ck;
        break;
      default:
        c = AppTheme.textMuted;
    }
    return StatusBadge(text: status, color: c);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
