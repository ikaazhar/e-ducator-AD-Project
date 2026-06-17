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

const List<String> kHariList = [
  'Isnin', 'Selasa', 'Rabu', 'Khamis', 'Jumaat'
];

// Warna tetap
const Color _kAmber    = Color(0xFFF59E0B); // cip terpilih
const Color _kDayBlue  = Color(0xFF1A56DB); // pengepala hari biasa
const Color _kDayToday = Color(0xFF7C3AED); // pengepala hari ini (ungu)
const Color _kBadgeSubjectBg   = Color(0xFFDBEAFE); // latar lencana subjek
const Color _kBadgeSubjectText = Color(0xFF1D4ED8); // teks lencana subjek
const Color _kBadgeKelasBg     = Color(0xFFEDE9FE); // latar lencana kelas
const Color _kBadgeKelasText   = Color(0xFF6D28D9); // teks lencana kelas

// ---------------------------------------------------------------------------
// Pembantu
// ---------------------------------------------------------------------------

int _weekOfYear(DateTime date) {
  final start = DateTime(date.year, 1, 1);
  return ((date.difference(start).inDays) / 7).floor() + 1;
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

// ---------------------------------------------------------------------------
// Screen utama
// ---------------------------------------------------------------------------

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
      setState(() {
        _data = _TimetableData(entries: entries, submitted: submitted);
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

  Future<void> _refresh() async => _load();

  // ── Statistik ─────────────────────────────────────────────────────────────

  int get _totalKelas  => _data?.entries.length ?? 0;
  int get _totalBilik  =>
      _data?.entries.map((e) => e.roomName).whereType<String>().toSet().length ?? 0;
  int get _totalSubjek =>
      _data?.entries.map((e) => e.subjectCode).toSet().length ?? 0;
  int get _kelasHariIni {
    final today = _todayMalay();
    return _data?.entries.where((e) => e.day == today).length ?? 0;
  }

  List<TimetableEntry> get _uniqueSubjects {
    if (_data == null) return [];
    final seen = <String>{};
    return _data!.entries.where((e) => seen.add(e.subjectCode)).toList();
  }

  List<TimetableEntry> get _filtered {
    if (_data == null) return [];
    final q = _searchQuery.toLowerCase();
    return _data!.entries.where((e) {
      final dayOk     = _selectedDay == null || e.day == _selectedDay;
      final subjectOk = _selectedSubjectCode == null ||
          e.subjectCode == _selectedSubjectCode;
      final searchOk  = q.isEmpty ||
          e.subjectName.toLowerCase().contains(q) ||
          e.subjectCode.toLowerCase().contains(q) ||
          e.departmentUnit.toLowerCase().contains(q) ||
          (e.roomName?.toLowerCase().contains(q) ?? false);
      return dayOk && subjectOk && searchOk;
    }).toList();
  }

  SessionState _sessionState(TimetableEntry e) {
    final submitted = _data?.submitted[e.id] ?? false;
    if (submitted) return SessionState.telahDihantar;
    if (e.isCurrentlyOngoing(DateTime.now())) return SessionState.sedangBerlangsung;
    return SessionState.akanDatang;
  }

  Future<void> _openAttendance(TimetableEntry e, {bool readOnly = false}) async {
    final user = context.read<UserProvider>().profile!;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await Navigator.pushNamed(
      context,
      '/attendance',
      arguments: {
        'timetableId'   : e.id,
        'subjectName'   : e.subjectName,
        'subjectCode'   : e.subjectCode,
        'departmentUnit': e.departmentUnit,
        'attendanceDate': today,
        'isReadOnly'    : readOnly,
        'userId'        : user.id,
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
                  totalKelas  : _totalKelas,
                  totalBilik  : _totalBilik,
                  totalSubjek : _totalSubjek,
                  kelasHariIni: _kelasHariIni,
                ),
                _SearchBar(
                  controller: _searchCtrl,
                  onChanged : (v) => setState(() => _searchQuery = v),
                ),
                _FilterRows(
                  selectedDay        : _selectedDay,
                  selectedSubjectCode: _selectedSubjectCode,
                  uniqueSubjects     : _uniqueSubjects,
                  onDayChanged: (d) => setState(() {
                    _selectedDay         = d;
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
    if (entries.isEmpty) {
      return const Center(
        child: Text('Tiada sesi dijumpai.',
            style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    if (_selectedDay == null) {
      final grouped = <String, List<TimetableEntry>>{};
      for (final day in kHariList) {
        final list = entries.where((e) => e.day == day).toList();
        if (list.isNotEmpty) grouped[day] = list;
      }
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          for (final day in kHariList)
            if (grouped.containsKey(day)) ...[
              _DayHeader(day: day, count: grouped[day]!.length),
              ...grouped[day]!.map((e) => _TimetableListItem(
                    entry             : e,
                    state             : _sessionState(e),
                    onTakeAttendance  : () => _openAttendance(e),
                    onViewAttendance  : () => _openAttendance(e, readOnly: true),
                  )),
              const SizedBox(height: 10),
            ],
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _DayHeader(day: _selectedDay!, count: entries.length),
        ...entries.map((e) => _TimetableListItem(
              entry            : e,
              state            : _sessionState(e),
              onTakeAttendance : () => _openAttendance(e),
              onViewAttendance : () => _openAttendance(e, readOnly: true),
            )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Banner pengepala
// ---------------------------------------------------------------------------

class _HeaderBanner extends StatelessWidget {
  final String session;
  const _HeaderBanner({required this.session});

  @override
  Widget build(BuildContext context) {
    final now  = DateTime.now();
    final week = _weekOfYear(now);
    final day  = _todayMalay();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.navy, Color(0xFF1A3A5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JADUAL WAKTU — IKM JOHOR BAHRU',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$week',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                const Text(
                  'MINGGU',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
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

// ---------------------------------------------------------------------------
// Bar statistik
// ---------------------------------------------------------------------------

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
      child: Row(
        children: [
          _statItem(Icons.book_outlined,        '$totalKelas',   'Kelas',    const Color(0xFF3B82F6)),
          _div(),
          _statItem(Icons.meeting_room_outlined, '$totalBilik',  'Bilik',    _kAmber),
          _div(),
          _statItem(Icons.layers_outlined,       '$totalSubjek', 'Subjek',   const Color(0xFF10B981)),
          _div(),
          _statItem(Icons.today_outlined,        '$kelasHariIni','Hari Ini', _kAmber),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, Color color) =>
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        ),
      );

  Widget _div() => Container(width: 1, height: 50, color: AppTheme.slateBorder);
}

// ---------------------------------------------------------------------------
// Kotak carian
// ---------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Cari subjek, bilik, kelas...',
          hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          prefixIcon:
              const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
          filled: true,
          fillColor: AppTheme.slate,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Penapis 2 lapisan — cip amber apabila dipilih
// ---------------------------------------------------------------------------

class _FilterRows extends StatelessWidget {
  final String? selectedDay;
  final String? selectedSubjectCode;
  final List<TimetableEntry> uniqueSubjects;
  final ValueChanged<String?> onDayChanged;
  final ValueChanged<String?> onSubjectChanged;

  const _FilterRows({
    required this.selectedDay,
    required this.selectedSubjectCode,
    required this.uniqueSubjects,
    required this.onDayChanged,
    required this.onSubjectChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lapisan 1 — Hari
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip(
                  label   : 'Semua Hari',
                  selected: selectedDay == null,
                  onTap   : () => onDayChanged(null),
                ),
                ...kHariList.map((d) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _chip(
                        label   : d,
                        selected: selectedDay == d,
                        onTap   : () => onDayChanged(selectedDay == d ? null : d),
                      ),
                    )),
              ],
            ),
          ),
          if (uniqueSubjects.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Lapisan 2 — Subjek
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip(
                    label   : 'Semua Subjek',
                    selected: selectedSubjectCode == null,
                    onTap   : () => onSubjectChanged(null),
                  ),
                  ...uniqueSubjects.map((e) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _chip(
                          label   : e.subjectName,
                          selected: selectedSubjectCode == e.subjectCode,
                          onTap   : () => onSubjectChanged(
                            selectedSubjectCode == e.subjectCode
                                ? null
                                : e.subjectCode,
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Cip: amber apabila dipilih, putih apabila tidak ──
  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color : selected ? _kAmber : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _kAmber : AppTheme.slateBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize  : 12,
            fontWeight: FontWeight.w600,
            color     : selected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pengepala hari — biru biasa, ungu untuk HARI INI
// ---------------------------------------------------------------------------

class _DayHeader extends StatelessWidget {
  final String day;
  final int count;
  const _DayHeader({required this.day, required this.count});

  @override
  Widget build(BuildContext context) {
    final isToday = day == _todayMalay();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isToday
              ? [_kDayToday, const Color(0xFF9333EA)]   // ungu untuk hari ini
              : [_kDayBlue, const Color(0xFF3B82F6)],   // biru untuk hari lain
          begin: Alignment.centerLeft,
          end  : Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            day,
            style: const TextStyle(
              color     : Colors.white,
              fontSize  : 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color       : Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'HARI INI',
                style: TextStyle(
                  color     : Colors.white,
                  fontSize  : 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          const Spacer(),
          Text(
            '$count kelas',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item senarai sesi — lencana tinted, sempadan kiri berwarna
// ---------------------------------------------------------------------------

class _TimetableListItem extends StatelessWidget {
  final TimetableEntry entry;
  final SessionState state;
  final VoidCallback onTakeAttendance;
  final VoidCallback onViewAttendance;

  const _TimetableListItem({
    required this.entry,
    required this.state,
    required this.onTakeAttendance,
    required this.onViewAttendance,
  });

  Color get _borderColor {
    switch (state) {
      case SessionState.sedangBerlangsung:
        return AppTheme.teal;
      case SessionState.telahDihantar:
        return AppTheme.textMuted;
      case SessionState.akanDatang:
        return _kDayBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitted = state == SessionState.telahDihantar;
    final isOngoing   = state == SessionState.sedangBerlangsung;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color        : Colors.white,
        borderRadius : BorderRadius.circular(10),
        border       : Border.all(color: AppTheme.slateBorder),
        boxShadow: [
          BoxShadow(
            color : Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Masa ──
            Container(
              width  : 68,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              child  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fmt(entry.startTime),
                    style: const TextStyle(
                      fontSize  : 14,
                      fontWeight: FontWeight.w800,
                      color     : AppTheme.navy,
                    ),
                  ),
                  Text(
                    _fmt(entry.endTime),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            // ── Sempadan warna ──
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: _borderColor,
                borderRadius: const BorderRadius.only(
                  topLeft   : Radius.circular(2),
                  bottomLeft: Radius.circular(2),
                ),
              ),
            ),
            // ── Kandungan ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Baris lencana atas
                    Row(
                      children: [
                        // Lencana subjek — tinted biru
                        _tintBadge(entry.subjectCode,
                            _kBadgeSubjectBg, _kBadgeSubjectText),
                        const SizedBox(width: 6),
                        _tintBadge(
                          entry.departmentUnit,
                          _kBadgeKelasBg,
                          _kBadgeKelasText,
                        ),
                        // Lencana "Sedang Berlangsung" sahaja (jika berkenaan)
                        if (isOngoing) ...[
                          const SizedBox(width: 6),
                          _tintBadge('Sedang Berlangsung',
                              AppTheme.teal.withValues(alpha: 0.12), AppTheme.teal),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Nama subjek
                    Text(
                      entry.subjectName,
                      style: TextStyle(
                        fontSize  : 14,
                        fontWeight: FontWeight.w700,
                        color     : isSubmitted
                            ? AppTheme.textMuted
                            : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Bilik
                    if (entry.roomName != null)
                      Row(
                        children: [
                          const Icon(Icons.meeting_room_outlined,
                              size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            entry.roomName!,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    // Butang tindakan
                    SizedBox(
                      width : double.infinity,
                      height: 34,
                      child : isSubmitted
                          ? OutlinedButton.icon(
                              onPressed: onViewAttendance,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                side   : const BorderSide(color: AppTheme.teal),
                              ),
                              icon : const Icon(Icons.visibility_outlined,
                                  size: 15, color: AppTheme.teal),
                              label: const Text('Lihat Kehadiran',
                                  style: TextStyle(
                                      fontSize: 12, color: AppTheme.teal)),
                            )
                          : ElevatedButton.icon(
                              onPressed: onTakeAttendance,
                              style: ElevatedButton.styleFrom(
                                padding        : EdgeInsets.zero,
                                backgroundColor: AppTheme.teal,
                              ),
                              icon : const Icon(Icons.checklist_rtl, size: 15),
                              label: const Text('Ambil Kehadiran',
                                  style: TextStyle(fontSize: 12)),
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

  // Lencana tinted (latar cerah, teks berwarna) — seperti gambar rujukan
  Widget _tintBadge(String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color       : bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color     : textColor,
          fontSize  : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _fmt(String? time) =>
      (time != null && time.length >= 5) ? time.substring(0, 5) : (time ?? '');
}

// ---------------------------------------------------------------------------
// Model data dalaman
// ---------------------------------------------------------------------------

class _TimetableData {
  final List<TimetableEntry> entries;
  final Map<String, bool> submitted;
  const _TimetableData({required this.entries, required this.submitted});
}