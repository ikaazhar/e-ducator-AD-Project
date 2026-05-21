// lib/widgets/attendance_row.dart
//
// Baris kehadiran setiap pelajar dengan pemilih status segmen.
import 'package:flutter/material.dart';

import '../models/attendance_record.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

class AttendanceRow extends StatelessWidget {
  final int rowNumber;
  final String studentName;
  final String studentId;
  final String? selected;       // Nilai status semasa atau null
  final bool readOnly;
  final ValueChanged<String> onStatusChanged;

  const AttendanceRow({
    super.key,
    required this.rowNumber,
    required this.studentName,
    required this.studentId,
    required this.selected,
    required this.onStatusChanged,
    this.readOnly = false,
  });

  Color _colorFor(String s) {
    switch (s) {
      case 'Hadir':
        return AppTheme.hadir;
      case 'Tak Hadir':
        return AppTheme.tidakHadir;
      case 'MC':
        return AppTheme.mc;
      case 'CK':
        return AppTheme.ck;
      default:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.slateBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.navy,
            child: Text(
              '$rowNumber',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  studentId,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (readOnly)
            StatusBadge.attendance(selected ?? '-')
          else
            _segmentedSelector(),
        ],
      ),
    );
  }

  Widget _segmentedSelector() {
    return Wrap(
      spacing: 6,
      children: kAttendanceStatuses.map((s) {
        final isSelected = selected == s;
        final c = _colorFor(s);
        return InkWell(
          onTap: () => onStatusChanged(s),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? c : c.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c, width: isSelected ? 1.5 : 1),
            ),
            child: Text(
              s,
              style: TextStyle(
                color: isSelected ? Colors.white : c,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
