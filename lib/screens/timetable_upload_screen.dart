// lib/screens/timetable_upload_screen.dart
//
// Modul 4: Muat Naik Jadual Waktu — Enhanced UI.
// - Admin / Ketua Jabatan / Ketua Program: boleh tambah, edit, padam.
// - Pensyarah: lihat sahaja.
// - Paparan jadual berbentuk grid mingguan IKM + senarai kad berwarna.
// - Ketuk mana-mana kelas → buka AttendanceScreen dengan tarikh kelas betul.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/room.dart';
import '../models/timetable_entry.dart';
import '../models/user_profile.dart';
import '../providers/user_provider.dart';
import '../screens/attendance_screen.dart';
import '../services/room_service.dart';
import '../services/timetable_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

// ─── Dummy semester start date (Week 1 = this date) ──────────────────────────
// Tarikh mula semester semasa — digunakan untuk kira tarikh setiap minggu.
// Tukar nilai ini mengikut semester semasa.
const String kSemesterStart = '2026-01-06'; // Isnin, 6 Jan 2026

// ─── Day colour palette ───────────────────────────────────────────────────────
const Map<String, Color> kDayColors = {
  'Isnin':  Color(0xFF3B82F6), // blue
  'Selasa': Color(0xFF8B5CF6), // purple
  'Rabu':   Color(0xFF0FB5A6), // teal
  'Khamis': Color(0xFFF59E0B), // amber
  'Jumaat': Color(0xFF10B981), // green
};

// ─── Unit colour palette ──────────────────────────────────────────────────────
Color _unitColor(String unit) {
  const map = {
    'DGS': Color(0xFF3B82F6),
    'DPP': Color(0xFF8B5CF6),
    'DED': Color(0xFFF59E0B),
    'DEK': Color(0xFF10B981),
    'DCP': Color(0xFFEF4444),
    'DCB': Color(0xFFEC4899),
    'ITW': Color(0xFF0FB5A6),
  };
  return map[unit] ?? AppTheme.navy;
}

// ─── Compute the calendar date for a given weekday in semester week W ─────────
String _dateForWeek(int semWeek, String day) {
  const dayOffset = {
    'Isnin': 0, 'Selasa': 1, 'Rabu': 2, 'Khamis': 3, 'Jumaat': 4,
  };
  try {
    final parts = kSemesterStart.split('-');
    final base = DateTime(
      int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]),
    );
    final weekStart = base.add(Duration(days: (semWeek - 1) * 7));
    final offset = dayOffset[day] ?? 0;
    final d = weekStart.add(Duration(days: offset));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return kSemesterStart;
  }
}

// ─── Which semester week is today? ────────────────────────────────────────────
int _currentSemesterWeek() {
  try {
    final parts = kSemesterStart.split('-');
    final base = DateTime(
      int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]),
    );
    final diff = DateTime.now().difference(base).inDays;
    if (diff < 0) return 1;
    return (diff ~/ 7) + 1;
  } catch (_) {
    return 1;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class TimetableUploadScreen extends StatefulWidget {
  const TimetableUploadScreen({super.key});
  @override
  State<TimetableUploadScreen> createState() => _TimetableUploadScreenState();
}

class _TimetableUploadScreenState extends State<TimetableUploadScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _service  = TimetableService();
  final _roomService = RoomService();

  // controllers
  final _codeCtrl    = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _sessionCtrl = TextEditingController();

  // form state
  String   _unit      = kJabatanList.first;
  String   _day       = kHariList.first;
  TimeOfDay _start    = const TimeOfDay(hour: 8,  minute: 0);
  TimeOfDay _end      = const TimeOfDay(hour: 10, minute: 0);
  int?     _roomId;
  String?  _lecturerId;
  String?  _kelas;
  bool     _isNewKelas = false; // true when kelas was just created

  // data
  List<Room>         _rooms     = const [];
  List<UserProfile>  _lecturers = const [];
  List<String>       _kelasList = const [];
  List<TimetableEntry> _entries = const [];
  TimetableStats _stats = const TimetableStats(
    totalClasses: 0, roomsInUse: 0, lecturersScheduled: 0, classesToday: 0,
  );

  // UI
  bool    _loading      = true;
  bool    _saving       = false;
  bool    _showForm     = false;
  String  _searchQuery  = '';
  String? _filterDay;
  String? _filterKelas;
  bool    _gridView     = true; // toggle: grid vs card list

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final user = context.read<UserProvider>().profile;
    if (user?.role == 'Ketua Program' && user?.departmentUnit != null) {
      _unit = user!.departmentUnit!;
    }
    _bootstrap();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _sessionCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ─── LOAD ───────────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    await Future.wait([_loadRooms(), _loadLecturers(), _loadKelas(), _loadEntries()]);
    await _loadStats();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRooms()     async => _rooms     = await _roomService.fetchAvailableRooms();
  Future<void> _loadLecturers() async => _lecturers = await _service.fetchLecturersByUnit(_unit);
  Future<void> _loadEntries()   async => _entries   = await _service.fetchAllTimetable(departmentUnit: _scopeUnit());
  Future<void> _loadStats()     async => _stats     = await _service.fetchStats(departmentUnit: _scopeUnit());

  Future<void> _loadKelas() async {
    _kelasList = await _service.fetchKelasByUnit(_unit);
    if (_kelas != null && !_kelasList.contains(_kelas)) _kelas = null;
  }

  String? _scopeUnit() {
    final u = context.read<UserProvider>().profile;
    return u?.role == 'Ketua Program' ? u?.departmentUnit : null;
  }

  // ─── ATTENDANCE NAV ─────────────────────────────────────────────────────────

  void _openAttendance(TimetableEntry entry, {int? semWeek}) {
    final user = context.read<UserProvider>().profile;
    if (user == null) return;
    final week = semWeek ?? _currentSemesterWeek();
    final date = _dateForWeek(week, entry.day);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceScreen(
          timetableId:    entry.id,
          subjectName:    entry.subjectName,
          subjectCode:    entry.subjectCode,
          departmentUnit: entry.departmentUnit,
          attendanceDate: date, // actual computed date for this week's class
          userId:         user.id,
        ),
      ),
    );
  }

  // ─── FORM HELPERS ───────────────────────────────────────────────────────────

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:00';

  bool _endAfterStart() =>
      _end.hour > _start.hour || (_end.hour == _start.hour && _end.minute > _start.minute);

  Future<void> _pickTime({required bool isStart}) async {
    final p = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (p == null) return;
    setState(() { if (isStart) _start = p; else _end = p; });
  }

  // ─── SUBMIT ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_kelas     == null) return _showSnack('Sila pilih kelas.',      isError: true);
    if (_roomId    == null) return _showSnack('Sila pilih bilik.',      isError: true);
    if (_lecturerId == null) return _showSnack('Sila pilih pensyarah.', isError: true);
    if (!_endAfterStart())   return _showSnack('Waktu tamat mesti selepas waktu mula.', isError: true);

    setState(() => _saving = true);
    try {
      final startStr = _formatTime(_start);
      final endStr   = _formatTime(_end);
      final free = await _service.isRoomSlotFree(
        roomId: _roomId!, day: _day, startTime: startStr, endTime: endStr,
      );
      if (!free) {
        if (!mounted) return;
        return _showSnack('Bilik telah ditempah untuk slot ini!', isError: true);
      }
      if (!mounted) return;
      final user = context.read<UserProvider>().profile!;
      await _service.insertTimetable(
        TimetableEntry(
          id: '', subjectCode: _codeCtrl.text.trim(),
          subjectName: _nameCtrl.text.trim(), departmentUnit: _unit,
          lecturerId: _lecturerId, day: _day,
          startTime: startStr, endTime: endStr,
          roomId: _roomId,
          session: _sessionCtrl.text.trim().isEmpty ? null : _sessionCtrl.text.trim(),
          kelas: _kelas,
        ),
        createdBy: user.id,
      );
      if (!mounted) return;
      _showSnack('Jadual berjaya disimpan!');
      _codeCtrl.clear(); _nameCtrl.clear();
      final wasNewKelas = _isNewKelas;
      final savedKelas = _kelas;
      setState(() { _lecturerId = null; _roomId = null; _kelas = null; _showForm = false; _isNewKelas = false; });
      if (wasNewKelas && savedKelas != null && mounted) {
        _promptAddStudents(savedKelas);
      }
      await _bootstrap();
    } catch (e) {
      if (mounted) _showSnack('Ralat: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── DELETE ─────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(TimetableEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Padam Entri?'),
        content: Text('${e.subjectCode} — ${e.subjectName}\n${e.day}  ${e.timeSlot}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.tidakHadir),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Padam'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.deleteTimetable(e.id);
    _showSnack('Entri dipadam.');
    await _bootstrap();
  }

  // ─── FILTER ─────────────────────────────────────────────────────────────────

  List<TimetableEntry> get _filtered {
    return _entries.where((e) {
      final q = _searchQuery.toLowerCase();
      final ms = q.isEmpty ||
          e.subjectCode.toLowerCase().contains(q) ||
          e.subjectName.toLowerCase().contains(q) ||
          (e.lecturerName ?? '').toLowerCase().contains(q) ||
          (e.roomName ?? '').toLowerCase().contains(q) ||
          (e.kelas ?? '').toLowerCase().contains(q);
      final md = _filterDay   == null || e.day   == _filterDay;
      final mk = _filterKelas == null || e.kelas == _filterKelas;
      return ms && md && mk;
    }).toList();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.tidakHadir : AppTheme.navy,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user     = context.watch<UserProvider>().profile;
    final canWrite = user?.role == 'Admin' ||
                     user?.role == 'Ketua Jabatan' ||
                     user?.role == 'Ketua Program';

    return AppScaffold(
      title: 'Jadual Waktu / Timetable',
      actions: [
        IconButton(
          tooltip: _gridView ? 'Paparan Kad' : 'Paparan Grid',
          icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
          onPressed: () => setState(() => _gridView = !_gridView),
        ),
        IconButton(tooltip: 'Muat semula', icon: const Icon(Icons.refresh), onPressed: _bootstrap),
        if (canWrite)
          IconButton(
            tooltip: _showForm ? 'Tutup Borang' : 'Tambah Kelas',
            icon: Icon(_showForm ? Icons.close : Icons.add),
            onPressed: () => setState(() => _showForm = !_showForm),
          ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Banner header ──
                _buildBanner(),
                // ── Stats bar ──
                _buildStatsRow(),
                // ── Form (collapsible) ──
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: canWrite ? _buildFormCard() : const SizedBox.shrink(),
                  crossFadeState: _showForm && canWrite
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
                // ── Filters ──
                _buildFilters(),
                // ── Content ──
                Expanded(
                  child: _filtered.isEmpty
                      ? _buildEmpty()
                      : _gridView
                          ? _buildWeeklyGrid()
                          : _buildCardList(canWrite),
                ),
              ],
            ),
    );
  }

  // ─── BANNER ─────────────────────────────────────────────────────────────────

  Widget _buildBanner() {
    final now   = DateTime.now();
    final week  = _currentSemesterWeek();
    final days  = ['Isnin','Selasa','Rabu','Khamis','Jumaat','Sabtu','Ahad'];
    final today = now.weekday <= 5 ? days[now.weekday - 1] : '-';
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.navy, AppTheme.navyDark],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('JADUAL WAKTU — IKM JOHOR BAHRU',
                    style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text('Minggu $week  •  $today',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Sesi: ${_sessionCtrl.text.isEmpty ? "JAN-JUN 2026" : _sessionCtrl.text}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.teal.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.teal.withOpacity(0.5)),
            ),
            child: Column(children: [
              Text('$week', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              const Text('MINGGU', style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1)),
            ]),
          ),
        ],
      ),
    );
  }

  // ─── STATS ROW ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _miniStat(Icons.class_,        '${_stats.totalClasses}',       'Kelas',    AppTheme.navy),
          _divider(),
          _miniStat(Icons.meeting_room,  '${_stats.roomsInUse}',         'Bilik',    AppTheme.teal),
          _divider(),
          _miniStat(Icons.person,        '${_stats.lecturersScheduled}', 'Pensyarah',AppTheme.tealDark),
          _divider(),
          _miniStat(Icons.today,         '${_stats.classesToday}',       'Hari Ini', AppTheme.mc),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ]),
        ],
      ),
    );
  }

  Widget _divider() => Container(height: 32, width: 1, color: AppTheme.slateBorder);

  // ─── FILTERS ────────────────────────────────────────────────────────────────

  Widget _buildFilters() {
    return Container(
      color: AppTheme.slate,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        children: [
          // Search
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari subjek, pensyarah, bilik, kelas...',
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.slateBorder)),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 6),
          // Day + Kelas chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _fChip('Semua Hari', _filterDay == null, () => setState(() => _filterDay = null)),
                ...kHariList.map((d) => _fChip(d, _filterDay == d,
                    () => setState(() => _filterDay = _filterDay == d ? null : d),
                    color: kDayColors[d])),
                const SizedBox(width: 12),
                if (_kelasList.isNotEmpty) ...[
                  _fChip('Semua Kelas', _filterKelas == null, () => setState(() => _filterKelas = null)),
                  ..._kelasList.map((k) => _fChip(k, _filterKelas == k,
                      () => setState(() => _filterKelas = _filterKelas == k ? null : k))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fChip(String label, bool selected, VoidCallback onTap, {Color? color}) {
    final c = color ?? AppTheme.teal;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? c : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? c : AppTheme.slateBorder),
          ),
          child: Text(label,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  // ─── WEEKLY GRID VIEW ───────────────────────────────────────────────────────

  Widget _buildWeeklyGrid() {
    // Group entries by day
    final byDay = <String, List<TimetableEntry>>{};
    for (final d in kHariList) {
      byDay[d] = _filtered.where((e) => e.day == d).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    final now = DateTime.now();
    final todayMalay = {1:'Isnin',2:'Selasa',3:'Rabu',4:'Khamis',5:'Jumaat'}[now.weekday] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: kHariList.map((day) {
          final classes = byDay[day] ?? [];
          final isToday = day == todayMalay;
          final dayColor = kDayColors[day] ?? AppTheme.navy;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isToday ? dayColor : AppTheme.slateBorder,
                width: isToday ? 2 : 1,
              ),
              boxShadow: isToday ? [
                BoxShadow(color: dayColor.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))
              ] : [],
            ),
            child: Column(
              children: [
                // ── Day header ──
                Container(
                  decoration: BoxDecoration(
                    color: dayColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Text(day,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('HARI INI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                      const Spacer(),
                      Text('${classes.length} kelas',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                // ── Classes for this day ──
                if (classes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(Icons.event_busy, color: dayColor.withOpacity(0.3), size: 18),
                      const SizedBox(width: 8),
                      Text('Tiada kelas', style: TextStyle(color: dayColor.withOpacity(0.5), fontSize: 13)),
                    ]),
                  )
                else
                  ...classes.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    final isLast = i == classes.length - 1;
                    return _buildGridRow(e, dayColor, isLast);
                  }),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGridRow(TimetableEntry e, Color dayColor, bool isLast) {
    final user     = context.read<UserProvider>().profile;
    final canWrite = user?.role == 'Admin' ||
                     user?.role == 'Ketua Jabatan' ||
                     user?.role == 'Ketua Program';
    final unitColor = _unitColor(e.departmentUnit);

    return InkWell(
      onTap: () => _openAttendance(e),
      child: Container(
        decoration: BoxDecoration(
          border: isLast ? null : const Border(bottom: BorderSide(color: AppTheme.slateBorder)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Time column
            SizedBox(
              width: 80,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.startTime.substring(0, 5),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: dayColor)),
                Text(e.endTime.substring(0, 5),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ]),
            ),
            // Colour stripe
            Container(width: 3, height: 44, color: unitColor,
                margin: const EdgeInsets.symmetric(horizontal: 10)),
            // Subject info
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(e.subjectCode,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: unitColor)),
                  const SizedBox(width: 6),
                  _pill(e.kelas ?? e.departmentUnit, unitColor),
                ]),
                const SizedBox(height: 2),
                Text(e.subjectName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.person_outline, size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(e.lecturerName ?? '-', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(width: 10),
                  const Icon(Icons.meeting_room_outlined, size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(e.roomName ?? '-', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ]),
              ]),
            ),
            // Actions
            Row(mainAxisSize: MainAxisSize.min, children: [
              // Attendance button
              IconButton(
                tooltip: 'Ambil Kehadiran',
                icon: const Icon(Icons.checklist_rtl, size: 20),
                color: AppTheme.teal,
                onPressed: () => _openAttendance(e),
              ),
              if (canWrite)
                IconButton(
                  tooltip: 'Padam',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppTheme.tidakHadir,
                  onPressed: () => _confirmDelete(e),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  // ─── CARD LIST VIEW ─────────────────────────────────────────────────────────

  Widget _buildCardList(bool canWrite) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _buildEntryCard(_filtered[i], canWrite),
    );
  }

  Widget _buildEntryCard(TimetableEntry e, bool canWrite) {
    final dayColor  = kDayColors[e.day] ?? AppTheme.navy;
    final unitColor = _unitColor(e.departmentUnit);
    final now       = DateTime.now();
    final isOngoing = e.isCurrentlyOngoing(now);
    final isToday   = e.isUpcomingToday(now) || isOngoing;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isOngoing ? AppTheme.teal : AppTheme.slateBorder,
            width: isOngoing ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openAttendance(e),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Day pill
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: dayColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: dayColor.withOpacity(0.3)),
                ),
                child: Column(children: [
                  Text(e.day.substring(0, 2),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: dayColor)),
                  const SizedBox(height: 4),
                  Text(e.startTime.substring(0, 5),
                      style: TextStyle(fontSize: 10, color: dayColor)),
                  Text(e.endTime.substring(0, 5),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(e.subjectCode,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: unitColor)),
                    const SizedBox(width: 6),
                    _pill(e.kelas ?? e.departmentUnit, unitColor),
                    if (isOngoing) ...[
                      const SizedBox(width: 6),
                      _pill('Sedang Berlangsung', AppTheme.teal),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(e.subjectName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 12, children: [
                    _iconInfo(Icons.person_outline,       e.lecturerName ?? '-'),
                    _iconInfo(Icons.meeting_room_outlined, e.roomName     ?? '-'),
                    _iconInfo(Icons.calendar_today_outlined, e.session   ?? '-'),
                  ]),
                ]),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton(
                    tooltip: 'Ambil Kehadiran',
                    icon: const Icon(Icons.checklist_rtl),
                    color: AppTheme.teal,
                    onPressed: () => _openAttendance(e),
                  ),
                  if (canWrite)
                    IconButton(
                      tooltip: 'Padam',
                      icon: const Icon(Icons.delete_outline),
                      color: AppTheme.tidakHadir,
                      onPressed: () => _confirmDelete(e),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );

  Widget _iconInfo(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppTheme.textMuted),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
    ],
  );

  // ─── EMPTY ──────────────────────────────────────────────────────────────────

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.calendar_today, size: 64, color: AppTheme.slateBorder),
      const SizedBox(height: 16),
      const Text('Tiada entri jadual ditemui.',
          style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
      const SizedBox(height: 8),
      const Text('Gunakan butang + untuk tambah kelas.',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
    ]),
  );

  // ─── FORM CARD ──────────────────────────────────────────────────────────────

  Widget _buildFormCard() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.add_circle_outline, color: AppTheme.teal),
              const SizedBox(width: 8),
              const Text('Tambah Entri Jadual',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.navy)),
              const Spacer(),
              TextButton(onPressed: () => setState(() => _showForm = false),
                  child: const Text('Tutup')),
            ]),
            const Divider(),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _ff(200, TextFormField(controller: _codeCtrl,
                  decoration: const InputDecoration(labelText: 'Kod Subjek'),
                  validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null)),
              _ff(280, TextFormField(controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Subjek'),
                  validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null)),
              _ff(150, DropdownButtonFormField<String>(
                  value: _unit,
                  decoration: const InputDecoration(labelText: 'Jabatan / Unit'),
                  items: kJabatanList.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() { _unit = v; _lecturerId = null; _kelas = null; });
                    await Future.wait([_loadLecturers(), _loadKelas()]);
                    setState(() {});
                  })),
              _ff(150, DropdownButtonFormField<String>(
                  value: _kelas,
                  decoration: const InputDecoration(labelText: 'Kelas'),
                  hint: const Text('Pilih kelas'),
                  items: [
                    ..._kelasList.map((k) => DropdownMenuItem(value: k, child: Text(k))),
                    const DropdownMenuItem(
                      value: '__new__',
                      child: Row(children: [
                        Icon(Icons.add_circle_outline, size: 16, color: AppTheme.teal),
                        SizedBox(width: 6),
                        Text('Tambah Kelas Baru', style: TextStyle(color: AppTheme.teal, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == '__new__') {
                      _showAddKelasDialog();
                    } else {
                      setState(() => _kelas = v);
                    }
                  })),
              _ff(250, DropdownButtonFormField<String>(
                  value: _lecturerId,
                  decoration: const InputDecoration(labelText: 'Pensyarah'),
                  hint: const Text('Pilih pensyarah'),
                  items: _lecturers.map((l) => DropdownMenuItem(value: l.id, child: Text(l.fullName))).toList(),
                  onChanged: (v) => setState(() => _lecturerId = v))),
              _ff(150, DropdownButtonFormField<String>(
                  value: _day,
                  decoration: const InputDecoration(labelText: 'Hari'),
                  items: kHariList.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setState(() => _day = v ?? _day))),
              _ff(160, OutlinedButton.icon(
                  onPressed: () => _pickTime(isStart: true),
                  icon: const Icon(Icons.access_time, size: 18),
                  label: Text('Mula: ${_start.format(context)}'))),
              _ff(160, OutlinedButton.icon(
                  onPressed: () => _pickTime(isStart: false),
                  icon: const Icon(Icons.access_time_filled, size: 18),
                  label: Text('Tamat: ${_end.format(context)}'))),
              _ff(220, DropdownButtonFormField<int>(
                  value: _roomId,
                  decoration: const InputDecoration(labelText: 'Bilik / Room'),
                  hint: const Text('Pilih bilik'),
                  items: _rooms.map((r) => DropdownMenuItem(value: r.id, child: Text(r.roomName))).toList(),
                  onChanged: (v) => setState(() => _roomId = v))),
              _ff(180, TextFormField(controller: _sessionCtrl,
                  decoration: const InputDecoration(labelText: 'Sesi', hintText: 'JAN-JUN 2026'))),
            ]),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(height: 16, width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Menyimpan...' : 'Simpan Entri'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PROMPT TO ADD STUDENTS AFTER NEW KELAS ────────────────────────────────

  void _promptAddStudents(String kelas) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.group_add_outlined, color: AppTheme.teal),
          SizedBox(width: 8),
          Text('Kelas Baru Disimpan!'),
        ]),
        content: Text(
          'Kelas "$kelas" berjaya ditambah. Adakah anda ingin menambah pelajar ke kelas ini sekarang?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(
                context,
                '/student-upload',
                arguments: {'kelas': kelas, 'program_id': _unit},
              );
            },
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Tambah Pelajar'),
          ),
        ],
      ),
    );
  }

  // ─── ADD NEW KELAS DIALOG ────────────────────────────────────────────────────

  Future<void> _showAddKelasDialog() async {
    final ctrl = TextEditingController();
    final newKelas = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.add_circle_outline, color: AppTheme.teal),
          SizedBox(width: 8),
          Text('Tambah Kelas Baru'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan nama kelas baru. Kelas ini belum mempunyai pelajar — anda boleh tambah pelajar selepas kelas ini disimpan.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Nama Kelas',
                hintText: 'Contoh: DGS4C',
                prefixIcon: const Icon(Icons.class_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = ctrl.text.trim().toUpperCase();
              if (val.isEmpty) return;
              Navigator.pop(ctx, val);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );

    if (newKelas == null || newKelas.isEmpty) return;

    setState(() {
      if (!_kelasList.contains(newKelas)) {
        _kelasList = [..._kelasList, newKelas]..sort();
      }
      _kelas = newKelas;
      _isNewKelas = true;
    });
  }

  Widget _ff(double w, Widget child) => SizedBox(width: w, child: child);
}
