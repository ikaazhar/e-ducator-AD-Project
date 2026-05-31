// lib/screens/dashboards/overview_dashboard.dart
//
// Papan pemuka untuk Timbalan Pengarah Akademik (gambaran institusi).
import 'package:flutter/material.dart';

import '_dashboard_shell.dart';

class OverviewDashboardScreen extends StatelessWidget {
  const OverviewDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardShell(
      roleTitle: 'Timbalan Pengarah Akademik',
      links: [
        DashboardLink(
          title: 'Pelaporan Kehadiran',
          description: 'Pantau kes kritikal (Level 3).',
          icon: Icons.bar_chart,
          route: '/reporting',
        ),
        DashboardLink(
          title: 'Laporan Disiplin',
          description: 'Pemantauan disiplin institusi.',
          icon: Icons.report_gmailerrorred,
          route: '/discipline',
        ),
        DashboardLink(
          title: 'Jadual Waktu',
          description: 'Paparan jadual seluruh institusi.',
          icon: Icons.calendar_month,
          route: '/timetable',
        ),
        DashboardLink(
          title: 'Tempahan Bilik',
          description: 'Tempah bilik dan fasiliti.',
          icon: Icons.meeting_room,
          route: '/booking',
        ),
      ],
    );
  }
}
