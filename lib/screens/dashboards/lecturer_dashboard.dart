// lib/screens/dashboards/lecturer_dashboard.dart
//
// Papan pemuka untuk peranan Lecturer.
import 'package:flutter/material.dart';

import '_dashboard_shell.dart';

class LecturerDashboardScreen extends StatelessWidget {
  const LecturerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardShell(
      roleTitle: 'Pensyarah',
      links: [
        DashboardLink(
          title: 'Jadual Waktu',
          description: 'Lihat jadual dan ambil kehadiran.',
          icon: Icons.calendar_month,
          route: '/timetable',
        ),
        DashboardLink(
          title: 'Laporan Disiplin',
          description: 'Hantar laporan disiplin pelajar.',
          icon: Icons.report_gmailerrorred,
          route: '/discipline',
        ),
        DashboardLink(
          title: 'Tempahan Bilik',
          description: 'Tempah bilik untuk aktiviti tambahan.',
          icon: Icons.meeting_room,
          route: '/booking',
        ),
        DashboardLink(
          title: 'Laporan Kehadiran',
          description: 'Pantau kehadiran kelas anda.',
          icon: Icons.bar_chart,
          route: '/reporting',
        ),
      ],
    );
  }
}
