// lib/screens/dashboards/department_head_dashboard.dart
//
// Papan pemuka untuk Ketua Jabatan.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/attendance_summary.dart';
import '../../providers/user_provider.dart';
import '../../services/reporting_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '_dashboard_shell.dart';
import '../../services/user_management_service.dart'; // NEW
import 'user_management_screen.dart';

class DepartmentHeadDashboardScreen extends StatefulWidget {
  const DepartmentHeadDashboardScreen({super.key});

  @override
  State<DepartmentHeadDashboardScreen> createState() =>
      _DepartmentHeadDashboardScreenState();
}

class _DepartmentHeadDashboardScreenState
    extends State<DepartmentHeadDashboardScreen> {
  bool _loading = true;
  int _level2Count = 0;
  int _level3Count = 0;
  int _totalPrograms = 0;
  int _totalLecturers = 0;
  // Add to state class:
  int _pendingCount = 0; // NEW 
  List<Map<String, dynamic>> _escalatedCases = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _loadPendingCount(); // NEW
  }

  Future<void> _loadPendingCount() async {
    try {
      final rows = await UserManagementService().getPendingUsers('Ketua Jabatan');
      if (mounted) setState(() => _pendingCount = rows.length);
    } catch (_) {}
  }

  void _openUserManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserManagementScreen()),
    );
    _loadPendingCount();
  }

  Future<void> _loadDashboard() async {
    final user = context.read<UserProvider>().profile;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final dept = user.departmentUnit ?? '';

    try {
      final lecturersFuture = client
          .from('profiles')
          .select('id')
          .eq('department_unit', dept)
          .eq('role', 'Lecturer');
      final programsFuture = client
          .from('timetable')
          .select('department_unit')
          .eq('department_unit', dept);
      final summariesFuture = ReportingService().fetchAttendanceSummary(user);

      final lecturerRows = _rowsFrom(await lecturersFuture);
      final programRows = _rowsFrom(await programsFuture);
      final summaries = await summariesFuture;

      final distinctPrograms = <String>{};
      for (final row in programRows) {
        final unit = row['department_unit']?.toString() ?? '';
        if (unit.isNotEmpty) distinctPrograms.add(unit);
      }

      final escalated = summaries.where((s) => s.warningLevel >= 2).toList()
        ..sort((a, b) => b.warningLevel.compareTo(a.warningLevel));

      final cases = escalated.take(5).map((summary) {
        return {
          'name': summary.studentName,
          'classId': summary.classId,
          'percent': summary.attendancePercent,
          'warningLevel': summary.warningLevel,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _totalLecturers = lecturerRows.length;
          _totalPrograms = distinctPrograms.length;
          _level2Count = summaries.where((s) => s.warningLevel == 2).length;
          _level3Count = summaries.where((s) => s.warningLevel == 3).length;
          _escalatedCases = cases;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _totalLecturers = 0;
          _totalPrograms = 0;
          _level2Count = 0;
          _level3Count = 0;
          _escalatedCases = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static List<Map<String, dynamic>> _rowsFrom(dynamic response) {
    if (response == null) return [];
    return (response as List).cast<Map<String, dynamic>>();
  }

  String _warningBadge(int level) {
    if (level == 3) return 'T3';
    if (level == 2) return 'T2';
    if (level == 1) return 'T1';
    return 'OK';
  }

  Widget _quickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required Color color,
  }) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.pushNamed(context, route),
        icon: Icon(icon, size: 18, color: color),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.navy,
          side: const BorderSide(color: AppTheme.slateBorder),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Papan Pemuka',
      actions: [
         Stack(
            children: [
              IconButton(
                tooltip: 'Sahkan Pengguna Baru',
                icon: const Icon(Icons.manage_accounts),
                onPressed: _openUserManagement,
              ),
              if (_pendingCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$_pendingCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/reporting'),
            icon: const Icon(Icons.bar_chart, size: 16),
            label: const Text('Laporan Penuh'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy, foregroundColor: Colors.white),
          ),
      ],
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.teal),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pemantauan Jabatan',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kes eskalasi dan kehadiran jabatan anda.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 900) {
                        return Row(
                          children: [
                            Expanded(
                              child: DashStatCard(
                                title: 'JUMLAH PENSYARAH',
                                value: '$_totalLecturers',
                                subtitle: 'Pensyarah jabatan',
                                icon: Icons.person,
                                iconColor: AppTheme.teal,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'UNIT PROGRAM',
                                value: '$_totalPrograms',
                                subtitle: 'Unit program aktif',
                                icon: Icons.account_tree,
                                iconColor: AppTheme.navy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'AMARAN TAHAP 2',
                                value: '$_level2Count',
                                subtitle: 'Kes tahap 2',
                                icon: Icons.warning,
                                iconColor: AppTheme.ck,
                                onTap: () => Navigator.pushNamed(context, '/reporting'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'AMARAN TAHAP 3',
                                value: '$_level3Count',
                                subtitle: 'Kes tahap 3',
                                icon: Icons.error,
                                iconColor: AppTheme.tidakHadir,
                                onTap: () => Navigator.pushNamed(context, '/reporting'),
                              ),
                            ),
                          ],
                        );
                      }

                      return GridView.count(
                        crossAxisCount: constraints.maxWidth >= 600 ? 2 : 1,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 110,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          DashStatCard(
                            title: 'JUMLAH PENSYARAH',
                            value: '$_totalLecturers',
                            subtitle: 'Pensyarah jabatan',
                            icon: Icons.person,
                            iconColor: AppTheme.teal,
                          ),
                          DashStatCard(
                            title: 'UNIT PROGRAM',
                            value: '$_totalPrograms',
                            subtitle: 'Unit program aktif',
                            icon: Icons.account_tree,
                            iconColor: AppTheme.navy,
                          ),
                          DashStatCard(
                            title: 'AMARAN TAHAP 2',
                            value: '$_level2Count',
                            subtitle: 'Kes tahap 2',
                            icon: Icons.warning,
                            iconColor: AppTheme.ck,
                            onTap: () => Navigator.pushNamed(context, '/reporting'),
                          ),
                          DashStatCard(
                            title: 'AMARAN TAHAP 3',
                            value: '$_level3Count',
                            subtitle: 'Kes tahap 3',
                            icon: Icons.error,
                            iconColor: AppTheme.tidakHadir,
                            onTap: () => Navigator.pushNamed(context, '/reporting'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      final escalated = _escalatedCases;
                      return isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          DashSectionHeader(
                                            title: 'Kes Eskalasi',
                                            actionLabel: 'Lihat Semua →',
                                            onAction: () => Navigator.pushNamed(
                                              context,
                                              '/reporting',
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          if (escalated.isEmpty)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.symmetric(vertical: 16),
                                              child: Center(
                                                child: Text(
                                                  'Tiada kes eskalasi aktif.',
                                                  style: TextStyle(
                                                    color: AppTheme.textMuted,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Column(
                                              children: escalated.map((item) {
                                                final percent = item['percent'] as double;
                                                final warningLevel =
                                                    item['warningLevel'] as int;
                                                final badgeColor = warningLevel == 3
                                                    ? AppTheme.tidakHadir
                                                    : AppTheme.ck;
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(
                                                      vertical: 8),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              item['name'] as String,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow.ellipsis,
                                                              style: const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight.w700,
                                                                color: AppTheme.navy,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              item['classId'] as String,
                                                              style: const TextStyle(
                                                                fontSize: 11,
                                                                color: AppTheme.textMuted,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '${percent.toStringAsFixed(1)}%',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w700,
                                                          color: badgeColor,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              badgeColor.withOpacity(0.15),
                                                          borderRadius:
                                                              BorderRadius.circular(20),
                                                        ),
                                                        child: Text(
                                                          _warningBadge(warningLevel),
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const Text(
                                            'Tindakan Pantas',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.navy,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          _quickAction(
                                            context,
                                            icon: Icons.bar_chart,
                                            label: 'Laporan Kehadiran',
                                            route: '/reporting',
                                            color: AppTheme.navy,
                                          ),
                                          const SizedBox(height: 8),
                                          _quickAction(
                                            context,
                                            icon: Icons.report_problem,
                                            label: 'Laporan Disiplin',
                                            route: '/discipline',
                                            color: AppTheme.mc,
                                          ),
                                          const SizedBox(height: 8),
                                          _quickAction(
                                            context,
                                            icon: Icons.meeting_room,
                                            label: 'Tempahan Bilik',
                                            route: '/booking',
                                            color: AppTheme.teal,
                                          ),
                                          const SizedBox(height: 8),
                                            SizedBox(
                                              height: 44,
                                              child: Stack(
                                                children: [
                                                  OutlinedButton.icon(
                                                    onPressed: _openUserManagement,
                                                    icon: const Icon(Icons.manage_accounts, size: 18, color: AppTheme.teal),
                                                    label: const Text('Sahkan Pengguna Baru'),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: AppTheme.navy,
                                                      side: const BorderSide(color: AppTheme.slateBorder),
                                                      alignment: Alignment.centerLeft,
                                                      minimumSize: const Size(double.infinity, 44),
                                                    ),
                                                  ),
                                                  if (_pendingCount > 0)
                                                    Positioned(
                                                      right: 12, top: 10,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                                        child: Text('$_pendingCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        DashSectionHeader(
                                          title: 'Kes Eskalasi',
                                          actionLabel: 'Lihat Semua →',
                                          onAction: () => Navigator.pushNamed(
                                            context,
                                            '/reporting',
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        if (escalated.isEmpty)
                                          const Padding(
                                            padding:
                                                EdgeInsets.symmetric(vertical: 16),
                                            child: Center(
                                              child: Text(
                                                'Tiada kes eskalasi aktif.',
                                                style: TextStyle(
                                                  color: AppTheme.textMuted,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Column(
                                            children: escalated.map((item) {
                                              final percent = item['percent'] as double;
                                              final warningLevel =
                                                  item['warningLevel'] as int;
                                              final badgeColor = warningLevel == 3
                                                  ? AppTheme.tidakHadir
                                                  : AppTheme.ck;
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(
                                                    vertical: 8),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            item['name'] as String,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight.w700,
                                                              color: AppTheme.navy,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            item['classId'] as String,
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              color: AppTheme.textMuted,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '${percent.toStringAsFixed(1)}%',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: badgeColor,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            badgeColor.withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(20),
                                                      ),
                                                      child: Text(
                                                        _warningBadge(warningLevel),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Text(
                                          'Tindakan Pantas',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.navy,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        _quickAction(
                                          context,
                                          icon: Icons.bar_chart,
                                          label: 'Laporan Kehadiran',
                                          route: '/reporting',
                                          color: AppTheme.navy,
                                        ),
                                        const SizedBox(height: 8),
                                        _quickAction(
                                          context,
                                          icon: Icons.report_problem,
                                          label: 'Laporan Disiplin',
                                          route: '/discipline',
                                          color: AppTheme.mc,
                                        ),
                                        const SizedBox(height: 8),
                                        _quickAction(
                                          context,
                                          icon: Icons.meeting_room,
                                          label: 'Tempahan Bilik',
                                          route: '/booking',
                                          color: AppTheme.teal,
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 44,
                                          child: Stack(
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: _openUserManagement,
                                                icon: const Icon(Icons.manage_accounts, size: 18, color: AppTheme.teal),
                                                label: const Text('Sahkan Pengguna Baru'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: AppTheme.navy,
                                                  side: const BorderSide(color: AppTheme.slateBorder),
                                                  alignment: Alignment.centerLeft,
                                                  minimumSize: const Size(double.infinity, 44),
                                                ),
                                              ),
                                            if (_pendingCount > 0)
                                              Positioned(
                                                right: 12, top: 10,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                                  child: Text('$_pendingCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
