// lib/screens/reporting_dashboard_screen.dart
//
// Modul 3: Papan Pemuka Pelaporan & Pemantauan Kehadiran.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/attendance_summary.dart';
import '../providers/user_provider.dart';
import '../services/reporting_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/summary_card.dart';

class ReportingDashboardScreen extends StatefulWidget {
  const ReportingDashboardScreen({super.key});

  @override
  State<ReportingDashboardScreen> createState() =>
      _ReportingDashboardScreenState();
}

class _ReportingDashboardScreenState extends State<ReportingDashboardScreen> {
  final _service = ReportingService();
  late Future<List<AttendanceSummary>> _summariesFuture;
  late Future<List<Map<String, dynamic>>> _notifFuture;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().profile!;
    _summariesFuture = _service.fetchAttendanceSummary(user);
    _notifFuture = _service.fetchWarningNotifications(user);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Pelaporan Kehadiran',
      actions: [
        IconButton(
          tooltip: 'Eksport PDF',
          icon: const Icon(Icons.picture_as_pdf),
          onPressed: () => _exportPdf(context),
        ),
      ],
      body: FutureBuilder<List<AttendanceSummary>>(
        future: _summariesFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Ralat: ${snap.error}'));
          }
          final summaries = snap.data ?? const [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow(summaries),
                const SizedBox(height: 16),
                _filters(),
                const SizedBox(height: 16),
                _notificationPanel(),
                const SizedBox(height: 16),
                _aiInsightPanel(summaries),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _trendChart()),
                    const SizedBox(width: 16),
                    Expanded(child: _breakdownChart(summaries)),
                  ],
                ),
                const SizedBox(height: 16),
                _classComparisonChart(summaries),
                const SizedBox(height: 16),
                _criticalStudentsTable(summaries),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryRow(List<AttendanceSummary> summaries) {
    final total = summaries.length;
    final overall = total == 0
        ? 0.0
        : summaries.map((s) => s.attendancePercent).reduce((a, b) => a + b) /
            total;
    final below80 = summaries.where((s) => s.attendancePercent < 80).length;
    final totalAbsent =
        summaries.fold<int>(0, (sum, s) => sum + s.totalAbsences);
    final warnings = summaries.where((s) => s.warningLevel > 0).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cross = width >= 1100
            ? 5
            : width >= 800
                ? 3
                : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: cross,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            SummaryCard(
              title: 'Jumlah Pelajar',
              value: '$total',
              icon: Icons.people,
            ),
            SummaryCard(
              title: 'Kehadiran Keseluruhan',
              value: '${overall.toStringAsFixed(1)}%',
              icon: Icons.percent,
              color: AppTheme.hadir,
            ),
            SummaryCard(
              title: 'Jumlah Ketidakhadiran',
              value: '$totalAbsent',
              icon: Icons.event_busy,
              color: AppTheme.tidakHadir,
            ),
            SummaryCard(
              title: 'Pelajar < 80%',
              value: '$below80',
              icon: Icons.warning_amber,
              color: AppTheme.mc,
            ),
            SummaryCard(
              title: 'Kes Amaran Aktif',
              value: '$warnings',
              icon: Icons.notifications_active,
              color: AppTheme.ck,
            ),
          ],
        );
      },
    );
  }

  Widget _filters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _filterDropdown('Semester', const ['2025/01', '2024/02']),
            _filterDropdown('Program', const ['DGS', 'DPP', 'DED']),
            _filterDropdown('Subjek', const ['DGS1013', 'DGS2023']),
            _filterDropdown('Pensyarah', const ['Pengguna Demo']),
            _filterDropdown('Seksyen', const ['DGS4A', 'DGS4B']),
            _filterDropdown('Julat Tarikh', const ['7 Hari', '30 Hari', 'Semester']),
          ],
        ),
      ),
    );
  }

  Widget _filterDropdown(String label, List<String> options) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (_) {},
      ),
    );
  }

  Widget _notificationPanel() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _notifFuture,
      builder: (context, snap) {
        final items = snap.data ?? const [];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications, color: AppTheme.navy),
                    const SizedBox(width: 8),
                    const Text(
                      'Amaran & Eskalasi',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: AppTheme.navy),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.tidakHadir,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${items.where((i) => i['is_read'] == false).length} belum dibaca',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Text('Tiada amaran semasa.',
                      style: TextStyle(color: AppTheme.textMuted))
                else
                  ...items.take(5).map((n) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.tidakHadir,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('L${n['warning_level']}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(n['message']?.toString() ?? '')),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _aiInsightPanel(List<AttendanceSummary> s) {
    final risky = s.where((x) => x.attendancePercent < 60).length;
    final insights = [
      '$risky pelajar berisiko tinggi dari segi kehadiran.',
      'Kehadiran menurun pada Minggu 5 berbanding Minggu 4.',
      'Seksyen DGS4A mencatat trend ketidakhadiran tertinggi.',
      'Subjek pagi mencatat kehadiran lebih baik berbanding subjek petang.',
      'Disyorkan menghantar surat amaran kepada kes Level 3.',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppTheme.teal),
                SizedBox(width: 8),
                Text(
                  'AI Insight (Simulasi)',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppTheme.navy),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...insights.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle, size: 6, color: AppTheme.teal),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _trendChart() {
    final spots = [
      const FlSpot(1, 92),
      const FlSpot(2, 88),
      const FlSpot(3, 85),
      const FlSpot(4, 83),
      const FlSpot(5, 78),
      const FlSpot(6, 80),
      const FlSpot(7, 82),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trend Kehadiran Mingguan',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 50,
                  maxY: 100,
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.teal,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.teal.withValues(alpha: 0.12),
                      ),
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownChart(List<AttendanceSummary> s) {
    int safe = 0, risk = 0, critical = 0;
    for (final x in s) {
      if (x.attendancePercent >= 80) {
        safe++;
      } else if (x.attendancePercent >= 60) {
        risk++;
      } else {
        critical++;
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pecahan Status Kehadiran',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  sections: [
                    PieChartSectionData(
                        value: safe.toDouble(),
                        color: AppTheme.hadir,
                        title: 'Selamat\n$safe',
                        radius: 60,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    PieChartSectionData(
                        value: risk.toDouble(),
                        color: AppTheme.mc,
                        title: 'Berisiko\n$risk',
                        radius: 60,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    PieChartSectionData(
                        value: critical.toDouble(),
                        color: AppTheme.tidakHadir,
                        title: 'Kritikal\n$critical',
                        radius: 60,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classComparisonChart(List<AttendanceSummary> s) {
    final groups = <String, List<double>>{};
    for (final x in s) {
      groups.putIfAbsent(x.classId, () => []).add(x.attendancePercent);
    }
    final entries = groups.entries.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Perbandingan Kelas',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  barGroups: List.generate(entries.length, (i) {
                    final list = entries[i].value;
                    final avg = list.reduce((a, b) => a + b) / list.length;
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: avg,
                        color: avg >= 80
                            ? AppTheme.hadir
                            : (avg >= 60 ? AppTheme.mc : AppTheme.tidakHadir),
                        width: 22,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ]);
                  }),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(entries[i].key,
                                style: const TextStyle(fontSize: 11)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _criticalStudentsTable(List<AttendanceSummary> s) {
    final sorted = [...s]
      ..sort((a, b) => a.attendancePercent.compareTo(b.attendancePercent));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Senarai Pelajar Kritikal',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Nama')),
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Kelas')),
                  DataColumn(label: Text('Kehadiran %')),
                  DataColumn(label: Text('Ketidakhadiran')),
                  DataColumn(label: Text('Level')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Surat Amaran')),
                ],
                rows: sorted.map((s) {
                  final color = s.attendancePercent >= 80
                      ? AppTheme.hadir
                      : (s.attendancePercent >= 60
                          ? AppTheme.mc
                          : AppTheme.tidakHadir);
                  return DataRow(cells: [
                    DataCell(Text(s.studentName)),
                    DataCell(Text(s.studentId)),
                    DataCell(Text(s.classId)),
                    DataCell(Text(
                      '${s.attendancePercent.toStringAsFixed(1)}%',
                      style: TextStyle(color: color, fontWeight: FontWeight.w700),
                    )),
                    DataCell(Text('${s.totalAbsences}')),
                    DataCell(Text('L${s.warningLevel}')),
                    DataCell(Text(s.riskStatus,
                        style: TextStyle(color: color, fontWeight: FontWeight.w700))),
                    DataCell(TextButton(
                      onPressed: () => _previewLetter(s),
                      child: const Text('Pratonton'),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _previewLetter(AttendanceSummary s) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pratonton Surat Amaran'),
        content: SingleChildScrollView(
          child: Text(
            'Kepada ${s.studentName} (${s.studentId})\n\n'
            'Anda mencatatkan kehadiran ${s.attendancePercent.toStringAsFixed(1)}% '
            'dengan ${s.totalAbsences} ketidakhadiran. Amaran Tahap ${s.warningLevel} '
            'telah dikeluarkan. Sila mengambil tindakan segera.\n\n'
            '— IKM Johor Bahru',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF surat amaran dijana (stub).')),
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Jana PDF'),
          ),
        ],
      ),
    );
  }

  void _exportPdf(BuildContext context) {
    final ts = DateFormat('d MMM yyyy HH:mm', 'ms').format(DateTime.now());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Laporan PDF dijana ($ts).')),
    );
  }
}
