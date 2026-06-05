// lib/widgets/timetable_card.dart
//
// Kad jadual waktu (M5). Memaparkan butiran sesi dan butang ambil/lihat kehadiran.
import 'package:flutter/material.dart';

import '../models/timetable_entry.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

enum SessionState { akanDatang, sedangBerlangsung, telahDihantar }

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

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOngoing ? AppTheme.teal : AppTheme.slateBorder,
          width: isOngoing ? 2.0 : 1.0,
        ),
      ),
      // Subtle teal tint when the class is ongoing
      color: isOngoing
          ? AppTheme.teal.withOpacity(0.04)
          : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: subject + state badge ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 2),
                      Text(
                        entry.subjectCode,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                _stateBadge(),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Info rows ──
            _infoRow(Icons.calendar_today_outlined, entry.day),
            _infoRow(Icons.access_time_outlined, entry.timeSlot),
            if (entry.roomName != null)
              _infoRow(Icons.meeting_room_outlined, entry.roomName!),
            if (entry.lecturerName != null)
              _infoRow(Icons.person_outline, entry.lecturerName!),
            if (entry.session != null)
              _infoRow(Icons.event_note_outlined, entry.session!),

            const SizedBox(height: 14),

            // ── Action button ──
            SizedBox(
              width: double.infinity,
              child: isSubmitted
                  ? OutlinedButton.icon(
                      onPressed: onViewAttendance,
                      icon: const Icon(Icons.visibility_outlined,
                          color: AppTheme.teal),
                      label: const Text(
                        'Lihat Kehadiran / View Attendance',
                        style: TextStyle(color: AppTheme.teal),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: onTakeAttendance,
                      icon: const Icon(Icons.checklist_rtl),
                      label: const Text('Ambil Kehadiran / Take Attendance'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateBadge() {
    switch (state) {
      case SessionState.sedangBerlangsung:
        return const StatusBadge(
            text: 'Sedang Berlangsung', color: AppTheme.teal);
      case SessionState.telahDihantar:
        return const StatusBadge(
            text: 'Telah Dihantar', color: AppTheme.tealDark);
      case SessionState.akanDatang:
        return const StatusBadge(
            text: 'Akan Datang', color: AppTheme.textMuted);
    }
  }
}
