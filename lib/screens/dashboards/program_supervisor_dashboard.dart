// lib/screens/dashboards/program_supervisor_dashboard.dart
//
// Papan pemuka untuk Ketua Program.
import 'package:flutter/material.dart';

import '_dashboard_shell.dart';

class ProgramSupervisorDashboardScreen extends StatelessWidget {
  const ProgramSupervisorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardShell(
      roleTitle: 'Ketua Program',
      links: [
        DashboardLink(
          title: 'Muat Naik Jadual',
          description: 'Urus jadual untuk program anda.',
          icon: Icons.upload_file,
          route: '/timetable-upload',
        ),
        DashboardLink(
          title: 'Jadual Waktu',
          description: 'Lihat dan ambil kehadiran kelas.',
          icon: Icons.calendar_month,
          route: '/timetable',
        ),
        DashboardLink(
          title: 'Laporan Disiplin',
          description: 'Pantau laporan disiplin program.',
          icon: Icons.report_gmailerrorred,
          route: '/discipline',
        ),
        DashboardLink(
          title: 'Pelaporan Kehadiran',
          description: 'Analitis kehadiran program.',
          icon: Icons.bar_chart,
          route: '/reporting',
        ),
        DashboardLink(
          title: 'Tempahan Bilik',
          description: 'Tempah bilik untuk program.',
          icon: Icons.meeting_room,
          route: '/booking',
        ),
      ],
    );
  }
}
