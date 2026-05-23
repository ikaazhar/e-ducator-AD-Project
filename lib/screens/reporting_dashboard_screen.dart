// lib/screens/reporting_dashboard_screen.dart
//
// Modul 3: Pelaporan & Pemantauan Kehadiran.
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
  List<AttendanceSummary> _summaries = [];
  List<Map<String, dynamic>> _sessionTrend = [];
  List<Map<String, dynamic>> _availableClasses = [];
  bool _loading = true;
  bool _reloading = false;
  String? _selectedTimetableId;
  String? _selectedSemester;
  String? _selectedProgram;
  String? _selectedSubject;
  String? _selectedSection;
  String? _selectedSubjectLabel;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final List<String> _semesterOptions = ['2024/01', '2024/02', '2025/01'];
  final List<String> _programOptions = ['DGS', 'DPP', 'DED'];
  final List<String> _subjectOptions = ['DGS1013', 'DGS2023', 'DGS3033'];
  final List<String> _sectionOptions = ['DGS4A', 'DGS4B', 'DGS4C'];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Laporan Kehadiran',
      actions: [
        IconButton(
          tooltip: 'Eksport Laporan PDF',
          icon: const Icon(Icons.picture_as_pdf),
          onPressed: () => _exportPdf(context),
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
                  _filters(),
                  if (_reloading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(color: AppTheme.teal),
                    ),
                  const SizedBox(height: 24),
                  _summaryCards(),
                  const SizedBox(height: 24),
                  _aiInsightPanel(),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _trendChart()),
                      const SizedBox(width: 16),
                      Expanded(child: _statusPieChart()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _classComparisonChart(),
                  const SizedBox(height: 24),
                  _criticalStudentsTable(),
                ],
              ),
            ),
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
            _semesterDropdown(),
            _programDropdown(),
            _subjectDropdown(),
            _sectionDropdown(),
            _dateFilterButton(
              label: _dateFrom == null
                  ? 'Tarikh Dari'
                  : DateFormat('d MMM yyyy', 'ms').format(_dateFrom!),
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: _dateFrom ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('ms'),
                );
                if (selected != null) {
                  setState(() => _dateFrom = selected);
                  await _reloadData();
                }
              },
            ),
            _dateFilterButton(
              label: _dateTo == null
                  ? 'Tarikh Hingga'
                  : DateFormat('d MMM yyyy', 'ms').format(_dateTo!),
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: _dateTo ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('ms'),
                );
                if (selected != null) {
                  setState(() => _dateTo = selected);
                  await _reloadData();
                }
              },
            ),
            if (_selectedTimetableId != null ||
                _selectedSemester != null ||
                _selectedProgram != null ||
                _selectedSubject != null ||
                _selectedSection != null ||
                _dateFrom != null ||
                _dateTo != null)
              TextButton.icon(
                onPressed: () async {
                  setState(() {
                    _selectedTimetableId = null;
                    _selectedSemester = null;
                    _selectedProgram = null;
                    _selectedSubject = null;
                    _selectedSection = null;
                    _selectedSubjectLabel = null;
                    _dateFrom = null;
                    _dateTo = null;
                  });
                  await _reloadData();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Set Semula'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateFilterButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(label),
      onPressed: onPressed,
    );
  }

  Widget _dropdownFilter({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280, minWidth: 140),
      child: DropdownButtonFormField<String?>(
        decoration: InputDecoration(labelText: label),
        value: value,
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('Semua $label'),
          ),
          ...options.map((option) => DropdownMenuItem(
                value: option,
                child: Text(option),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _semesterDropdown() {
    return _dropdownFilter(
      label: 'Semester',
      value: _selectedSemester,
      options: _semesterOptions,
      onChanged: (value) async {
        setState(() => _selectedSemester = value);
        await _reloadData();
      },
    );
  }

  Widget _programDropdown() {
    return _dropdownFilter(
      label: 'Program',
      value: _selectedProgram,
      options: _programOptions,
      onChanged: (value) async {
        setState(() => _selectedProgram = value);
        await _reloadData();
      },
    );
  }

  Widget _subjectDropdown() {
    return _dropdownFilter(
      label: 'Subjek',
      value: _selectedSubject,
      options: _subjectOptions,
      onChanged: (value) async {
        setState(() => _selectedSubject = value);
        await _reloadData();
      },
    );
  }

  Widget _sectionDropdown() {
    return _dropdownFilter(
      label: 'Seksion',
      value: _selectedSection,
      options: _sectionOptions,
      onChanged: (value) async {
        setState(() => _selectedSection = value);
        await _reloadData();
      },
    );
  }

  Widget _summaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxis = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 700
                ? 3
                : 2;
        final cards = [
          SummaryCard(
            title: 'Jumlah Pelajar',
            value: '$_totalStudents',
            icon: Icons.people,
          ),
          SummaryCard(
            title: 'Kehadiran Keseluruhan',
            value: '${_overallPercent.toStringAsFixed(1)}%',
            icon: Icons.percent,
            color: AppTheme.hadir,
          ),
          SummaryCard(
            title: 'Jumlah Tak Hadir',
            value: '$_totalAbsences',
            icon: Icons.event_busy,
            color: AppTheme.tidakHadir,
          ),
          SummaryCard(
            title: 'Pelajar Bawah 80%',
            value: '$_below80Count',
            icon: Icons.warning_amber,
            color: AppTheme.mc,
          ),
          SummaryCard(
            title: 'Kes Amaran Aktif',
            value: '$_activeWarnings',
            icon: Icons.notifications_active,
            color: AppTheme.ck,
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxis,
            mainAxisExtent: 150,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }

  Widget _aiInsightPanel() {
    return Card(
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppTheme.teal, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wawasan AI (Simulasi)',
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy),
                        ),
                        if (_selectedSubjectLabel != null)
                          Text(
                            _selectedSubjectLabel!,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._insights.map(
                (insight) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle, size: 6, color: AppTheme.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          insight,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trendChart() {
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
              height: 240,
              child: _sessionTrend.isEmpty
                  ? const Center(
                      child: Text(
                        'Tiada data sesi direkodkan lagi.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: 100,
                        lineTouchData: LineTouchData(enabled: false),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        extraLinesData: ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: 80,
                              color: AppTheme.tidakHadir,
                              strokeWidth: 1.5,
                              dashArray: [6, 4],
                              label: HorizontalLineLabel(
                                show: true,
                                labelResolver: (_) => '80%',
                                style: const TextStyle(
                                  color: AppTheme.tidakHadir,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= _sessionTrend.length) {
                                  return const SizedBox.shrink();
                                }
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text('M${index + 1}', style: const TextStyle(fontSize: 11)),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _sessionTrend.asMap().entries.map((entry) {
                              final row = entry.value;
                              final hadir = row['hadir'] as int? ?? 0;
                              final takHadir = row['takHadir'] as int? ?? 0;
                              final total = hadir + takHadir;
                              final y = total == 0 ? 100.0 : (hadir / total) * 100.0;
                              return FlSpot(entry.key.toDouble(), y);
                            }).toList(),
                            isCurved: true,
                            color: AppTheme.teal,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppTheme.teal.withOpacity(0.1),
                            ),
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

  Widget _statusPieChart() {
    final totals = _statusTotals;
    final hasData = totals.values.any((value) => value > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Taburan Status Kehadiran',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: hasData
                  ? PieChart(
                      PieChartData(
                        sections: [
                          if (totals['hadir']! > 0)
                            PieChartSectionData(
                              value: totals['hadir']!.toDouble(),
                              color: AppTheme.hadir,
                              title: 'Hadir\n${totals['hadir']}',
                              radius: 60,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (totals['takHadir']! > 0)
                            PieChartSectionData(
                              value: totals['takHadir']!.toDouble(),
                              color: AppTheme.tidakHadir,
                              title: 'Tak Hadir\n${totals['takHadir']}',
                              radius: 60,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (totals['mc']! > 0)
                            PieChartSectionData(
                              value: totals['mc']!.toDouble(),
                              color: AppTheme.mc,
                              title: 'MC\n${totals['mc']}',
                              radius: 60,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (totals['ck']! > 0)
                            PieChartSectionData(
                              value: totals['ck']!.toDouble(),
                              color: AppTheme.ck,
                              title: 'CK\n${totals['ck']}',
                              radius: 60,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                        centerSpaceRadius: 36,
                        sectionsSpace: 2,
                        borderData: FlBorderData(show: false),
                        pieTouchData: PieTouchData(enabled: false),
                      ),
                    )
                  : const Center(
                      child: Text(
                        'Tiada data kehadiran lagi.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classComparisonChart() {
    final selected = _selectedTimetableId != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Perbandingan Kehadiran Pelajar',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy),
            ),
            const SizedBox(height: 12),
            if (!selected)
              Container(
                height: 120,
                alignment: Alignment.center,
                child: const Text(
                  'Pilih kelas untuk melihat carta perbandingan pelajar.',
                  style: TextStyle(color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_filtered.isEmpty)
              Container(
                height: 120,
                alignment: Alignment.center,
                child: const Text(
                  'Tiada data pelajar untuk kelas ini.',
                  style: TextStyle(color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    maxY: 100,
                    barGroups: _filtered.asMap().entries.map((entry) {
                      final summary = entry.value;
                      final color = summary.attendancePercent >= 80
                          ? AppTheme.hadir
                          : summary.attendancePercent >= 60
                              ? AppTheme.mc
                              : AppTheme.tidakHadir;
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: summary.attendancePercent,
                            color: color,
                            width: 18,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= _filtered.length) {
                              return const SizedBox.shrink();
                            }
                            final name = _filtered[index].studentName.split(' ').first;
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(name, style: const TextStyle(fontSize: 10)),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: 80,
                          color: AppTheme.tidakHadir,
                          strokeWidth: 1.5,
                          dashArray: [6, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            labelResolver: (_) => '80%',
                            style: const TextStyle(
                              color: AppTheme.tidakHadir,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _criticalStudentsTable() {
    final criticalList = _filtered.where((s) => s.attendancePercent < 80).toList()
      ..sort((a, b) => a.attendancePercent.compareTo(b.attendancePercent));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Senarai Pelajar Kritikal',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (_below80Count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.tidakHadir,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_below80Count pelajar',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (criticalList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Tiada pelajar di bawah 80% untuk skop semasa.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      const MaterialStatePropertyAll(AppTheme.slate),
                  columns: const [
                    DataColumn(label: Text('Nama Pelajar')),
                    DataColumn(label: Text('ID Pelajar')),
                    DataColumn(label: Text('Kelas')),
                    DataColumn(label: Text('Kehadiran %')),
                    DataColumn(label: Text('Jumlah Tak Hadir')),
                    DataColumn(label: Text('Tahap Amaran')),
                    DataColumn(label: Text('Status Risiko')),
                    DataColumn(label: Text('Tren Terkini')),
                    DataColumn(label: Text('Surat Amaran')),
                  ],
                  rows: criticalList.map((summary) {
                    final pctColor = summary.attendancePercent >= 60
                        ? AppTheme.mc
                        : AppTheme.tidakHadir;
                    Widget trendIcon;
                    if (_sessionTrend.length >= 2) {
                      final last = _sessionTrend[_sessionTrend.length - 1];
                      final prev = _sessionTrend[_sessionTrend.length - 2];
                      double pct(Map<String, dynamic> row) {
                        final hadir = row['hadir'] as int? ?? 0;
                        final takHadir = row['takHadir'] as int? ?? 0;
                        final total = hadir + takHadir;
                        return total == 0 ? 100.0 : (hadir / total) * 100.0;
                      }
                      if (pct(last) > pct(prev)) {
                        trendIcon = const Icon(Icons.trending_up,
                            color: AppTheme.hadir, size: 18);
                      } else if (pct(last) < pct(prev)) {
                        trendIcon = const Icon(Icons.trending_down,
                            color: AppTheme.tidakHadir, size: 18);
                      } else {
                        trendIcon = const Icon(Icons.trending_flat,
                            color: AppTheme.textMuted, size: 18);
                      }
                    } else {
                      trendIcon = const Icon(Icons.trending_flat,
                          color: AppTheme.textMuted, size: 18);
                    }
                    return DataRow(cells: [
                      DataCell(Text(
                        summary.studentName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )),
                      DataCell(Text(
                        summary.studentId,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      )),
                      DataCell(Text(summary.classId)),
                      DataCell(Text(
                        '${summary.attendancePercent.toStringAsFixed(1)}%',
                        style: TextStyle(color: pctColor, fontWeight: FontWeight.w700),
                      )),
                      DataCell(Text('${summary.totalAbsences}')),
                      DataCell(_warningLevelBadge(summary.warningLevel)),
                      DataCell(Text(
                        summary.riskStatus,
                        style: TextStyle(color: pctColor, fontWeight: FontWeight.w600),
                      )),
                      DataCell(trendIcon),
                      DataCell(TextButton(
                        onPressed: () => _previewLetter(context, summary),
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

  Widget _warningLevelBadge(int level) {
    final color = level == 1
        ? AppTheme.mc
        : level == 2
            ? AppTheme.ck
            : level == 3
                ? AppTheme.tidakHadir
                : AppTheme.textMuted;
    final label = level == 0 ? 'Tiada' : 'Tahap $level';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _previewLetter(BuildContext context, AttendanceSummary summary) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Surat Amaran Kehadiran',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SURAT AMARAN KEHADIRAN',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                      fontSize: 15,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  _letterRow('Kepada', summary.studentName),
                  _letterRow('ID Pelajar', summary.studentId),
                  _letterRow('Kelas', summary.classId),
                  _letterRow(
                    'Tarikh',
                    DateFormat('d MMMM yyyy', 'ms').format(DateTime.now()),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Dengan hormatnya perkara di atas dirujuk.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Adalah dimaklumkan bahawa kehadiran anda ke sesi pembelajaran bagi kelas ${summary.classId} adalah sebanyak ${summary.attendancePercent.toStringAsFixed(1)}%, iaitu di bawah had minimum yang ditetapkan iaitu 80%.',
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 10),
                  _letterRow('Jumlah Ketidakhadiran', '${summary.totalAbsences} sesi'),
                  _letterRow('Tahap Amaran', 'Level ${summary.warningLevel}'),
                  _letterRow('Status Risiko', summary.riskStatus),
                  const SizedBox(height: 10),
                  const Text(
                    'Anda dikehendaki mengambil tindakan segera bagi memperbaiki kehadiran anda. Kegagalan berbuat demikian boleh menjejaskan kelayakan anda untuk menduduki peperiksaan akhir semester.',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  const Text('Sekian, terima kasih.', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  const Text(
                    'Pihak Pengurusan Akademik',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const Text('IKM Johor Bahru', style: TextStyle(fontSize: 13)),
                  const Divider(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Jana PDF'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PDF surat amaran dijana (stub).'),
                    backgroundColor: AppTheme.navy,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Padding _letterRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              '$label :',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
    });

    final user = context.read<UserProvider>().profile;
    if (user == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    final classes = await _service.fetchAvailableClasses(user);
    final summaries = await _service.fetchAttendanceSummary(
      user,
      timetableId: _selectedTimetableId,
      semester: _selectedSemester,
      programId: _selectedProgram,
      subjectCode: _selectedSubject,
      section: _selectedSection,
      dateFrom: _dateFrom?.toIso8601String().substring(0, 10),
      dateTo: _dateTo?.toIso8601String().substring(0, 10),
    );
    final sessionTrend = await _service.fetchRawSessionTrend(
      user,
      timetableId: _selectedTimetableId,
      semester: _selectedSemester,
      programId: _selectedProgram,
      subjectCode: _selectedSubject,
      section: _selectedSection,
      dateFrom: _dateFrom?.toIso8601String().substring(0, 10),
      dateTo: _dateTo?.toIso8601String().substring(0, 10),
    );

    if (!mounted) return;
    setState(() {
      _availableClasses = classes;
      _summaries = summaries;
      _sessionTrend = sessionTrend;
      _loading = false;
    });
  }

  Future<void> _reloadData() async {
    setState(() {
      _reloading = true;
    });

    final user = context.read<UserProvider>().profile;
    if (user == null) {
      setState(() {
        _reloading = false;
      });
      return;
    }

    final summaries = await _service.fetchAttendanceSummary(
      user,
      timetableId: _selectedTimetableId,
      semester: _selectedSemester,
      programId: _selectedProgram,
      subjectCode: _selectedSubject,
      section: _selectedSection,
      dateFrom: _dateFrom?.toIso8601String().substring(0, 10),
      dateTo: _dateTo?.toIso8601String().substring(0, 10),
    );
    final sessionTrend = await _service.fetchRawSessionTrend(
      user,
      timetableId: _selectedTimetableId,
      semester: _selectedSemester,
      programId: _selectedProgram,
      subjectCode: _selectedSubject,
      section: _selectedSection,
      dateFrom: _dateFrom?.toIso8601String().substring(0, 10),
      dateTo: _dateTo?.toIso8601String().substring(0, 10),
    );

    if (!mounted) return;
    setState(() {
      _summaries = summaries;
      _sessionTrend = sessionTrend;
      _reloading = false;
    });
  }

  List<AttendanceSummary> get _filtered {
    final role = context.watch<UserProvider>().profile?.role ?? '';
    if (role == 'Timbalan Pengarah Akademik') {
      return _summaries.where((s) => s.warningLevel == 3).toList();
    }
    return _summaries;
  }

  int get _totalStudents => _filtered.length;

  double get _overallPercent {
    if (_filtered.isEmpty) return 0.0;
    return _filtered.map((s) => s.attendancePercent).reduce((a, b) => a + b) /
        _filtered.length;
  }

  int get _totalAbsences =>
      _filtered.fold(0, (sum, s) => sum + s.totalAbsences);

  int get _below80Count =>
      _filtered.where((s) => s.attendancePercent < 80).length;

  int get _activeWarnings =>
      _filtered.where((s) => s.warningLevel > 0).length;

  Map<String, int> get _statusTotals {
    final totals = {'hadir': 0, 'takHadir': 0, 'mc': 0, 'ck': 0};
    for (final row in _sessionTrend) {
      totals['hadir'] = totals['hadir']! + (row['hadir'] as int? ?? 0);
      totals['takHadir'] = totals['takHadir']! + (row['takHadir'] as int? ?? 0);
      totals['mc'] = totals['mc']! + (row['mc'] as int? ?? 0);
      totals['ck'] = totals['ck']! + (row['ck'] as int? ?? 0);
    }
    return totals;
  }

  List<String> get _insights {
    final insights = <String>[];
    final highRiskCount = _filtered.where((s) => s.attendancePercent < 60).length;
    if (highRiskCount > 0) {
      insights.add('$highRiskCount pelajar berisiko tinggi dari segi kehadiran.');
    }

    if (_sessionTrend.isNotEmpty) {
      final trendWithPercent = _sessionTrend.map((row) {
        final hadir = row['hadir'] as int? ?? 0;
        final takHadir = row['takHadir'] as int? ?? 0;
        final total = hadir + takHadir;
        final percent = total == 0 ? 100.0 : (hadir / total) * 100.0;
        return {'date': row['date'] as String, 'percent': percent};
      }).toList();

      final lowest = trendWithPercent.reduce((a, b) =>
          (a['percent'] as double) < (b['percent'] as double) ? a : b);
      if ((lowest['percent'] as double) < 80) {
        final index = trendWithPercent.indexOf(lowest);
        insights.add(
          'Kehadiran paling rendah pada Minggu ${index + 1} (${(lowest['percent'] as double).toStringAsFixed(1)}%).',
        );
      }
    }

    if (_overallPercent >= 90 && _totalStudents > 0) {
      insights.add(
        'Prestasi cemerlang — kehadiran keseluruhan ${_overallPercent.toStringAsFixed(1)}%.',
      );
    }

    if (_statusTotals['mc']! > _statusTotals['takHadir']! && _statusTotals['mc']! > 0) {
      insights.add('Kebanyakan ketidakhadiran disertai MC (${_statusTotals['mc']} kes).');
    }

    final level3Count = _filtered.where((s) => s.warningLevel == 3).length;
    if (level3Count > 0) {
      insights.add('Disyorkan menghantar surat amaran kepada $level3Count pelajar Tahap 3.');
    }

    if (insights.isEmpty) {
      insights.add('Tiada isu kritikal dikesan untuk skop semasa.');
    }

    return insights;
  }

  void _exportPdf(BuildContext context) {
    final ts = DateFormat('d MMM yyyy HH:mm', 'ms').format(DateTime.now());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Laporan PDF sedang dijana ($ts). Sila tunggu...'),
        backgroundColor: AppTheme.navy,
      ),
    );
  }
}
