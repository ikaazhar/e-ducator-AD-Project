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
                return TabBarView(
                  controller: _tabController,
                  children: kHariList.map((day) {
                    final list = data.entries.where((e) => e.day == day).toList();
                    if (list.isEmpty) {
                      return const Center(
                        child: Text(
                          'Tiada sesi pada hari ini.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
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
                );
              },
            ),
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
