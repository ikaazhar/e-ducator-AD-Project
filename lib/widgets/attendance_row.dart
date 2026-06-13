// lib/widgets/attendance_row.dart
//
// Baris grid kehadiran mingguan untuk satu pelajar.
// Menampilkan Bil, Nama Pelajar, sel M1–M18, dan % Kehadiran.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lebar tetap setiap sel minggu.
const double kWeekCellWidth = 44.0;

/// Lebar tetap kolum Bil.
const double kBilCellWidth = 40.0;

/// Lebar tetap kolum Nama Pelajar.
const double kNamaCellWidth = 200.0;

/// Lebar tetap kolum % Kehadiran.
const double kPeratusWidth = 80.0;

/// Jumlah minggu dalam semester.
const int kTotalMinggu = 18;

/// Peta label pendek → warna sel.
Color cellColorFor(String? status) {
  switch (status) {
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

/// Label pendek untuk setiap status.
String shortLabel(String? status) {
  switch (status) {
    case 'Hadir':
      return 'H';
    case 'Tak Hadir':
      return 'X';
    case 'MC':
      return 'MC';
    case 'CK':
      return 'CK';
    default:
      return '-';
  }
}

/// Satu baris pelajar dalam grid kehadiran mingguan.
class AttendanceRow extends StatelessWidget {
  final int rowNumber;
  final String studentName;
  final String studentId;

  /// Peta minggu (1-indexed, 1..18) → status kehadiran atau null.
  final Map<int, String?> weeklyStatus;

  /// Set minggu yang telah dihantar (baca sahaja).
  final Set<int> submittedWeeks;

  /// Minggu yang sedang aktif (boleh diubah).
  final int activeWeek;

  /// Dipanggil apabila sel diklik — minggu dan status baharu.
  final void Function(int week, String status) onCellTapped;

  const AttendanceRow({
    super.key,
    required this.rowNumber,
    required this.studentName,
    required this.studentId,
    required this.weeklyStatus,
    required this.submittedWeeks,
    required this.activeWeek,
    required this.onCellTapped,
  });

  double get _percentHadir {
    int tidakHadir = 0;
    int totalRecorded = 0;
    for (int w = 1; w <= kTotalMinggu; w++) {
      final s = weeklyStatus[w];
      if (s != null) {
        totalRecorded++;
        if (s == 'Tak Hadir') tidakHadir++;
      }
    }
    // Jika tiada rekod lagi, papar 100%
    if (totalRecorded == 0) return 100.0;
    // Tolak peratusan ketidakhadiran dari 100%
    // MC dan CK tidak menjejaskan peratusan
    return 100.0 - (tidakHadir / kTotalMinggu) * 100;
  }

  Color get _percentColor {
    final p = _percentHadir;
    if (p >= 80) return AppTheme.hadir;
    if (p >= 60) return AppTheme.mc;
    return AppTheme.tidakHadir;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          // Kolum Bil
          _fixedCell(
            width: kBilCellWidth,
            child: Text(
              '$rowNumber',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          // Kolum Nama
          _fixedCell(
            width: kNamaCellWidth,
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                studentName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                ),
              ),
            ),
          ),
          // Sel minggu M1–M18
          for (int w = 1; w <= kTotalMinggu; w++) _weekCell(context, w),
          // Kolum % Kehadiran
          _percentCell(),
        ],
      ),
    );
  }

  Widget _weekCell(BuildContext context, int week) {
    final status = weeklyStatus[week];
    final isSubmitted = submittedWeeks.contains(week);
    final isActive = week == activeWeek;
    final color = cellColorFor(status);
    final label = shortLabel(status);
    final hasValue = status != null;

    // Highlight kolum aktif dengan latar sedikit berbeza
    final bgColor = isActive && !hasValue
        ? AppTheme.teal.withValues(alpha: 0.08)
        : Colors.white;

    return GestureDetector(
      onTap: isSubmitted
          ? null
          : () => _showStatusSheet(context, week),
      child: Container(
        width: kWeekCellWidth,
        height: 48,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            right: BorderSide(color: AppTheme.slateBorder, width: 0.5),
            bottom: BorderSide(color: AppTheme.slateBorder, width: 0.5),
          ),
        ),
        child: hasValue
            ? Center(
                child: Container(
                  width: 32,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isSubmitted ? 0.18 : 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: color.withValues(alpha: isSubmitted ? 0.5 : 0.8),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSubmitted
                            ? color.withValues(alpha: 0.7)
                            : color,
                      ),
                    ),
                  ),
                ),
              )
            : Center(
                child: Icon(
                  isActive && !isSubmitted
                      ? Icons.touch_app_rounded
                      : Icons.remove,
                  size: 14,
                  color: isActive && !isSubmitted
                      ? AppTheme.teal.withValues(alpha: 0.6)
                      : AppTheme.slateBorder,
                ),
              ),
      ),
    );
  }

  Widget _percentCell() {
    final p = _percentHadir;
    final c = _percentColor;
    return Container(
      width: kPeratusWidth,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.slateBorder, width: 0.5),
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withValues(alpha: 0.5)),
          ),
          child: Text(
            '${p.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ),
      ),
    );
  }

  Widget _fixedCell({
    required double width,
    required Widget child,
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      width: width,
      height: 48,
      alignment: alignment,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: AppTheme.slateBorder, width: 0.5),
          bottom: BorderSide(color: AppTheme.slateBorder, width: 0.5),
        ),
      ),
      child: child,
    );
  }

  void _showStatusSheet(BuildContext context, int week) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _StatusPickerSheet(
        studentName: studentName,
        week: week,
        currentStatus: weeklyStatus[week],
        onSelected: (s) {
          Navigator.pop(ctx);
          onCellTapped(week, s);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet pemilih status
// ---------------------------------------------------------------------------

class _StatusPickerSheet extends StatelessWidget {
  final String studentName;
  final int week;
  final String? currentStatus;
  final ValueChanged<String> onSelected;

  const _StatusPickerSheet({
    required this.studentName,
    required this.week,
    required this.currentStatus,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pemegang
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.slateBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Tajuk
          Text(
            'Minggu $week — Kehadiran',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            studentName,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Pilihan status
          Row(
            children: [
              _statusTile(context, 'Hadir', 'H', AppTheme.hadir),
              const SizedBox(width: 10),
              _statusTile(context, 'Tak Hadir', 'X', AppTheme.tidakHadir),
              const SizedBox(width: 10),
              _statusTile(context, 'MC', 'MC', AppTheme.mc),
              const SizedBox(width: 10),
              _statusTile(context, 'CK', 'CK', AppTheme.ck),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusTile(
    BuildContext context,
    String status,
    String label,
    Color color,
  ) {
    final isSelected = currentStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelected(status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.85)
                      : color.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
