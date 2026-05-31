// lib/screens/hierarchy_router.dart
//
// Penghala berasaskan peranan. Membaca UserProvider dan menghala
// pengguna ke papan pemuka yang sesuai.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import 'dashboards/admin_dashboard.dart';
import 'dashboards/department_head_dashboard.dart';
import 'dashboards/lecturer_dashboard.dart';
import 'dashboards/overview_dashboard.dart';
import 'dashboards/program_supervisor_dashboard.dart';
import 'login_screen.dart';

class HierarchyRouter extends StatelessWidget {
  const HierarchyRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProvider>().profile;

    if (profile == null) {
      return const LoginScreen();
    }

    switch (profile.role) {
      case 'Admin':
        return const AdminDashboardScreen();
      case 'Timbalan Pengarah Akademik':
        return const OverviewDashboardScreen();
      case 'Ketua Jabatan':
        return const DepartmentHeadDashboardScreen();
      case 'Ketua Program':
        return const ProgramSupervisorDashboardScreen();
      case 'Lecturer':
      default:
        return const LecturerDashboardScreen();
    }
  }
}
