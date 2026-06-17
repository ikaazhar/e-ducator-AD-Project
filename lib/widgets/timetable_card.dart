// lib/widgets/timetable_card.dart
import 'package:flutter/material.dart';

import '../models/timetable_entry.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

enum SessionState { akanDatang, sedangBerlangsung, telahDihantar }

const Map<String, Color> kCardDayColors = {
  'Isnin':  Color(0xFF3B82F6),
  'Selasa': Color(0xFF8B5CF6),
  'Rabu':   Color(0xFF0FB5A6),
  'Khamis': Color(0xFFF59E0B),
  'Jumaat': Color(0xFF10B981),
};

Color _unitColor(String unit) {
  const map = {
    'DGS': Color(0xFF3B82F6),
    'DPP': Color(0xFF8B5CF6),
    'DED': Color(0xFFF59E0B),
    'DEK': Color(0xFF10B981),
    'DCP': Color(0xFFEF4444),
    'DCB': Color(0xFFEC4899),
    'ITW': Color(0xFF0FB5A6),
  };
  return map[unit] ?? AppTheme.navy;
}

class TimetableCard extends StatelessWidget {
  final TimetableEntry entry;
  final SessionState state;
  final VoidCallback onTakeAttendance;
  final VoidCallback onViewAttendance;

  const TimetableCard({
    super.key,
    required this.entry,
    required this.state,
    required this.onTakeAttendance,
    required this.onViewAttendance,
  });

  @override
  Widget build(BuildContext context) {
    final isOngoing   = state == SessionState.sedangBerlangsung;
    final isSubmitted = state == SessionState.telahDihantar;
    final dayColor    = kCardDayColors[entry.day] ?? AppTheme.navy;
    final unitColor   = _unitColor(entry.departmentUnit);

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: isOngoing ? AppTheme.teal.withValues (alpha: 0.04) : Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.slateBorder),
          left: isOngoing
              ? BorderSide(color: AppTheme.teal, width: 3)
              : BorderSide.none,
        ),
      ),
      child: InkWell(
        onTap: onTakeAttendance,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              // ── Time column ──
              SizedBox(
                width: 48,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.startTime.substring(0, 5),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: dayColor,
                      ),
                    ),
                    Text(
                      entry.endTime.substring(0, 5),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Colored left stripe ──
              Container(
                width: 3,
                height: 44,
                color: unitColor,
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),

              // ── Subject info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject code + kelas pill
                    Row(children: [
                      Text(
                        entry.subjectCode,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: unitColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (entry.kelas != null) _pill(entry.kelas!, unitColor),
                      if (isOngoing) ...[
                        const SizedBox(width: 6),
                        _pill('Sedang Berlangsung', AppTheme.teal),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    // Subject name
                    Text(
                      entry.subjectName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Lecturer + Room
                    Row(children: [
                      if (entry.lecturerName != null) ...[
                        _iconInfo(Icons.person_outline, entry.lecturerName!),
                        const SizedBox(width: 10),
                      ],
                      _iconInfo(Icons.meeting_room_outlined, entry.roomName ?? '-'),
                    ]),
                  ],
                ),
              ),

              // ── Right: attendance icon + state badge ──
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _stateBadge(),
                  const SizedBox(height: 6),
                  isSubmitted
                      ? IconButton(
                          tooltip: 'Lihat Kehadiran',
                          icon: const Icon(Icons.visibility_outlined),
                          color: AppTheme.teal,
                          onPressed: onViewAttendance,
                        )
                      : IconButton(
                          tooltip: 'Ambil Kehadiran',
                          icon: const Icon(Icons.checklist_rtl),
                          color: AppTheme.teal,
                          onPressed: onTakeAttendance,
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues (alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );

  Widget _iconInfo(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppTheme.textMuted),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
    ],
  );

  Widget _stateBadge() {
    switch (state) {
      case SessionState.sedangBerlangsung:
        return const StatusBadge(text: 'Sedang Berlangsung', color: AppTheme.teal);
      case SessionState.telahDihantar:
        return const StatusBadge(text: 'Telah Dihantar', color: AppTheme.tealDark);
      case SessionState.akanDatang:
        return const StatusBadge(text: 'Akan Datang', color: AppTheme.textMuted);
    }
  }
}