// lib/screens/timetable_screen.dart
//
// Modul 5: Paparan Jadual Waktu — reka bentuk baharu.
// Ciri: banner pengepala, bar statistik, carian, penapis 2 lapisan, senarai sesi.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/timetable_entry.dart';
import '../providers/user_provider.dart';
import '../services/timetable_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/timetable_card.dart';

const Map<String, Color> _dayColors = {
  'Isnin': Color(0xFF3B82F6),
  'Selasa': Color(0xFF8B5CF6),
  'Rabu': Color(0xFF0FB5A6),
  'Khamis': Color(0xFFF59E0B),
  'Jumaat': Color(0xFF10B981),
};

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

int _weekOfYear(DateTime date) {
  final start = DateTime(date.year, 1, 1);
  return (date.difference(start).inDays ~/ 7) + 1;
}

String _todayMalay() {
  const map = {
    DateTime.monday: 'Isnin',
    DateTime.tuesday: 'Selasa',
    DateTime.wednesday: 'Rabu',
    DateTime.thursday: 'Khamis',
    DateTime.friday: 'Jumaat',
    DateTime.saturday: 'Sabtu',
    DateTime.sunday: 'Ahad',
  };
  return map[DateTime.now().weekday] ?? '';
}

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final _service = TimetableService();
  final _searchCtrl = TextEditingController();

  _TimetableData? _data;
  bool _loading = true;

  String? _selectedDay;
  String? _selectedSubjectCode;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final wd = DateTime.now().weekday;
    if (wd >= 1 && wd <= 5) _selectedDay = kHariList[wd - 1];
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = context.read<UserProvider>().profile!;
      final entries = await _service.fetchLecturerTimetable(user.id);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final submitted = <String, bool>{};
      for (final e in entries) {
        submitted[e.id] = await _service.checkSessionSubmitted(
          timetableId: e.id,
          attendanceDate: today,
        );
      }
      if (!mounted) return;
      setState(() {
        _data = _TimetableData(entries: entries, submitted: submitted);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ralat berlaku. Sila cuba semula.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async => _load();

  int get _totalKelas => _data?.entries.length ?? 0;

  int get _totalBilik =>
      _data?.entries
          .map((e) => e.roomName)
          .whereType<String>()
          .toSet()
          .length ??
      0;

  int get _totalSubjek =>
      _data?.entries.map((e) => e.subjectCode).toSet().length ?? 0;

  int get _kelasHariIni {
    final today = _todayMalay();
    return _data?.entries.where((e) => e.day == today).length ?? 0;
  }

  List<TimetableEntry> get _uniqueSubjects {
    if (_data == null) return [];
    final scoped = _selectedDay == null
        ? _data!.entries
        : _data!.entries.where((e) => e.day == _selectedDay);
    final seen = <String>{};
    return scoped.where((e) => seen.add(e.subjectCode)).toList()
      ..sort((a, b) => a.subjectName.compareTo(b.subjectName));
  }

  List<TimetableEntry> get _filtered {
    if (_data == null) return [];
    final q = _searchQuery.toLowerCase();
    final list = _data!.entries.where((e) {
      final dayOk = _selectedDay == null || e.day == _selectedDay;
      final subjectOk =
          _selectedSubjectCode == null || e.subjectCode == _selectedSubjectCode;
      final searchOk = q.isEmpty ||
          e.subjectName.toLowerCase().contains(q) ||
          e.subjectCode.toLowerCase().contains(q) ||
          (e.lecturerName?.toLowerCase().contains(q) ?? false) ||
          (e.roomName?.toLowerCase().contains(q) ?? false) ||
          (e.kelas?.toLowerCase().contains(q) ?? false);
      return dayOk && subjectOk && searchOk;
    }).toList();

    list.sort((a, b) {
      final dayCompare =
          kHariList.indexOf(a.day).compareTo(kHariList.indexOf(b.day));
      if (dayCompare != 0) return dayCompare;
      return a.startTime.compareTo(b.startTime);
    });
    return list;
  }

  SessionState _sessionState(TimetableEntry e) {
    final submitted = _data?.submitted[e.id] ?? false;
    if (submitted) return SessionState.telahDihantar;
    if (e.isCurrentlyOngoing(DateTime.now())) {
      return SessionState.sedangBerlangsung;
    }
    return SessionState.akanDatang;
  }

  Future<void> _openAttendance(
    TimetableEntry e, {
    bool readOnly = false,
  }) async {
    final user = context.read<UserProvider>().profile!;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await Navigator.pushNamed(
      context,
      '/attendance',
      arguments: {
        'timetableId': e.id,
        'subjectName': e.subjectName,
        'subjectCode': e.subjectCode,
        'departmentUnit': e.departmentUnit,
        'attendanceDate': today,
<<<<<<< Updated upstream
=======
        'kelas': e.kelas,
>>>>>>> Stashed changes
        'isReadOnly': readOnly,
        'userId': user.id,
      },
    );
    if (result == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Jadual Waktu',
      actions: [
        IconButton(
          tooltip: 'Muat semula',
          icon: const Icon(Icons.refresh),
          onPressed: _refresh,
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _HeaderBanner(
                  session: _data?.entries.isNotEmpty == true
                      ? (_data!.entries.first.session ?? 'JAN-JUN 2026')
                      : 'JAN-JUN 2026',
                ),
                _StatsBar(
                  totalKelas: _totalKelas,
                  totalBilik: _totalBilik,
                  totalSubjek: _totalSubjek,
                  kelasHariIni: _kelasHariIni,
                ),
                _FilterArea(
                  controller: _searchCtrl,
                  selectedDay: _selectedDay,
                  selectedSubjectCode: _selectedSubjectCode,
                  uniqueSubjects: _uniqueSubjects,
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                  onDayChanged: (d) => setState(() {
                    _selectedDay = d;
                    _selectedSubjectCode = null;
                  }),
                  onSubjectChanged: (s) =>
                      setState(() => _selectedSubjectCode = s),
                ),
                Expanded(child: _buildList()),
              ],
            ),
    );
  }

  Widget _buildList() {
    final entries = _filtered;
    if (entries.isEmpty) return const _EmptyTimetable();

    final grouped = <String, List<TimetableEntry>>{};
    for (final day in kHariList) {
      final list = entries.where((e) => e.day == day).toList();
      if (list.isNotEmpty) grouped[day] = list;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (final day in kHariList)
            if (grouped.containsKey(day))
              _DaySection(
                day: day,
                entries: grouped[day]!,
                sessionState: _sessionState,
                onTakeAttendance: (e) => _openAttendance(e),
                onViewAttendance: (e) => _openAttendance(e, readOnly: true),
              ),
        ],
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  final String session;

  const _HeaderBanner({required this.session});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final week = _weekOfYear(now);
    final day = _todayMalay();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.navy, AppTheme.navyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JADUAL WAKTU — IKM JOHOR BAHRU',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Minggu $week  •  $day',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sesi: $session',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.teal.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.teal.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Text(
                  '$week',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'MINGGU',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final int totalKelas;
  final int totalBilik;
  final int totalSubjek;
  final int kelasHariIni;

  const _StatsBar({
    required this.totalKelas,
    required this.totalBilik,
    required this.totalSubjek,
    required this.kelasHariIni,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _miniStat(Icons.class_, '$totalKelas', 'Kelas', AppTheme.navy),
          _divider(),
          _miniStat(Icons.meeting_room, '$totalBilik', 'Bilik', AppTheme.teal),
          _divider(),
          _miniStat(Icons.layers_outlined, '$totalSubjek', 'Subjek',
              AppTheme.tealDark),
          _divider(),
          _miniStat(Icons.today, '$kelasHariIni', 'Hari Ini', AppTheme.mc),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        height: 32,
        width: 1,
        color: AppTheme.slateBorder,
      );
}

class _FilterArea extends StatelessWidget {
  final TextEditingController controller;
  final String? selectedDay;
  final String? selectedSubjectCode;
  final List<TimetableEntry> uniqueSubjects;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onDayChanged;
  final ValueChanged<String?> onSubjectChanged;

  const _FilterArea({
    required this.controller,
    required this.selectedDay,
    required this.selectedSubjectCode,
    required this.uniqueSubjects,
    required this.onSearchChanged,
    required this.onDayChanged,
    required this.onSubjectChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.slate,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Cari subjek, pensyarah, bilik, kelas...',
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: AppTheme.textMuted,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.slateBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.slateBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.navy, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _chipRow(
            children: [
              _filterChip(
                'Semua Hari',
                selectedDay == null,
                () => onDayChanged(null),
              ),
              ...kHariList.map(
                (day) => _filterChip(
                  day,
                  selectedDay == day,
                  () => onDayChanged(selectedDay == day ? null : day),
                  color: _dayColors[day],
                ),
              ),
            ],
          ),
          if (uniqueSubjects.isNotEmpty) ...[
            const SizedBox(height: 6),
            _chipRow(
              children: [
                _filterChip(
                  'Semua Subjek',
                  selectedSubjectCode == null,
                  () => onSubjectChanged(null),
                ),
                ...uniqueSubjects.map(
                  (entry) => _filterChip(
                    entry.subjectName,
                    selectedSubjectCode == entry.subjectCode,
                    () => onSubjectChanged(
                      selectedSubjectCode == entry.subjectCode
                          ? null
                          : entry.subjectCode,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipRow({required List<Widget> children}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }

  Widget _filterChip(
    String label,
    bool selected,
    VoidCallback onTap, {
    Color? color,
  }) {
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
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  final String day;
  final List<TimetableEntry> entries;
  final SessionState Function(TimetableEntry entry) sessionState;
  final ValueChanged<TimetableEntry> onTakeAttendance;
  final ValueChanged<TimetableEntry> onViewAttendance;

  const _DaySection({
    required this.day,
    required this.entries,
    required this.sessionState,
    required this.onTakeAttendance,
    required this.onViewAttendance,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = day == _todayMalay();
    final dayColor = _dayColors[day] ?? AppTheme.navy;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday ? dayColor : AppTheme.slateBorder,
          width: isToday ? 2 : 1,
        ),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: dayColor.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: dayColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'HARI INI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${entries.length} kelas',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ...entries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _TimetableGridRow(
              entry: item,
              dayColor: dayColor,
              state: sessionState(item),
              isLast: index == entries.length - 1,
              onTakeAttendance: () => onTakeAttendance(item),
              onViewAttendance: () => onViewAttendance(item),
            );
          }),
        ],
      ),
    );
  }
}

class _TimetableGridRow extends StatelessWidget {
  final TimetableEntry entry;
  final Color dayColor;
  final SessionState state;
  final bool isLast;
  final VoidCallback onTakeAttendance;
  final VoidCallback onViewAttendance;

  const _TimetableGridRow({
    required this.entry,
    required this.dayColor,
    required this.state,
    required this.isLast,
    required this.onTakeAttendance,
    required this.onViewAttendance,
  });

  @override
  Widget build(BuildContext context) {
    final isSubmitted = state == SessionState.telahDihantar;
    final unitColor = _unitColor(entry.departmentUnit);

    return InkWell(
      onTap: isSubmitted ? onViewAttendance : onTakeAttendance,
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppTheme.slateBorder)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTime(entry.startTime),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: dayColor,
                    ),
                  ),
                  Text(
                    _formatTime(entry.endTime),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 3,
              height: 44,
              color: unitColor,
              margin: const EdgeInsets.symmetric(horizontal: 10),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.subjectCode,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: unitColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _pill(entry.kelas ?? entry.departmentUnit, unitColor),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subjectName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _iconInfo(
                          Icons.person_outline, entry.lecturerName ?? '-'),
                      _iconInfo(
                        Icons.meeting_room_outlined,
                        entry.roomName ?? '-',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: isSubmitted ? 'Lihat Kehadiran' : 'Ambil Kehadiran',
                  icon: Icon(
                    isSubmitted
                        ? Icons.visibility_outlined
                        : Icons.checklist_rtl,
                    size: 20,
                  ),
                  color: AppTheme.teal,
                  onPressed: isSubmitted ? onViewAttendance : onTakeAttendance,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );

  Widget _iconInfo(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      );

  String _formatTime(String time) {
    return time.length >= 5 ? time.substring(0, 5) : time;
  }
}

class _EmptyTimetable extends StatelessWidget {
  const _EmptyTimetable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 64, color: AppTheme.slateBorder),
          const SizedBox(height: 16),
          const Text(
            'Tiada sesi dijumpai.',
            style: TextStyle(fontSize: 16, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _TimetableData {
  final List<TimetableEntry> entries;
  final Map<String, bool> submitted;

  const _TimetableData({required this.entries, required this.submitted});
}
