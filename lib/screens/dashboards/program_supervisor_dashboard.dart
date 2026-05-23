// lib/screens/dashboards/program_supervisor_dashboard.dart
//
// Papan pemuka untuk Ketua Program.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/attendance_summary.dart';
import '../../providers/user_provider.dart';
import '../../services/reporting_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '_dashboard_shell.dart';

class ProgramSupervisorDashboardScreen extends StatefulWidget {
  const ProgramSupervisorDashboardScreen({super.key});

  @override
  State<ProgramSupervisorDashboardScreen> createState() =>
      _ProgramSupervisorDashboardScreenState();
}

class _ProgramSupervisorDashboardScreenState
    extends State<ProgramSupervisorDashboardScreen> {
  bool _loading = true;
  int _totalStudents = 0;
  int _below80Count = 0;
  int _activeWarnings = 0;
  int _totalClasses = 0;
  List<Map<String, dynamic>> _criticalStudents = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
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
      final studentQuery = client.from('students').select('id').eq('program_id', dept);
      final timetableQuery = client.from('timetable').select('id').eq('department_unit', dept);
      final summariesFuture = ReportingService().fetchAttendanceSummary(user);

      final studentRows = _rowsFrom(await studentQuery);
      final timetableRows = _rowsFrom(await timetableQuery);
      final summaries = await summariesFuture;

      final below80 = summaries.where((s) => s.attendancePercent < 80).toList();
      final activeWarnings = summaries.where((s) => s.warningLevel > 0).length;
      below80.sort((a, b) => a.attendancePercent.compareTo(b.attendancePercent));

      final critical = below80.take(5).map((summary) {
        return {
          'name': summary.studentName,
          'classId': summary.classId,
          'percent': summary.attendancePercent,
          'warningLevel': summary.warningLevel,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _totalStudents = studentRows.length;
          _totalClasses = timetableRows.length;
          _below80Count = below80.length;
          _activeWarnings = activeWarnings;
          _criticalStudents = critical;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _totalStudents = 0;
          _totalClasses = 0;
          _below80Count = 0;
          _activeWarnings = 0;
          _criticalStudents = [];
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
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/reporting'),
          icon: const Icon(Icons.bar_chart, size: 16),
          label: const Text('Laporan Penuh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.navy,
            side: const BorderSide(color: AppTheme.slateBorder),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/timetable-upload'),
          icon: const Icon(Icons.upload_file, size: 16),
          label: const Text('Muat Naik Jadual'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.teal,
            foregroundColor: Colors.white,
          ),
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
                    'Gambaran Program',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pantau kehadiran dan amaran pelajar program anda.',
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
                                title: 'JUMLAH PELAJAR',
                                value: '$_totalStudents',
                                subtitle: 'Dalam program anda',
                                icon: Icons.people,
                                iconColor: AppTheme.teal,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'JUMLAH KELAS',
                                value: '$_totalClasses',
                                subtitle: 'Entri jadual program',
                                icon: Icons.class_,
                                iconColor: AppTheme.navy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'PELAJAR BAWAH 80%',
                                value: '$_below80Count',
                                subtitle: 'Amaran kehadiran',
                                icon: Icons.warning_amber,
                                iconColor: AppTheme.mc,
                                onTap: () => Navigator.pushNamed(context, '/reporting'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'AMARAN AKTIF',
                                value: '$_activeWarnings',
                                subtitle: 'Amaran aktif',
                                icon: Icons.notifications_active,
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
                            title: 'JUMLAH PELAJAR',
                            value: '$_totalStudents',
                            subtitle: 'Dalam program anda',
                            icon: Icons.people,
                            iconColor: AppTheme.teal,
                          ),
                          DashStatCard(
                            title: 'JUMLAH KELAS',
                            value: '$_totalClasses',
                            subtitle: 'Entri jadual program',
                            icon: Icons.class_,
                            iconColor: AppTheme.navy,
                          ),
                          DashStatCard(
                            title: 'PELAJAR BAWAH 80%',
                            value: '$_below80Count',
                            subtitle: 'Amaran kehadiran',
                            icon: Icons.warning_amber,
                            iconColor: AppTheme.mc,
                            onTap: () => Navigator.pushNamed(context, '/reporting'),
                          ),
                          DashStatCard(
                            title: 'AMARAN AKTIF',
                            value: '$_activeWarnings',
                            subtitle: 'Amaran aktif',
                            icon: Icons.notifications_active,
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
                                            title: 'Pelajar Kritikal',
                                            actionLabel: 'Lihat Semua',
                                            onAction: () => Navigator.pushNamed(
                                              context,
                                              '/reporting',
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          if (_criticalStudents.isEmpty)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.symmetric(vertical: 16),
                                              child: Center(
                                                child: Text(
                                                  'Tiada pelajar bawah 80%.',
                                                  style: TextStyle(
                                                    color: AppTheme.textMuted,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Column(
                                              children: _criticalStudents.map((item) {
                                                final percent = item['percent'] as double;
                                                final color = percent >= 60
                                                    ? AppTheme.mc
                                                    : AppTheme.tidakHadir;
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
                                                          color: color,
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
                                                          color: color.withOpacity(0.15),
                                                          borderRadius:
                                                              BorderRadius.circular(20),
                                                        ),
                                                        child: Text(
                                                          _warningBadge(
                                                              item['warningLevel'] as int),
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
                                            icon: Icons.calendar_month,
                                            label: 'Jadual Waktu',
                                            route: '/timetable',
                                            color: AppTheme.teal,
                                          ),
                                          const SizedBox(height: 8),
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
                                          title: 'Pelajar Kritikal',
                                          actionLabel: 'Lihat Semua',
                                          onAction: () => Navigator.pushNamed(
                                            context,
                                            '/reporting',
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        if (_criticalStudents.isEmpty)
                                          const Padding(
                                            padding:
                                                EdgeInsets.symmetric(vertical: 16),
                                            child: Center(
                                              child: Text(
                                                'Tiada pelajar bawah 80%.',
                                                style: TextStyle(
                                                  color: AppTheme.textMuted,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Column(
                                            children: _criticalStudents.map((item) {
                                              final percent = item['percent'] as double;
                                              final color = percent >= 60
                                                  ? AppTheme.mc
                                                  : AppTheme.tidakHadir;
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
                                                        color: color,
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
                                                        color: color.withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(20),
                                                      ),
                                                      child: Text(
                                                        _warningBadge(
                                                            item['warningLevel'] as int),
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
                                          icon: Icons.calendar_month,
                                          label: 'Jadual Waktu',
                                          route: '/timetable',
                                          color: AppTheme.teal,
                                        ),
                                        const SizedBox(height: 8),
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
