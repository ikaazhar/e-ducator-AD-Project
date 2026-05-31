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

    final borderColor = isOngoing
        ? AppTheme.teal
        : (isSubmitted ? AppTheme.slateBorder : AppTheme.slateBorder);
    final borderWidth = isOngoing ? 2.0 : 1.0;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            _infoRow(Icons.calendar_today, entry.day),
            _infoRow(Icons.access_time, entry.timeSlot),
            _infoRow(Icons.meeting_room, entry.roomName ?? '-'),
            const SizedBox(height: 16),
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

  Widget _infoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: AppTheme.textDark)),
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
