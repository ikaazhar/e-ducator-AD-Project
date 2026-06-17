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

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  final _service = TimetableService();
  late TabController _tabController;
  late Future<_TimetableData> _future;
  String  _searchQuery = '';
  String? _filterDay;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kHariList.length, vsync: this);
    final today = DateTime.now().weekday;
    final idx = today >= 1 && today <= 5 ? today - 1 : 0;
    _tabController.index = idx;
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
        'timetableId': e.id,
        'subjectName': e.subjectName,
        'subjectCode': e.subjectCode,
        'departmentUnit': e.departmentUnit,
        'attendanceDate': today,
        'kelas': e.kelas,  
        'isReadOnly': readOnly,
        'userId': user.id,
      },
    );
    if (result == true) _refresh();
  }

  Widget _buildFilters() {
  return Container(
    color: AppTheme.slate,
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
    child: Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Cari subjek, bilik, kelas...',
            prefixIcon: const Icon(Icons.search, size: 18),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            filled: true, fillColor: Colors.white,
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
                    () => setState(() => _filterDay = _filterDay == d ? null : d),
                  )),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _fChip(String label, bool selected, VoidCallback onTap) {
  return Padding(
    padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.teal : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.teal : AppTheme.slateBorder,
          ),
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: FutureBuilder<_TimetableData>(
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
                  final q = _searchQuery.toLowerCase();
                  final ms = q.isEmpty ||
                      e.subjectCode.toLowerCase().contains(q) ||
                      e.subjectName.toLowerCase().contains(q) ||
                      (e.roomName ?? '').toLowerCase().contains(q) ||
                      (e.kelas ?? '').toLowerCase().contains(q);
                  final md = _filterDay == null || e.day == _filterDay;
                  return ms && md;
                }).toList();

                final byDay = {
                  for (final day in kHariList)
                    day: filtered.where((e) => e.day == day).toList()
                };

                if (_searchQuery.isNotEmpty || _filterDay != null) {
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('Tiada keputusan ditemui.',
                          style: TextStyle(color: AppTheme.textMuted)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      final submitted = data.submitted[e.id] ?? false;
                      final state = _sessionState(e, submitted);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TimetableCard(
                          entry: e,
                          state: state,
                          onTakeAttendance: () => _openAttendance(e),
                          onViewAttendance: () => _openAttendance(e, readOnly: true),
                        ),
                      );
                    },
                  );
                }

                return Column(
                  children: [
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: AppTheme.navy,
                        unselectedLabelColor: AppTheme.textMuted,
                        indicatorColor: AppTheme.teal,
                        tabs: kHariList.map((h) => Tab(text: h)).toList(),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: kHariList.map((day) {
                          final list = byDay[day] ?? [];
                          if (list.isEmpty) {
                            return const Center(
                              child: Text('Tiada sesi pada hari ini.',
                                  style: TextStyle(color: AppTheme.textMuted)),
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final e = list[i];
                              final submitted = data.submitted[e.id] ?? false;
                              final state = _sessionState(e, submitted);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TimetableCard(
                                  entry: e,
                                  state: state,
                                  onTakeAttendance: () => _openAttendance(e),
                                  onViewAttendance: () =>
                                      _openAttendance(e, readOnly: true),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),                         // closes AppScaffold body
    );                           // closes AppScaffold(
  }                              // closes build()
}                                // closes _TimetableScreenState

class _TimetableData {
  final List<TimetableEntry> entries;
  final Map<String, bool> submitted;
  const _TimetableData({required this.entries, required this.submitted});
}