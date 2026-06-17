// lib/screens/timetable_screen.dart
//
// Modul 5: Paparan Jadual Waktu. Titik masuk ke Modul 1.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/timetable_entry.dart';
import '../providers/user_provider.dart';
import '../services/timetable_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/timetable_card.dart';

const String kSemesterStart = '2026-01-06';

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

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final _service = TimetableService();
  late Future<_TimetableData> _future;
  String  _searchQuery  = '';
  String? _filterDay;
  String? _filterSubject;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TimetableData> _load() async {
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
    return _TimetableData(entries: entries, submitted: submitted);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  SessionState _sessionState(TimetableEntry e, bool submitted) {
    if (submitted) return SessionState.telahDihantar;
    final now = DateTime.now();
    if (e.isCurrentlyOngoing(now)) return SessionState.sedangBerlangsung;
    return SessionState.akanDatang;
  }

  Future<void> _openAttendance(TimetableEntry e, {bool readOnly = false}) async {
    final user = context.read<UserProvider>().profile!;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await Navigator.pushNamed(
      context,
      '/attendance',
      arguments: {
        'timetableId':    e.id,
        'subjectName':    e.subjectName,
        'subjectCode':    e.subjectCode,
        'departmentUnit': e.departmentUnit,
        'attendanceDate': today,
        'kelas':          e.kelas,
        'roomName':       e.roomName,
        'isReadOnly':     readOnly,
        'userId':         user.id,
      },
    );
    if (result == true) _refresh();
  }

  // ── Banner ───────────────────────────────────────────────────────────────────

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
                  'Minggu $week  •  $today',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Sesi: JAN-JUN 2026',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
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
            child: Column(children: [
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
            ]),
          ),
        ],
      ),
    );
  }

  // ── Stats row ────────────────────────────────────────────────────────────────

  Widget _buildStatsRow(List<TimetableEntry> entries) {
    final now        = DateTime.now();
    final todayDay   = {1:'Isnin',2:'Selasa',3:'Rabu',4:'Khamis',5:'Jumaat'}[now.weekday];
    final todayCount = entries.where((e) => e.day == todayDay).length;
    final rooms      = entries.map((e) => e.roomName).whereType<String>().toSet().length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _miniStat(Icons.class_,       '${entries.length}', 'Kelas',    AppTheme.navy),
          _statDivider(),
          _miniStat(Icons.meeting_room, '$rooms',            'Bilik',    AppTheme.teal),
          _statDivider(),
          _miniStat(Icons.today,        '$todayCount',       'Hari Ini', AppTheme.mc),
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
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ]),
        ],
      ),
    );
  }

  Widget _statDivider() =>
      Container(height: 32, width: 1, color: AppTheme.slateBorder);

  // ── Day banner ───────────────────────────────────────────────────────────────

  Widget _dayBanner(String day, int count) {
    final now = DateTime.now();
    final todayMalay = {
      1: 'Isnin', 2: 'Selasa', 3: 'Rabu',
      4: 'Khamis', 5: 'Jumaat',
    }[now.weekday] ?? '';
    final isToday  = day == todayMalay;
    final dayColor = kCardDayColors[day] ?? AppTheme.navy;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: dayColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(day,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          if (isToday) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('HARI INI',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ],
          const Spacer(),
          Text('$count kelas',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Filters ──────────────────────────────────────────────────────────────────

  Widget _buildFilters(List<TimetableEntry> entries) {
    final subjects = entries
        .map((e) => e.subjectName)
        .toSet()
        .toList()
      ..sort();

    return Container(
      color: AppTheme.slate,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari subjek, bilik, kelas...',
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.slateBorder),
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _fChip('Semua Hari', _filterDay == null,
                    () => setState(() => _filterDay = null)),
                ...kHariList.map((d) => _fChip(
                      d,
                      _filterDay == d,
                      () => setState(
                          () => _filterDay = _filterDay == d ? null : d),
                    )),
              ],
            ),
          ),
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _fChip('Semua Subjek', _filterSubject == null,
                      () => setState(() => _filterSubject = null),
                      color: AppTheme.tealDark),
                  ...subjects.map((s) => _fChip(
                        s,
                        _filterSubject == s,
                        () => setState(() =>
                            _filterSubject = _filterSubject == s ? null : s),
                        color: AppTheme.tealDark,
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fChip(String label, bool selected, VoidCallback onTap,
      {Color? color}) {
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

  // ── Build ────────────────────────────────────────────────────────────────────

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
      body: FutureBuilder<_TimetableData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(
              child: Text('Ralat berlaku. Sila cuba semula.'),
            );
          }
          final data = snap.data!;

          final filtered = data.entries.where((e) {
            final q  = _searchQuery.toLowerCase();
            final ms = q.isEmpty ||
                e.subjectCode.toLowerCase().contains(q) ||
                e.subjectName.toLowerCase().contains(q) ||
                (e.roomName ?? '').toLowerCase().contains(q) ||
                (e.kelas ?? '').toLowerCase().contains(q);
            final md = _filterDay     == null || e.day         == _filterDay;
            final mk = _filterSubject == null || e.subjectName == _filterSubject;
            return ms && md && mk;
          }).toList();

          final byDay = {
            for (final day in kHariList)
              day: filtered.where((e) => e.day == day).toList()
          };

          return Column(
            children: [
              _buildBanner(),
              _buildStatsRow(data.entries),
              _buildFilters(data.entries),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('Tiada keputusan ditemui.',
                            style: TextStyle(color: AppTheme.textMuted)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final e = filtered[i];
                          final submitted = data.submitted[e.id] ?? false;
                          final state = _sessionState(e, submitted);
                          final isFirstOfDay =
                              i == 0 || filtered[i - 1].day != e.day;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isFirstOfDay)
                                _dayBanner(e.day, byDay[e.day]?.length ?? 0),
                              TimetableCard(
                                entry: e,
                                state: state,
                                onTakeAttendance: () => _openAttendance(e),
                                onViewAttendance: () =>
                                    _openAttendance(e, readOnly: true),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimetableData {
  final List<TimetableEntry> entries;
  final Map<String, bool> submitted;
  const _TimetableData({required this.entries, required this.submitted});
}