// lib/screens/attendance_screen.dart
//
// Modul 1: Perekodan Kehadiran — Grid Mingguan M1–M18.
// Menerima parameter [kelas] dari TimetableUploadScreen supaya
// hanya pelajar dalam kelas berkenaan dipaparkan.
import 'package:flutter/material.dart';

import '../models/attendance_record.dart';
import '../models/student.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/attendance_row.dart';

String weekStartDate(String semesterStart, int week) {
  try {
    final parts = semesterStart.split('-');
    final base = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final d = base.add(Duration(days: (week - 1) * 7));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return semesterStart;
  }
}

class AttendanceScreen extends StatefulWidget {
  final String  timetableId;
  final String  subjectName;
  final String  subjectCode;
  final String  departmentUnit;
  final String? kelas;         // ← NEW: filter students by class e.g. DGS4A
  final String  attendanceDate; // semester start date YYYY-MM-DD
  final String  userId;
  final bool    initialReadOnly;

  const AttendanceScreen({
    super.key,
    required this.timetableId,
    required this.subjectName,
    required this.subjectCode,
    required this.departmentUnit,
    this.kelas,
    required this.attendanceDate,
    required this.userId,
    this.initialReadOnly = false,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _service = AttendanceService();

  List<Student>                 _students      = [];
  Map<String, Map<int, String?>> _weeklyData   = {};
  Set<int>                      _submittedWeeks = {};

  bool _loading    = true;
  bool _submitting = false;
  int  _activeWeek = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // ── Fetch students filtered by kelas ───────────────────────────────────
      final students = await _service.fetchStudentsByUnit(
        widget.departmentUnit,
        kelas: widget.kelas, // only students in this specific class
      );

      final results = await Future.wait(
        List.generate(kTotalMinggu, (i) {
          final w = i + 1;
          return _service.fetchExistingAttendance(
            timetableId:    widget.timetableId,
            attendanceDate: weekStartDate(widget.attendanceDate, w),
          );
        }),
      );

      final weeklyData     = <String, Map<int, String?>>{ for (final s in students) s.id: {} };
      final submittedWeeks = <int>{};

      for (int i = 0; i < kTotalMinggu; i++) {
        final w       = i + 1;
        final existing = results[i];
        if (existing.isNotEmpty) {
          submittedWeeks.add(w);
          for (final s in students) {
            weeklyData[s.id]![w] = existing[s.id];
          }
        }
      }

      int activeWeek = kTotalMinggu;
      for (int w = 1; w <= kTotalMinggu; w++) {
        if (!submittedWeeks.contains(w)) { activeWeek = w; break; }
      }

      setState(() {
        _students       = students;
        _weeklyData     = weeklyData;
        _submittedWeeks = submittedWeeks;
        _activeWeek     = activeWeek;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ralat berlaku. Sila cuba semula.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _hadirKiniCount {
    int count = 0;
    for (final s in _students) {
      if (_weeklyData[s.id]?[_activeWeek] == 'Hadir') count++;
    }
    return count;
  }

  bool get _isActiveWeekSubmitted => _submittedWeeks.contains(_activeWeek);
  bool get _allActiveWeekFilled   =>
      _students.every((s) => _weeklyData[s.id]?[_activeWeek] != null);

  void _onCellTapped(String studentId, int week, String status) {
    if (_submittedWeeks.contains(week)) return;
    setState(() {
      _weeklyData[studentId] ??= {};
      _weeklyData[studentId]![week] = status;
    });
  }

  void _applyBulkToActiveWeek(String status) {
    if (_isActiveWeekSubmitted) return;
    setState(() {
      for (final s in _students) {
        _weeklyData[s.id] ??= {};
        _weeklyData[s.id]![_activeWeek] = status;
      }
    });
  }

  Future<void> _submit() async {
    if (_isActiveWeekSubmitted || !_allActiveWeekFilled || _submitting) return;
    setState(() => _submitting = true);
    try {
      final dateStr = weekStartDate(widget.attendanceDate, _activeWeek);
      final records = _students
          .map((s) => AttendanceRecord(
                timetableId:      widget.timetableId,
                studentId:        s.id,
                attendanceDate:   dateStr,
                attendanceStatus: _weeklyData[s.id]![_activeWeek]!,
                markedBy:         widget.userId,
              ))
          .toList();
      await _service.submitAttendance(records);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kehadiran Minggu $_activeWeek berjaya direkodkan!')),
      );
      setState(() => _submittedWeeks.add(_activeWeek));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ralat berlaku. Sila cuba semula.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.subjectName, style: const TextStyle(fontSize: 16)),
            if (widget.kelas != null)
              Text(widget.kelas!,
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali ke Jadual',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppTheme.slate,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _HeaderCard(
                  subjectName:    widget.subjectName,
                  subjectCode:    widget.subjectCode,
                  kelas:          widget.kelas,
                  activeWeek:     _activeWeek,
                  hadirCount:     _hadirKiniCount,
                  totalStudents:  _students.length,
                  isSubmitted:    _isActiveWeekSubmitted,
                  totalWeeks:     kTotalMinggu,
                  submittedWeeks: _submittedWeeks,
                  onWeekChanged:  (w) => setState(() => _activeWeek = w),
                ),
                if (_isActiveWeekSubmitted) _lockedBanner(),
                if (!_isActiveWeekSubmitted) _bulkBar(),
                Expanded(child: _gridBody()),
                _submitBar(),
              ],
            ),
    );
  }

  Widget _gridBody() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GridHeader(activeWeek: _activeWeek),
            ..._students.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return AttendanceRow(
                rowNumber:    i + 1,
                studentName:  s.fullName,
                studentId:    s.studentId,
                weeklyStatus: _weeklyData[s.id] ?? {},
                submittedWeeks: _submittedWeeks,
                activeWeek:   _activeWeek,
                onCellTapped: (week, status) => _onCellTapped(s.id, week, status),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _lockedBanner() {
    return Container(
      width: double.infinity,
      color: AppTheme.teal.withOpacity(0.10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        const Icon(Icons.lock, color: AppTheme.tealDark, size: 18),
        const SizedBox(width: 8),
        Text('Minggu $_activeWeek Telah Dihantar — Rekod Dikunci',
            style: const TextStyle(color: AppTheme.tealDark, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }

  Widget _bulkBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        const Icon(Icons.flash_on_rounded, color: AppTheme.teal, size: 18),
        const SizedBox(width: 8),
        const Text('Tindakan Pukal:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textDark)),
        const SizedBox(width: 12),
        _bulkChip('Semua Hadir', AppTheme.hadir),
        const SizedBox(width: 6),
        _bulkChip('Semua X', AppTheme.tidakHadir),
        const SizedBox(width: 6),
        _bulkChip('Semua MC', AppTheme.mc),
        const SizedBox(width: 6),
        _bulkChip('Semua CK', AppTheme.ck),
      ]),
    );
  }

  Widget _bulkChip(String label, Color color) {
    String status;
    if (label.contains('Hadir'))  status = 'Hadir';
    else if (label.contains('X')) status = 'Tak Hadir';
    else if (label.contains('MC'))status = 'MC';
    else                          status = 'CK';
    return InkWell(
      onTap: () => _applyBulkToActiveWeek(status),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  Widget _submitBar() {
    final locked = _isActiveWeekSubmitted;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Expanded(
          child: locked
              ? OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock),
                  label: Text('Minggu $_activeWeek Telah Dikunci'))
              : ElevatedButton.icon(
                  onPressed: (_allActiveWeekFilled && !_submitting) ? _submit : null,
                  icon: _submitting
                      ? const SizedBox(height: 16, width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text('Hantar Kehadiran — Minggu $_activeWeek')),
        ),
      ]),
    );
  }
}

// ─── Header Card ──────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final String   subjectName;
  final String   subjectCode;
  final String?  kelas;
  final int      activeWeek;
  final int      hadirCount;
  final int      totalStudents;
  final bool     isSubmitted;
  final int      totalWeeks;
  final Set<int> submittedWeeks;
  final ValueChanged<int> onWeekChanged;

  const _HeaderCard({
    required this.subjectName,
    required this.subjectCode,
    this.kelas,
    required this.activeWeek,
    required this.hadirCount,
    required this.totalStudents,
    required this.isSubmitted,
    required this.totalWeeks,
    required this.submittedWeeks,
    required this.onWeekChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subjectName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.navy)),
              const SizedBox(height: 2),
              Row(children: [
                Text(subjectCode, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                if (kelas != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.navy.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(kelas!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.navy)),
                  ),
                ],
              ]),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.teal.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Hadir: $hadirCount / $totalStudents',
                  style: const TextStyle(color: AppTheme.tealDark, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: totalWeeks,
              itemBuilder: (_, i) {
                final w      = i + 1;
                final isActive = w == activeWeek;
                final isDone   = submittedWeeks.contains(w);
                return GestureDetector(
                  onTap: () => onWeekChanged(w),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.navy
                          : isDone   ? AppTheme.teal.withOpacity(0.12)
                                     : AppTheme.slate,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive ? AppTheme.navy
                            : isDone   ? AppTheme.teal.withOpacity(0.4)
                                       : AppTheme.slateBorder,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (isDone) ...[
                        Icon(Icons.check_circle, size: 12,
                            color: isActive ? Colors.white : AppTheme.tealDark),
                        const SizedBox(width: 4),
                      ],
                      Text('M$w',
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: isActive ? Colors.white
                                : isDone   ? AppTheme.tealDark
                                           : AppTheme.textMuted,
                          )),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Grid Header ──────────────────────────────────────────────────────────────

class _GridHeader extends StatelessWidget {
  final int activeWeek;
  const _GridHeader({required this.activeWeek});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44, color: AppTheme.navy,
      child: Row(children: [
        _hCell(kBilCellWidth,  'Bil'),
        _hCell(kNamaCellWidth, 'Nama Pelajar', align: TextAlign.left),
        for (int w = 1; w <= kTotalMinggu; w++) _weekCell(w, w == activeWeek),
        _hCell(kPeratusWidth,  '% Hadir'),
      ]),
    );
  }

  Widget _hCell(double w, String text, {TextAlign align = TextAlign.center}) {
    return Container(
      width: w, height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: align == TextAlign.left ? Alignment.centerLeft : Alignment.center,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.15), width: 0.5)),
      ),
      child: Text(text, textAlign: align,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }

  Widget _weekCell(int week, bool isActive) {
    return Container(
      width: kWeekCellWidth, height: 44,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.teal.withOpacity(0.35) : Colors.transparent,
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.15), width: 0.5)),
      ),
      child: Center(child: Text('M$week',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.70)))),
    );
  }
}
