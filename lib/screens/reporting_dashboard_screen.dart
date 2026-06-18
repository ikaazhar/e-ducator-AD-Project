// lib/screens/reporting_dashboard_screen.dart
//
// Modul 3: Pelaporan & Pemantauan Kehadiran.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  Map<String, Map<String, dynamic>> _warningLetterActions = {};
  List<String> _sessionOptions = [];
  List<String> _sectionOptions = [];
  bool _loading = true;
  bool _reloading = false;
  String? _selectedTimetableId;
  String? _selectedSession;
  String? _selectedSection;
  String? _selectedSubjectLabel;
  DateTime? _dateFrom;
  DateTime? _dateTo;

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
                  _chartSection(),
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
            _sessionDropdown(),
            _classDropdown(),
            _sectionDropdown(),
            _dateFilterButton(
              label: _dateLabel(_dateFrom, fallback: 'Tarikh Dari'),
              onPressed: () async {
                final today = _dateOnly(DateTime.now());
                final firstDate = DateTime(2020);
                final lastDate = _dateTo ?? today;
                final selected = await showDatePicker(
                  context: context,
                  initialDate: _boundedInitialDate(
                    _dateFrom ?? lastDate,
                    firstDate: firstDate,
                    lastDate: lastDate,
                  ),
                  firstDate: firstDate,
                  lastDate: lastDate,
                );
                if (selected != null) {
                  setState(() => _dateFrom = _dateOnly(selected));
                  await _reloadData();
                }
              },
            ),
            _dateFilterButton(
              label: _dateLabel(_dateTo, fallback: 'Tarikh Hingga'),
              onPressed: () async {
                final today = _dateOnly(DateTime.now());
                final firstDate = _dateFrom ?? DateTime(2020);
                final selected = await showDatePicker(
                  context: context,
                  initialDate: _boundedInitialDate(
                    _dateTo ?? today,
                    firstDate: firstDate,
                    lastDate: today,
                  ),
                  firstDate: firstDate,
                  lastDate: today,
                );
                if (selected != null) {
                  setState(() => _dateTo = _dateOnly(selected));
                  await _reloadData();
                }
              },
            ),
            if (_selectedTimetableId != null ||
                _selectedSession != null ||
                _selectedSection != null ||
                _dateFrom != null ||
                _dateTo != null)
              TextButton.icon(
                onPressed: () async {
                  setState(() {
                    _selectedTimetableId = null;
                    _selectedSession = null;
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

  Widget _sessionDropdown() {
    return _dropdownFilter(
      label: 'Sesi',
      value: _selectedSession,
      options: _sessionOptions,
      onChanged: (value) async {
        setState(() => _selectedSession = value);
        await _reloadData();
      },
    );
  }

  Widget _classDropdown() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320, minWidth: 180),
      child: DropdownButtonFormField<String?>(
        decoration: const InputDecoration(labelText: 'Subjek'),
        isExpanded: true,
        value: _selectedTimetableId,
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Semua Subjek'),
          ),
          ..._availableClasses.map((item) {
            final id = item['timetableId']?.toString();
            return DropdownMenuItem<String?>(
              value: id,
              child: Text(
                item['label']?.toString() ?? id ?? '',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
        onChanged: (value) async {
          final selected = _availableClasses.cast<Map<String, dynamic>?>().firstWhere(
                (item) => item?['timetableId']?.toString() == value,
                orElse: () => null,
              );
          setState(() {
            _selectedTimetableId = value;
            _selectedSubjectLabel = selected?['label']?.toString();
          });
          await _reloadData();
        },
      ),
    );
  }

  Widget _sectionDropdown() {
    return _dropdownFilter(
      label: 'Seksyen',
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
            ? 4
            : constraints.maxWidth >= 700
                ? 2
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
                          'Ringkasan Automatik',
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

  Widget _chartSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              _trendChart(),
              const SizedBox(height: 16),
              _statusPieChart(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _trendChart()),
            const SizedBox(width: 16),
            Expanded(child: _statusPieChart()),
          ],
        );
      },
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
              'Trend Kehadiran Mengikut Tarikh',
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
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (spots) {
                              return spots.map((spot) {
                                final index = spot.x.toInt();
                                if (index < 0 || index >= _sessionTrend.length) {
                                  return null;
                                }
                                final row = _sessionTrend[index];
                                final hadir = row['hadir'] as int? ?? 0;
                                final takHadir = row['takHadir'] as int? ?? 0;
                                final date = _trendDateLabel(
                                  row['date']?.toString(),
                                );
                                return LineTooltipItem(
                                  '$date\n${spot.y.toStringAsFixed(1)}%\n'
                                  'Hadir: $hadir | Tak Hadir: $takHadir',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }).toList();
                            },
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
                                  child: Text(
                                    _trendDateLabel(_sessionTrend[index]['date']?.toString()),
                                    style: const TextStyle(fontSize: 11),
                                  ),
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
                  ? Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sections: [
                                if (totals['hadir']! > 0)
                                  _statusPieSection(
                                    value: totals['hadir']!,
                                    color: AppTheme.hadir,
                                  ),
                                if (totals['takHadir']! > 0)
                                  _statusPieSection(
                                    value: totals['takHadir']!,
                                    color: AppTheme.tidakHadir,
                                  ),
                                if (totals['mc']! > 0)
                                  _statusPieSection(
                                    value: totals['mc']!,
                                    color: AppTheme.mc,
                                  ),
                                if (totals['ck']! > 0)
                                  _statusPieSection(
                                    value: totals['ck']!,
                                    color: AppTheme.ck,
                                  ),
                              ],
                              centerSpaceRadius: 42,
                              sectionsSpace: 2,
                              borderData: FlBorderData(show: false),
                              pieTouchData: PieTouchData(enabled: false),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _statusLegend('Hadir', totals['hadir']!, AppTheme.hadir),
                              _statusLegend(
                                'Tak Hadir',
                                totals['takHadir']!,
                                AppTheme.tidakHadir,
                              ),
                              _statusLegend('MC', totals['mc']!, AppTheme.mc),
                              _statusLegend('CK', totals['ck']!, AppTheme.ck),
                            ],
                          ),
                        ),
                      ],
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

  PieChartSectionData _statusPieSection({
    required int value,
    required Color color,
  }) {
    return PieChartSectionData(
      value: value.toDouble(),
      color: color,
      title: value.toString(),
      radius: 62,
      titleStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _statusLegend(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _criticalStudentsTable() {
    final criticalList = [..._warningStudents]
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
                  'Senarai Pelajar Amaran',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                    fontSize: 15,
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
                    'Tiada pelajar amaran untuk skop semasa.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        headingRowColor:
                            const MaterialStatePropertyAll(AppTheme.slate),
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 72,
                        columns: const [
                          DataColumn(label: Text('Nama Pelajar')),
                          DataColumn(label: Text('ID Pelajar')),
                          DataColumn(label: Text('Kelas')),
                          DataColumn(label: Center(child: Text('Kehadiran %'))),
                          DataColumn(label: Center(child: Text('Jumlah Tak Hadir'))),
                          DataColumn(label: Center(child: Text('Tahap Amaran'))),
                          DataColumn(label: Text('Status Tindakan')),
                        ],
                        rows: criticalList.asMap().entries.map((entry) {
                          final summary = entry.value;
                          final pctColor = summary.attendancePercent >= 60
                              ? AppTheme.mc
                              : AppTheme.tidakHadir;
                          return DataRow(cells: [
                            DataCell(Text(
                              '${entry.key + 1}. ${summary.studentName}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            )),
                            DataCell(Text(
                              summary.studentId,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            )),
                            DataCell(Text(summary.classId)),
                            DataCell(Center(
                              child: Text(
                                '${summary.attendancePercent.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: pctColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )),
                            DataCell(Center(child: Text('${summary.totalAbsences}'))),
                            DataCell(Center(
                              child: _warningLevelBadge(summary.warningLevel),
                            )),
                            DataCell(_warningLetterStatusCell(summary)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  );
                },
              ), 
          ],
        ),
      ),
    );
  }

  Widget _warningLetterStatusCell(AttendanceSummary summary) {
    final action = _warningLetterActions[summary.studentId];
    final status = action?['status']?.toString();
    final isSent = status == 'sent';
    final user = context.watch<UserProvider>().profile;
    final canMarkSent = user?.role == 'Ketua Program';

    if (isSent) {
      return _sentWarningLetterStatus(action);
    }

    if (canMarkSent) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.check_circle_outline, size: 16),
        label: const Text('Tanda Tindakan Selesai'),
        onPressed: () => _confirmWarningLetterSent(summary),
      );
    }

    return _statusChip(
      label: 'Belum Dikemaskini',
      color: AppTheme.textMuted,
      icon: Icons.schedule,
    );
  }

  Widget _sentWarningLetterStatus(Map<String, dynamic>? action) {
    final sentBy = action?['sent_by_name']?.toString().trim();
    final sentAt = DateTime.tryParse(action?['sent_at']?.toString() ?? '');
    final dateLabel =
        sentAt == null ? null : DateFormat('d MMM yyyy', 'ms').format(sentAt.toLocal());

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 170, maxWidth: 230),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _statusChip(
            label: 'Telah Dikemaskini',
            color: AppTheme.hadir,
            icon: Icons.verified,
          ),
          if ((sentBy != null && sentBy.isNotEmpty) || dateLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (sentBy != null && sentBy.isNotEmpty) 'oleh $sentBy',
                  if (dateLabel != null) dateLabel,
                ].join(' • '),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

  Future<void> _confirmWarningLetterSent(AttendanceSummary summary) async {
    final user = context.read<UserProvider>().profile;
    if (user == null || user.role != 'Ketua Program') return;

    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Sahkan Status Tindakan',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adakah tindakan susulan bagi pelajar ini telah diselesaikan?',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                _letterRow('Nama Pelajar', summary.studentName),
                _letterRow('ID Pelajar', summary.studentId),
                _letterRow('Kelas', summary.classId),
                _letterRow(
                  'Kehadiran',
                  '${summary.attendancePercent.toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (pilihan)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Sahkan'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      notesController.dispose();
      return;
    }

    try {
      final saved = await _service.markWarningLetterSent(
        summary: summary,
        user: user,
        notes: notesController.text,
      );
      notesController.dispose();
      if (!mounted) return;
      setState(() {
        _warningLetterActions[summary.studentId] = saved;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status tindakan telah dikemaskini.'),
          backgroundColor: AppTheme.navy,
        ),
      );
    } catch (error) {
      notesController.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengemaskini status tindakan: $error'),
          backgroundColor: AppTheme.tidakHadir,
        ),
      );
    }
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
    final sessions = await _service.fetchAvailableSessions();
    final sections = await _service.fetchAvailableSections();
    final summaries = await _service.fetchAttendanceSummary(
      user,
      timetableId: _selectedTimetableId,
      session: _selectedSession,
      section: _selectedSection,
      dateFrom: _dateParam(_dateFrom),
      dateTo: _dateParam(_dateTo),
    );
    final warningLetterActions = await _service.fetchWarningLetterActions(
      summaries.where((summary) => summary.warningLevel > 0).toList(),
    );
    final sessionTrend = await _service.fetchRawSessionTrend(
      user,
      timetableId: _selectedTimetableId,
      session: _selectedSession,
      section: _selectedSection,
      dateFrom: _dateParam(_dateFrom),
      dateTo: _dateParam(_dateTo),
    );

    if (!mounted) return;
    setState(() {
      _availableClasses = classes;
      _sessionOptions = sessions;
      _sectionOptions = sections;
      _summaries = summaries;
      _warningLetterActions = warningLetterActions;
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
      session: _selectedSession,
      section: _selectedSection,
      dateFrom: _dateParam(_dateFrom),
      dateTo: _dateParam(_dateTo),
    );
    final warningLetterActions = await _service.fetchWarningLetterActions(
      summaries.where((summary) => summary.warningLevel > 0).toList(),
    );
    final sessionTrend = await _service.fetchRawSessionTrend(
      user,
      timetableId: _selectedTimetableId,
      session: _selectedSession,
      section: _selectedSection,
      dateFrom: _dateParam(_dateFrom),
      dateTo: _dateParam(_dateTo),
    );

    if (!mounted) return;
    setState(() {
      _summaries = summaries;
      _warningLetterActions = warningLetterActions;
      _sessionTrend = sessionTrend;
      _reloading = false;
    });
  }

  List<AttendanceSummary> get _filtered => _summaries;

  List<AttendanceSummary> get _withAttendance =>
      _filtered.where(_hasAttendanceRecord).toList();

  List<AttendanceSummary> get _warningStudents =>
      _withAttendance.where((s) => s.warningLevel > 0).toList();

  int get _totalStudents => _filtered.length;

  double get _overallPercent {
    if (_filtered.isEmpty) return 0.0;
    return _filtered.map((s) => s.attendancePercent).reduce((a, b) => a + b) /
        _filtered.length;
  }

  int get _totalAbsences =>
      _filtered.fold(0, (sum, s) => sum + s.totalAbsences);

  int get _below80Count =>
      _withAttendance.where((s) => s.attendancePercent < 80).length;

  int get _activeWarnings =>
      _withAttendance.where((s) => s.warningLevel > 0).length;

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
    final highRiskCount =
        _withAttendance.where((s) => s.attendancePercent < 60).length;
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
        final date = _trendDateLabel(lowest['date'] as String?);
        insights.add(
          'Kehadiran paling rendah pada $date (${(lowest['percent'] as double).toStringAsFixed(1)}%).',
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

    final level3Count = _withAttendance.where((s) => s.warningLevel == 3).length;
    if (level3Count > 0) {
      insights.add('Tindakan susulan diperlukan untuk $level3Count pelajar Tahap 3.');
    }

    if (insights.isEmpty) {
      insights.add('Tiada isu amaran dikesan untuk skop semasa.');
    }

    return insights;
  }

  bool _hasAttendanceRecord(AttendanceSummary summary) {
    return summary.countedRecords > 0;
  }

  String _trendDateLabel(String? value) {
    final parsed = value == null ? null : DateTime.tryParse(value);
    if (parsed == null) return '';
    return DateFormat('d/M').format(parsed);
  }

  Future<void> _exportPdf(BuildContext context) async {
    try {
      final now = DateTime.now();
      final dateLabel = DateFormat('d MMM yyyy HH:mm', 'ms').format(now);
      final filename =
          'laporan-kehadiran-${DateFormat('yyyyMMdd-HHmm').format(now)}.pdf';
      final totals = _statusTotals;
      final logoData = await rootBundle.load('assets/images/ikm_logo.png');
      final logo = pw.MemoryImage(logoData.buffer.asUint8List());
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 30),
          footer: (context) => _pdfFooter(context),
          build: (context) => [
            _pdfHeader(dateLabel, logo),
            pw.SizedBox(height: 14),
            _pdfFilterTags(),
            pw.SizedBox(height: 16),
            _pdfSectionTitle('Taburan Status'),
            _pdfStatusBlocks(totals),
            pw.SizedBox(height: 18),
            _pdfSectionTitle('Senarai Pelajar Amaran'),
            _warningStudents.isEmpty
                ? _pdfEmptyState(
                    'Tiada pelajar amaran untuk skop laporan semasa.',
                  )
                : _pdfStudentTable(_warningStudents),
            pw.SizedBox(height: 18),
            _pdfSectionTitle('Senarai Semua Pelajar'),
            _filtered.isEmpty
                ? _pdfEmptyState('Tiada pelajar untuk skop laporan semasa.')
                : _pdfStudentTable(_filtered),
          ],
        ),
      );

      await Printing.layoutPdf(
        name: filename,
        onLayout: (_) async => pdf.save(),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menjana PDF: $error'),
          backgroundColor: AppTheme.tidakHadir,
        ),
      );
    }
  }

  pw.Widget _pdfSectionTitle(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey900,
        ),
      ),
    );
  }

  pw.Widget _pdfHeader(String dateLabel, pw.ImageProvider logo) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.7),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 82,
            height: 36,
            alignment: pw.Alignment.center,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Laporan Kehadiran',
                  style: pw.TextStyle(
                    color: PdfColors.blueGrey900,
                    fontSize: 19,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'IKM Johor Bahru',
                  style: const pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            'Dijana\n$dateLabel',
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 8.5),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfFilterTags() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Maklumat Tapisan',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
        pw.SizedBox(height: 6),
        ..._pdfFilterPairs()
            .map((pair) => _pdfFilterRow(pair.key, pair.value))
            .toList(),
      ],
    );
  }

  pw.Widget _pdfFilterRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 78,
            child: pw.Text(
              label,
              textAlign: pw.TextAlign.left,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
          ),
          pw.SizedBox(
            width: 8,
            child: pw.Text(
              ':',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.blueGrey700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfStatusBlocks(Map<String, int> totals) {
    final rows = [
      ['Hadir', totals['hadir'] ?? 0],
      ['Tak Hadir', totals['takHadir'] ?? 0],
      ['MC', totals['mc'] ?? 0],
      ['CK', totals['ck'] ?? 0],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.0),
        1: pw.FlexColumnWidth(1.0),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          children: [
            _pdfHeaderCell('Status'),
            _pdfHeaderCell('Jumlah', align: pw.Alignment.center),
          ],
        ),
        ...rows.map((row) {
          final value = row[1] as int;
          return pw.TableRow(
            children: [
              _pdfStatusCell(row[0] as String),
              _pdfStatusCell('$value', align: pw.Alignment.center),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _pdfStatusCell(
    String text, {
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          fontSize: 8.8,
          color: PdfColors.blueGrey900,
        ),
      ),
    );
  }

  pw.Widget _pdfStudentTable(List<AttendanceSummary> students) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.4),
        1: pw.FlexColumnWidth(1.25),
        2: pw.FlexColumnWidth(1.0),
        3: pw.FlexColumnWidth(1.15),
        4: pw.FlexColumnWidth(0.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          children: [
            _pdfHeaderCell('Nama'),
            _pdfHeaderCell('ID Pelajar'),
            _pdfHeaderCell('Kelas'),
            _pdfHeaderCell('Kehadiran', align: pw.Alignment.center),
            _pdfHeaderCell('Tak Hadir', align: pw.Alignment.center),
          ],
        ),
        ...students.asMap().entries.map(
          (entry) {
            final summary = entry.value;
            return pw.TableRow(
              children: [
                _pdfCell('${entry.key + 1}. ${summary.studentName}'),
                _pdfCell(summary.studentId),
                _pdfCell(summary.classId),
                _pdfCell(
                  '${summary.attendancePercent.toStringAsFixed(1)}%',
                  align: pw.Alignment.center,
                ),
                _pdfCell('${summary.totalAbsences}', align: pw.Alignment.center),
              ],
            );
          },
        ),
      ],
    );
  }

  pw.Widget _pdfHeaderCell(
    String text, {
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _pdfCell(String text, {pw.Alignment align = pw.Alignment.centerLeft}) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 7.8, color: PdfColors.blueGrey900),
      ),
    );
  }

  pw.Widget _pdfEmptyState(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }

  pw.Widget _pdfFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Laporan dijana oleh sistem E-ducator',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Halaman ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, String>> _pdfFilterPairs() {
    return [
      MapEntry('Sesi', _selectedSession ?? 'Semua'),
      MapEntry('Subjek', _selectedSubjectLabel ?? 'Semua'),
      MapEntry('Seksyen', _selectedSection ?? 'Semua'),
      MapEntry('Tarikh Dari', _dateLabel(_dateFrom, fallback: 'Semua')),
      MapEntry('Tarikh Hingga', _dateLabel(_dateTo, fallback: 'Semua')),
    ];
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _boundedInitialDate(
    DateTime date, {
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    final normalized = _dateOnly(date);
    if (normalized.isBefore(firstDate)) return firstDate;
    if (normalized.isAfter(lastDate)) return lastDate;
    return normalized;
  }

  String? _dateParam(DateTime? date) {
    return date == null ? null : DateFormat('yyyy-MM-dd').format(_dateOnly(date));
  }

  String _dateLabel(DateTime? date, {required String fallback}) {
    return date == null
        ? fallback
        : DateFormat('d MMM yyyy', 'ms').format(_dateOnly(date));
  }
}
