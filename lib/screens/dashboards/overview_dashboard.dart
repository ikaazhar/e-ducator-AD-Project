// lib/screens/dashboards/overview_dashboard.dart
//
// Papan pemuka untuk Timbalan Pengarah Akademik (gambaran institusi).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/attendance_summary.dart';
import '../../providers/user_provider.dart';
import '../../services/reporting_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '_dashboard_shell.dart';

class OverviewDashboardScreen extends StatefulWidget {
  const OverviewDashboardScreen({super.key});

  @override
  State<OverviewDashboardScreen> createState() =>
      _OverviewDashboardScreenState();
}

class _OverviewDashboardScreenState extends State<OverviewDashboardScreen> {
  bool _loading = true;
  int _level3Count = 0;
  int _totalDepts = 0;
  int _totalStudents = 0;
  double _overallRate = 0.0;
  List<Map<String, dynamic>> _criticalCases = [];

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

    try {
      final studentsFuture = client.from('students').select('id');
      final timetableFuture = client.from('timetable').select('department_unit');
      final summariesFuture = ReportingService().fetchAttendanceSummary(user);

      final studentRows = _rowsFrom(await studentsFuture);
      final timetableRows = _rowsFrom(await timetableFuture);
      final summaries = await summariesFuture;

      final departments = <String>{};
      for (final row in timetableRows) {
        final unit = row['department_unit']?.toString() ?? '';
        if (unit.isNotEmpty) departments.add(unit);
      }

      final level3 = summaries.where((s) => s.warningLevel == 3).toList();
      final overallRate = summaries.isEmpty
          ? 0.0
          : summaries.map((s) => s.attendancePercent).reduce((a, b) => a + b) /
              summaries.length;

      level3.sort((a, b) => a.attendancePercent.compareTo(b.attendancePercent));

      final critical = level3.take(5).map((summary) {
        return {
          'name': summary.studentName,
          'classId': summary.classId,
          'percent': summary.attendancePercent,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _totalStudents = studentRows.length;
          _totalDepts = departments.length;
          _level3Count = level3.length;
          _overallRate = overallRate;
          _criticalCases = critical;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _totalStudents = 0;
          _totalDepts = 0;
          _level3Count = 0;
          _overallRate = 0.0;
          _criticalCases = [];
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
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/reporting'),
          icon: const Icon(Icons.bar_chart, size: 16),
          label: const Text('Laporan Kritikal'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.tidakHadir,
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
                    'Gambaran Akademik',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hanya kes Level 3 dipaparkan untuk semakan anda.',
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
                                subtitle: 'Dalam sistem',
                                icon: Icons.people,
                                iconColor: AppTheme.teal,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'JABATAN AKTIF',
                                value: '$_totalDepts',
                                subtitle: 'Unit program aktif',
                                icon: Icons.business,
                                iconColor: AppTheme.navy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'KADAR KEHADIRAN',
                                value: '${_overallRate.toStringAsFixed(1)}%',
                                subtitle: 'Purata institusi',
                                icon: Icons.percent,
                                iconColor: AppTheme.hadir,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'KES KRITIKAL L3',
                                value: '$_level3Count',
                                subtitle: 'Level 3 sahaja',
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
                            title: 'JUMLAH PELAJAR',
                            value: '$_totalStudents',
                            subtitle: 'Dalam sistem',
                            icon: Icons.people,
                            iconColor: AppTheme.teal,
                          ),
                          DashStatCard(
                            title: 'JABATAN AKTIF',
                            value: '$_totalDepts',
                            subtitle: 'Unit program aktif',
                            icon: Icons.business,
                            iconColor: AppTheme.navy,
                          ),
                          DashStatCard(
                            title: 'KADAR KEHADIRAN',
                            value: '${_overallRate.toStringAsFixed(1)}%',
                            subtitle: 'Purata institusi',
                            icon: Icons.percent,
                            iconColor: AppTheme.hadir,
                          ),
                          DashStatCard(
                            title: 'KES KRITIKAL L3',
                            value: '$_level3Count',
                            subtitle: 'Level 3 sahaja',
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
                      final cases = _criticalCases;
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
                                            title: 'Kes Kritikal Tahap 3',
                                            actionLabel: 'Lihat Semua →',
                                            onAction: () => Navigator.pushNamed(
                                              context,
                                              '/reporting',
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          if (cases.isEmpty)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.symmetric(vertical: 16),
                                              child: Center(
                                                child: Text(
                                                  'Tiada kes kritikal Level 3.',
                                                  style: TextStyle(
                                                    color: AppTheme.textMuted,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Column(
                                              children: cases.map((item) {
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
                                                        '${(item['percent'] as double).toStringAsFixed(1)}%',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w700,
                                                          color: AppTheme.tidakHadir,
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
                                          title: 'Kes Kritikal Tahap 3',
                                          actionLabel: 'Lihat Semua →',
                                          onAction: () => Navigator.pushNamed(
                                            context,
                                            '/reporting',
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        if (cases.isEmpty)
                                          const Padding(
                                            padding:
                                                EdgeInsets.symmetric(vertical: 16),
                                            child: Center(
                                              child: Text(
                                                'Tiada kes kritikal Level 3.',
                                                style: TextStyle(
                                                  color: AppTheme.textMuted,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Column(
                                            children: cases.map((item) {
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
                                                      '${(item['percent'] as double).toStringAsFixed(1)}%',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppTheme.tidakHadir,
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
