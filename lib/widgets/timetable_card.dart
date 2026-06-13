// lib/widgets/timetable_card.dart
//
// Kad jadual waktu (M5). Memaparkan butiran sesi dan butang ambil/lihat kehadiran.
// Tambahan: paparan tarikh sesi seterusnya berdasarkan hari kelas.
import 'package:flutter/material.dart';

import '../models/timetable_entry.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

enum SessionState { akanDatang, sedangBerlangsung, telahDihantar }

// ---------------------------------------------------------------------------
// Pembantu: Kira tarikh sesi seterusnya berdasarkan hari kelas.
// ---------------------------------------------------------------------------

/// Kembalikan tarikh sesi terdekat untuk hari [malayDay].
/// Jika hari ini adalah hari berkenaan, kembalikan tarikh hari ini.
String nextSessionDate(String malayDay) {
  const dayMap = {
    'Isnin': DateTime.monday,
    'Selasa': DateTime.tuesday,
    'Rabu': DateTime.wednesday,
    'Khamis': DateTime.thursday,
    'Jumaat': DateTime.friday,
  };
  const months = [
    'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
    'Jul', 'Ogs', 'Sep', 'Okt', 'Nov', 'Dis',
  ];
  final target = dayMap[malayDay] ?? DateTime.monday;
  var date = DateTime.now();
  // Cari tarikh paling dekat (termasuk hari ini)
  while (date.weekday != target) {
    date = date.add(const Duration(days: 1));
  }
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

// ---------------------------------------------------------------------------
// Widget Kad Jadual
// ---------------------------------------------------------------------------

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
    final isOngoing = state == SessionState.sedangBerlangsung;
    final isSubmitted = state == SessionState.telahDihantar;
    final dateLabel = nextSessionDate(entry.day);

    final borderColor = isOngoing
        ? AppTheme.teal
        : (isSubmitted ? AppTheme.slateBorder : AppTheme.slateBorder);
    final borderWidth = isOngoing ? 2.0 : 1.0;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
<<<<<<< Updated upstream
=======
      color: isOngoing
          ? AppTheme.teal.withOpacity(0.04)
          : Colors.white,
>>>>>>> Stashed changes
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
<<<<<<< Updated upstream
=======
            // ── Pengepala: nama subjek + lencana status ──
>>>>>>> Stashed changes
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.subjectName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.subjectCode,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _stateBadge(),
              ],
            ),
            const SizedBox(height: 12),
<<<<<<< Updated upstream
            _infoRow(Icons.calendar_today, entry.day),
            _infoRow(Icons.access_time, entry.timeSlot),
            _infoRow(Icons.meeting_room, entry.roomName ?? '-'),
            const SizedBox(height: 16),
=======
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Baris maklumat ──
            // Hari + tarikh dalam satu baris, contoh: "Isnin — 6 Jan 2025"
            _infoRow(
              Icons.calendar_today_outlined,
              '${entry.day}  —  $dateLabel',
              highlight: isOngoing,
            ),
            _infoRow(Icons.access_time_outlined, entry.timeSlot),
            if (entry.roomName != null)
              _infoRow(Icons.meeting_room_outlined, entry.roomName!),
            if (entry.lecturerName != null)
              _infoRow(Icons.person_outline, entry.lecturerName!),
            if (entry.session != null)
              _infoRow(Icons.event_note_outlined, entry.session!),

            const SizedBox(height: 14),

            // ── Butang tindakan ──
>>>>>>> Stashed changes
            SizedBox(
              width: double.infinity,
              child: isSubmitted
                  ? OutlinedButton.icon(
                      onPressed: onViewAttendance,
                      icon: const Icon(Icons.visibility, color: AppTheme.teal),
                      label: const Text(
                        'Lihat Kehadiran',
                        style: TextStyle(color: AppTheme.teal),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: onTakeAttendance,
                      icon: const Icon(Icons.checklist_rtl),
                      label: const Text('Ambil Kehadiran'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
<<<<<<< Updated upstream
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: AppTheme.textDark)),
=======
          Icon(
            icon,
            size: 15,
            color: highlight ? AppTheme.teal : AppTheme.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: highlight ? AppTheme.teal : AppTheme.textDark,
                fontWeight:
                    highlight ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
>>>>>>> Stashed changes
        ],
      ),
    );
  }

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