// lib/screens/dashboards/department_head_dashboard.dart
//
// Papan pemuka untuk Ketua Jabatan.
import 'package:flutter/material.dart';

import '_dashboard_shell.dart';

class DepartmentHeadDashboardScreen extends StatelessWidget {
  const DepartmentHeadDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardShell(
      roleTitle: 'Ketua Jabatan',
      links: [
        DashboardLink(
          title: 'Pelaporan Kehadiran',
          description: 'Pantau eskalasi & amaran jabatan.',
          icon: Icons.bar_chart,
          route: '/reporting',
        ),
        DashboardLink(
          title: 'Jadual Waktu',
          description: 'Paparan jadual jabatan.',
          icon: Icons.calendar_month,
          route: '/timetable',
        ),
        DashboardLink(
          title: 'Laporan Disiplin',
          description: 'Semak kes disiplin jabatan.',
          icon: Icons.report_gmailerrorred,
          route: '/discipline',
        ),
        DashboardLink(
          title: 'Tempahan Bilik',
          description: 'Tempah bilik.',
          icon: Icons.meeting_room,
          route: '/booking',
        ),
      ],
    );
  }
}
