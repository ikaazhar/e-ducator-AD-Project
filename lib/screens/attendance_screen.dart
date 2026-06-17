// lib/screens/attendance_screen.dart
//
// Modul 1: Perekodan Kehadiran — Grid Mingguan M1–M18.
// UI diubah suai mengikut kehendak rakan industri: grid boleh skrol mendatar,
// setiap baris = satu pelajar, setiap kolum = satu minggu (M1–M18),
// kolum terakhir = % Kehadiran auto-kira.
// Logik Supabase dalam attendance_service.dart TIDAK diubah.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance_record.dart';
import '../models/student.dart';
import '../providers/user_provider.dart';
import '../services/attendance_service.dart';
import '../services/notification_service.dart';
import '../services/reporting_service.dart';
import '../theme/app_theme.dart';
import '../widgets/attendance_row.dart';

// ---------------------------------------------------------------------------
// Helper: tarikh mula setiap minggu berdasarkan tarikh mula semester.
// ---------------------------------------------------------------------------

/// Kira tarikh mula Minggu [week] (1-indexed) daripada [semesterStart].
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

// ---------------------------------------------------------------------------
// Widget Utama
// ---------------------------------------------------------------------------

class AttendanceScreen extends StatefulWidget {
  final String timetableId;
  final String subjectName;
  final String subjectCode;
  final String departmentUnit;

  /// Tarikh mula semester dalam format YYYY-MM-DD.
  /// Digunakan sebagai asas pengiraan tarikh setiap minggu.
  final String attendanceDate;
  final String? kelas;
  final String? roomName;
  final String userId;
  final bool initialReadOnly;

  const AttendanceScreen({
    super.key,
    required this.timetableId,
    required this.subjectName,
    required this.subjectCode,
    required this.departmentUnit,
    required this.attendanceDate,
    required this.userId,
    this.kelas,
    this.roomName,
    this.initialReadOnly = false,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _service = AttendanceService();
  final _reportingService = ReportingService();
  final _notificationService = NotificationService();

  List<Student> _students = [];

  /// weeklyData[studentId][minggu 1..18] = status / null
  Map<String, Map<int, String?>> _weeklyData = {};

  /// Minggu yang telah dihantar (baca sahaja).
  Set<int> _submittedWeeks = {};

  bool _loading = true;
  bool _submitting = false;
  String _searchQuery = '';

  /// Minggu aktif yang sedang dipaparkan / diedit.
  int _activeWeek = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // -------------------------------------------------------------------------
  // Muatkan data
  // -------------------------------------------------------------------------

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final students =
          await _service.fetchStudentsByUnit(widget.departmentUnit, kelas: widget.kelas,);

      // Muat semua 18 minggu secara selari
      final results = await Future.wait(
        List.generate(kTotalMinggu, (i) {
          final w = i + 1;
          return _service.fetchExistingAttendance(
            timetableId: widget.timetableId,
            attendanceDate: weekStartDate(widget.attendanceDate, w),
          );
        }),
      );

      final weeklyData = <String, Map<int, String?>>{
        for (final s in students) s.id: {},
      };
      final submittedWeeks = <int>{};

      for (int i = 0; i < kTotalMinggu; i++) {
        final w = i + 1;
        final existing = results[i];
        if (existing.isNotEmpty) {
          submittedWeeks.add(w);
          for (final s in students) {
            weeklyData[s.id]![w] = existing[s.id];
          }
        }
      }

      // Tentukan minggu aktif: minggu terawal yang belum dihantar, atau M18.
      int activeWeek = kTotalMinggu;
      for (int w = 1; w <= kTotalMinggu; w++) {
        if (!submittedWeeks.contains(w)) {
          activeWeek = w;
          break;
        }
      }

      setState(() {
        _students = students;
        _weeklyData = weeklyData;
        _submittedWeeks = submittedWeeks;
        _activeWeek = activeWeek;
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

  // -------------------------------------------------------------------------
  // Kira statistik
  // -------------------------------------------------------------------------

  int get _hadirKiniCount {
    int count = 0;
    for (final s in _students) {
      if (_weeklyData[s.id]?[_activeWeek] == 'Hadir') count++;
    }
    return count;
  }

  bool get _isActiveWeekSubmitted => _submittedWeeks.contains(_activeWeek);

  bool get _allActiveWeekFilled =>
      _students.every((s) => _weeklyData[s.id]?[_activeWeek] != null);

  // -------------------------------------------------------------------------
  // Tindakan
  // -------------------------------------------------------------------------

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
                timetableId: widget.timetableId,
                studentId: s.id,
                attendanceDate: dateStr,
                attendanceStatus: _weeklyData[s.id]![_activeWeek]!,
                markedBy: widget.userId,
              ))
          .toList();
      await _service.submitAttendance(records);
      await _generateAttendanceWarningNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kehadiran Minggu $_activeWeek berjaya direkodkan!',
          ),
        ),
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

  Future<void> _generateAttendanceWarningNotifications() async {
    final user = context.read<UserProvider>().profile;
    if (user == null) return;

    final hasClassScope =
        widget.kelas != null && widget.kelas!.trim().isNotEmpty;
    final summaries = await _reportingService.fetchAttendanceSummary(
      user,
      timetableId: hasClassScope ? null : widget.timetableId,
      section: hasClassScope ? widget.kelas : null,
    );
    await _notificationService.generateWarningEscalations(
      summaries,
      timetableId: widget.timetableId,
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kembali ke Jadual Waktu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali ke Jadual Waktu',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppTheme.slate,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _HeaderCard(
                  subjectName: widget.subjectName,
                  subjectCode: widget.subjectCode,
                  roomName: widget.roomName,
                  activeWeek: _activeWeek,
                  hadirCount: _hadirKiniCount,
                  totalStudents: _students.length,
                  isSubmitted: _isActiveWeekSubmitted,
                  totalWeeks: kTotalMinggu,
                  submittedWeeks: _submittedWeeks,
                  onWeekChanged: (w) => setState(() => _activeWeek = w),
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                ),
                if (_isActiveWeekSubmitted) _lockedBanner(),
                if (!_isActiveWeekSubmitted) _bulkBar(),
                Expanded(child: _gridBody()),
                _submitBar(),
              ],
            ),
    );
  }

  // -------------------------------------------------------------------------
  // Badan grid boleh skrol mendatar
  // -------------------------------------------------------------------------

  Widget _gridBody() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GridHeader(activeWeek: _activeWeek),
            ...(_searchQuery.isEmpty
                    ? _students
                    : _students
                        .where((s) => s.fullName
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()))
                        .toList())
                .asMap()
                .entries
                .map((entry) {
              final i = entry.key;
              final s = entry.value;
              return AttendanceRow(
                rowNumber: i + 1,
                studentName: s.fullName,
                studentId: s.studentId,
                weeklyStatus: _weeklyData[s.id] ?? {},
                submittedWeeks: _submittedWeeks,
                activeWeek: _activeWeek,
                onCellTapped: (week, status) =>
                    _onCellTapped(s.id, week, status),
              );
            }),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Widget sokongan
  // -------------------------------------------------------------------------

  Widget _lockedBanner() {
    return Container(
      width: double.infinity,
      color: AppTheme.teal.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.lock, color: AppTheme.tealDark, size: 18),
          const SizedBox(width: 8),
          Text(
            'Minggu $_activeWeek Telah Dihantar — Rekod Dikunci',
            style: const TextStyle(
              color: AppTheme.tealDark,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulkBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.flash_on_rounded, color: AppTheme.teal, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Pilih...',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          _bulkChip('Semua Hadir', AppTheme.hadir),
          const SizedBox(width: 6),
          _bulkChip('Semua X', AppTheme.tidakHadir),
          const SizedBox(width: 6),
          _bulkChip('Semua MC', AppTheme.mc),
          const SizedBox(width: 6),
          _bulkChip('Semua CK', AppTheme.ck),
        ],
      ),
    );
  }

  Widget _bulkChip(String label, Color color) {
    String status;
    if (label.contains('Hadir')) {
      status = 'Hadir';
    } else if (label.contains('X')) {
      status = 'Tak Hadir';
    } else if (label.contains('MC')) {
      status = 'MC';
    } else {
      status = 'CK';
    }
    return InkWell(
      onTap: () => _applyBulkToActiveWeek(status),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _submitBar() {
    final locked = _isActiveWeekSubmitted;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: locked
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.lock),
                    label: Text('Minggu $_activeWeek Telah Dikunci'),
                  )
                : ElevatedButton.icon(
                    onPressed:
                        (_allActiveWeekFilled && !_submitting) ? _submit : null,
                    icon: _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      'Hantar Kehadiran — Minggu $_activeWeek',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kad pengepala dengan pemilih minggu
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  final String subjectName;
  final String subjectCode;
  final String? roomName;
  final int activeWeek;
  final int hadirCount;
  final int totalStudents;
  final bool isSubmitted;
  final int totalWeeks;
  final Set<int> submittedWeeks;
  final ValueChanged<int> onWeekChanged;
  final ValueChanged<String> onSearchChanged;

  const _HeaderCard({
    required this.subjectName,
    required this.subjectCode,
    this.roomName,
    required this.activeWeek,
    required this.hadirCount,
    required this.totalStudents,
    required this.isSubmitted,
    required this.totalWeeks,
    required this.submittedWeeks,
    required this.onWeekChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nama & kod subjek
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subjectName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                        Text(
                        subjectCode,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                      if (roomName != null) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.meeting_room_outlined, size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            roomName!,
                            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                        ]),
                      ] else ...[
                        const SizedBox(height: 2),
                        const Text(
                          'Masih tiada bilik/makmal disediakan.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
              // Lencana kehadiran
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.teal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Hadir: $hadirCount / $totalStudents',
                  style: const TextStyle(
                    color: AppTheme.tealDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari nama pelajar...',
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              filled: true,
              fillColor: AppTheme.slate,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.slateBorder),
              ),
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 12),
          // Pemilih minggu
          const SizedBox(height: 12),
          // Pemilih minggu
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: totalWeeks,
              itemBuilder: (_, i) {
                final w = i + 1;
                final isActive = w == activeWeek;
                final isDone = submittedWeeks.contains(w);
                return GestureDetector(
                  onTap: () => onWeekChanged(w),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.navy
                          : isDone
                              ? AppTheme.teal.withValues(alpha: 0.12)
                              : AppTheme.slate,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive
                            ? AppTheme.navy
                            : isDone
                                ? AppTheme.teal.withValues(alpha: 0.4)
                                : AppTheme.slateBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isDone) ...[
                          Icon(
                            Icons.check_circle,
                            size: 12,
                            color: isActive
                                ? Colors.white
                                : AppTheme.tealDark,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          'M$w',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? Colors.white
                                : isDone
                                    ? AppTheme.tealDark
                                    : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
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

// ---------------------------------------------------------------------------
// Baris pengepala grid (Bil | Nama | M1…M18 | % Kehadiran)
// ---------------------------------------------------------------------------

class _GridHeader extends StatelessWidget {
  final int activeWeek;

  const _GridHeader({required this.activeWeek});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: AppTheme.navy,
      child: Row(
        children: [
          _hCell(kBilCellWidth, 'Bil'),
          _hCell(kNamaCellWidth, 'Nama Pelajar', align: TextAlign.left),
          for (int w = 1; w <= kTotalMinggu; w++)
            _weekHeaderCell(w, w == activeWeek),
          _hCell(kPeratusWidth, '% Hadir'),
        ],
      ),
    );
  }

  Widget _hCell(double width, String text,
      {TextAlign align = TextAlign.center}) {
    return Container(
      width: width,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: align == TextAlign.left
          ? Alignment.centerLeft
          : Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _weekHeaderCell(int week, bool isActive) {
    return Container(
      width: kWeekCellWidth,
      height: 44,
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.teal.withValues(alpha: 0.35)
            : Colors.transparent,
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Center(
        child: Text(
          'M$week',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.70),
          ),
        ),
      ),
    );
  }
}
