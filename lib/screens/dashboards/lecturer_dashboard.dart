// lib/screens/dashboards/lecturer_dashboard.dart
//
// Papan pemuka untuk peranan Lecturer.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/user_provider.dart';
import '../../services/reporting_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '_dashboard_shell.dart';

class LecturerDashboardScreen extends StatefulWidget {
  const LecturerDashboardScreen({super.key});

  @override
  State<LecturerDashboardScreen> createState() =>
      _LecturerDashboardScreenState();
}

class _LecturerDashboardScreenState extends State<LecturerDashboardScreen> {
  bool _loading = true;
  int _totalStudents = 0;
  int _totalClassesToday = 0;
  double _overallAttendanceRate = 0.0;
  int _pendingDisciplineCount = 0;
  List<Map<String, dynamic>> _todayClasses = [];
  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _weeklyTrend = [];

  String get _todayLabel => DateFormat('d MMM yyyy', 'ms').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final user = context.read<UserProvider>().profile;
    if (user == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    setState(() => _loading = true);

    final client = Supabase.instance.client;
    final today = DateTime.now();
    final todayDayNames = ['Isnin', 'Selasa', 'Rabu', 'Khamis', 'Jumaat'];
    final todayDay = today.weekday >= 1 && today.weekday <= 5
        ? todayDayNames[today.weekday - 1]
        : 'Isnin';

    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 4));
    final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);
    final weekEndStr = DateFormat('yyyy-MM-dd').format(weekEnd);

    try {
      final studentsFuture = client.from('students').select('id, program_id');
      final timetableFuture = client
          .from('timetable')
          .select('id, department_unit')
          .eq('lecturer_id', user.id);
      final todayClassesFuture = client
          .from('timetable')
          .select(
            'id, subject_code, subject_name, start_time, end_time, session, rooms(room_name)',
          )
          .eq('lecturer_id', user.id)
          .eq('day', todayDay)
          .order('start_time', ascending: true);
      final attendanceFuture = client
          .from('attendance_records')
          .select('attendance_status, timetable(lecturer_id)');
      final disciplineFuture = client
          .from('discipline_reports')
          .select('id')
          .eq('reported_by', user.id);
      final trendFuture = client
          .from('attendance_records')
          .select('attendance_date, attendance_status, timetable(lecturer_id)')
          .gte('attendance_date', weekStartStr)
          .lte('attendance_date', weekEndStr);
      final activityFuture = client
          .from('attendance_records')
          .select(
            'created_at, attendance_date, students(full_name), timetable(subject_name, lecturer_id)',
          )
          .eq('timetable.lecturer_id', user.id)
          .order('created_at', ascending: false)
          .limit(5);

      final results = await Future.wait([
        studentsFuture,
        timetableFuture,
        todayClassesFuture,
        attendanceFuture,
        disciplineFuture,
        trendFuture,
        activityFuture,
      ]);

      final studentRows = _rowsFrom(results[0]);
      final ttRows = _rowsFrom(results[1]);
      final todayClassesRows = _rowsFrom(results[2]);
      final attendanceRows = _rowsFrom(results[3]);
      final disciplineRows = _rowsFrom(results[4]);
      final trendRows = _rowsFrom(results[5]);
      final activityRows = _rowsFrom(results[6]);

      final todayClasses = todayClassesRows.map((row) {
        final room = (row['rooms'] as Map<String, dynamic>?)?['room_name']
                ?.toString() ??
            '-';
        return {
          'subject_name': row['subject_name']?.toString() ?? '',
          'subject_code': row['subject_code']?.toString() ?? '',
          'start_time': row['start_time']?.toString() ?? '',
          'end_time': row['end_time']?.toString() ?? '',
          'room': room,
        };
      }).toList();

      final attendanceMine = attendanceRows.where((row) {
        final timetable = row['timetable'] as Map<String, dynamic>?;
        return timetable != null &&
            timetable['lecturer_id']?.toString() == user.id;
      }).toList();

      final hadir = attendanceMine
          .where((row) => row['attendance_status'] == 'Hadir')
          .length;
      final takHadir = attendanceMine
          .where((row) => row['attendance_status'] == 'Tak Hadir')
          .length;
      final totalAttendance = hadir + takHadir;
      final trendGroups = <String, Map<String, int>>{};

      for (final row in trendRows) {
        final dateValue = row['attendance_date']?.toString() ?? '';
        if (dateValue.isEmpty) continue;
        final status = row['attendance_status']?.toString();
        final bucket =
            trendGroups.putIfAbsent(dateValue, () => {'hadir': 0, 'total': 0});
        if (status == 'Hadir') {
          bucket['hadir'] = bucket['hadir']! + 1;
        }
        if (status == 'Hadir' || status == 'Tak Hadir') {
          bucket['total'] = bucket['total']! + 1;
        }
      }

      final weeklyTrend = <Map<String, dynamic>>[];
      for (var i = 0; i < 5; i++) {
        final date = weekStart.add(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(date);
        final bucket = trendGroups[key];
        final total = bucket?['total'] ?? 0;
        final hadirCount = bucket?['hadir'] ?? 0;
        final percent = total == 0 ? 0.0 : (hadirCount * 100.0) / total;
        weeklyTrend.add({
          'day': todayDayNames[date.weekday - 1],
          'percent': percent,
        });
      }

      final recentActivity = activityRows.map((row) {
        final student = row['students'] as Map<String, dynamic>?;
        final timetable = row['timetable'] as Map<String, dynamic>?;
        final name = student?['full_name']?.toString() ?? 'Pelajar';
        final subject = timetable?['subject_name']?.toString() ?? '';
        final createdAt = row['created_at']?.toString() ?? '';
        final dateTime = DateTime.tryParse(createdAt);
        return {
          'name': name,
          'action': 'kehadiran direkod — $subject',
          'time': dateTime == null ? '' : _timeAgo(dateTime),
          'initials': _initials(name),
        };
      }).toList();

      if (mounted) {
        setState(() {
          _totalStudents = ttRows.isEmpty ? 0 : studentRows.length;
          _todayClasses = todayClasses;
          _totalClassesToday = todayClasses.length;
          _overallAttendanceRate = totalAttendance == 0
              ? 0.0
              : (hadir / totalAttendance) * 100;
          _pendingDisciplineCount = disciplineRows.length;
          _weeklyTrend = weeklyTrend;
          _recentActivity = recentActivity;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _totalStudents = 0;
          _todayClasses = [];
          _totalClassesToday = 0;
          _overallAttendanceRate = 0.0;
          _pendingDisciplineCount = 0;
          _weeklyTrend = [];
          _recentActivity = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  static List<Map<String, dynamic>> _rowsFrom(dynamic response) {
    if (response == null) return [];
    return (response as List).cast<Map<String, dynamic>>();
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  static String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);

    if (diff.inMinutes < 1) return 'Baru sahaja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minit lepas';
    if (diff.inHours < 24) return '${diff.inHours} jam lepas';
    if (diff.inDays == 1) return 'Semalam';
    return '${diff.inDays} hari lepas';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Papan Pemuka',
      actions: [
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/timetable-upload'),
          icon: const Icon(Icons.upload_file, size: 16),
          label: const Text('Muat Naik Jadual'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.navy,
            side: const BorderSide(color: AppTheme.slateBorder),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/booking'),
          icon: const Icon(Icons.meeting_room, size: 16),
          label: const Text('Tempah Bilik'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.navy,
            side: const BorderSide(color: AppTheme.slateBorder),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/timetable'),
          icon: const Icon(Icons.how_to_reg, size: 16),
          label: const Text('Ambil Kehadiran'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.teal,
            foregroundColor: Colors.white,
          ),
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
                  const Text(
                    'Gambaran Keseluruhan',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Jadual, kehadiran dan tindakan penting anda.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 900) {
                        return Row(
                          children: [
                            Expanded(
                              child: DashStatCard(
                                title: 'JUMLAH PELAJAR',
                                value: '$_totalStudents',
                                subtitle: 'Dalam kelas anda',
                                icon: Icons.people_outline,
                                iconColor: AppTheme.teal,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'KELAS HARI INI',
                                value: '$_totalClassesToday',
                                subtitle: _todayLabel,
                                icon: Icons.today,
                                iconColor: AppTheme.navy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'KADAR KEHADIRAN',
                                value: '${_overallAttendanceRate.toStringAsFixed(1)}%',
                                subtitle: 'Hadir vs Tak Hadir',
                                icon: Icons.trending_up,
                                iconColor: _overallAttendanceRate >= 80
                                    ? AppTheme.hadir
                                    : _overallAttendanceRate >= 60
                                        ? AppTheme.mc
                                        : AppTheme.tidakHadir,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'LAPORAN DISIPLIN',
                                value: '$_pendingDisciplineCount',
                                subtitle: 'Dilaporkan oleh anda',
                                icon: Icons.report_problem_outlined,
                                iconColor: AppTheme.mc,
                                onTap: () => Navigator.pushNamed(context, '/discipline'),
                              ),
                            ),
                          ],
                        );
                      }

                      return GridView.count(
                        crossAxisCount: constraints.maxWidth >= 600 ? 2 : 1,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 110,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          DashStatCard(
                            title: 'JUMLAH PELAJAR',
                            value: '$_totalStudents',
                            subtitle: 'Dalam kelas anda',
                            icon: Icons.people_outline,
                            iconColor: AppTheme.teal,
                          ),
                          DashStatCard(
                            title: 'KELAS HARI INI',
                            value: '$_totalClassesToday',
                            subtitle: _todayLabel,
                            icon: Icons.today,
                            iconColor: AppTheme.navy,
                          ),
                          DashStatCard(
                            title: 'KADAR KEHADIRAN',
                            value: '${_overallAttendanceRate.toStringAsFixed(1)}%',
                            subtitle: 'Hadir vs Tak Hadir',
                            icon: Icons.trending_up,
                            iconColor: _overallAttendanceRate >= 80
                                ? AppTheme.hadir
                                : _overallAttendanceRate >= 60
                                    ? AppTheme.mc
                                    : AppTheme.tidakHadir,
                          ),
                          DashStatCard(
                            title: 'LAPORAN DISIPLIN',
                            value: '$_pendingDisciplineCount',
                            subtitle: 'Dilaporkan oleh anda',
                            icon: Icons.report_problem_outlined,
                            iconColor: AppTheme.mc,
                            onTap: () => Navigator.pushNamed(context, '/discipline'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      return isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    children: [
                                      Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(18),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                children: [
                                                  const Text(
                                                    'Kehadiran Mingguan',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppTheme.navy,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Row(
                                                    children: const [
                                                      Icon(
                                                        Icons.circle,
                                                        size: 8,
                                                        color: AppTheme.teal,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Minggu ini',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: AppTheme.textMuted,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Kadar kehadiran purata mengikut hari',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textMuted,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              SizedBox(
                                                height: 220,
                                                child: _buildWeeklyChart(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(18),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              const DashSectionHeader(
                                                title: 'Aktiviti Terkini',
                                              ),
                                              const SizedBox(height: 12),
                                              if (_recentActivity.isEmpty)
                                                const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 16),
                                                  child: Center(
                                                    child: Text(
                                                      'Tiada aktiviti terkini.',
                                                      style: TextStyle(
                                                          color:
                                                              AppTheme.textMuted),
                                                    ),
                                                  ),
                                                )
                                              else
                                                Column(
                                                  children: _recentActivity
                                                      .map(
                                                        (activity) =>
                                                            ActivityItem(
                                                          initials: activity[
                                                                  'initials']
                                                              as String,
                                                          name: activity['name']
                                                              as String,
                                                          action: activity[
                                                                  'action']
                                                              as String,
                                                          timeAgo: activity[
                                                                  'time']
                                                              as String,
                                                          color: AppTheme.teal,
                                                        ),
                                                      )
                                                      .toList(),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    children: [
                                      Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(18),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              DashSectionHeader(
                                                title: 'Jadual Hari Ini',
                                                actionLabel: 'Lihat Semua →',
                                                onAction: () => Navigator.pushNamed(
                                                  context,
                                                  '/timetable',
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              if (_todayClasses.isEmpty)
                                                Column(
                                                  children: const [
                                                    Icon(
                                                      Icons.event_available_outlined,
                                                      size: 32,
                                                      color: AppTheme.textMuted,
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      'Tiada kelas hari ini.',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        color: AppTheme.textMuted,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              else
                                                Column(
                                                  children: _todayClasses
                                                      .map(
                                                        (cls) => Column(
                                                          children: [
                                                            TodayClassItem(
                                                              timeRange:
                                                                  '${cls['start_time']}–${cls['end_time']}',
                                                              subjectName: cls[
                                                                      'subject_name']
                                                                  as String,
                                                              classCode:
                                                                  cls['subject_code']
                                                                      as String,
                                                              room: cls['room']
                                                                  as String,
                                                              onTap: () =>
                                                                  Navigator.pushNamed(
                                                                context,
                                                                '/timetable',
                                                              ),
                                                            ),
                                                            const Divider(
                                                              height: 1,
                                                              color:
                                                                  AppTheme.slateBorder,
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                      .toList(),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(18),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              const Text(
                                                'Tindakan Pantas',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.navy,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                height: 44,
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      Navigator.pushNamed(
                                                    context,
                                                    '/timetable',
                                                  ),
                                                  icon: const Icon(
                                                    Icons.how_to_reg_outlined,
                                                    size: 18,
                                                    color: AppTheme.teal,
                                                  ),
                                                  label: const Text('Ambil Kehadiran'),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: AppTheme.navy,
                                                    side: const BorderSide(
                                                      color: AppTheme.slateBorder,
                                                    ),
                                                    alignment: Alignment.centerLeft,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                height: 44,
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      Navigator.pushNamed(
                                                    context,
                                                    '/discipline',
                                                  ),
                                                  icon: const Icon(
                                                    Icons.report_problem_outlined,
                                                    size: 18,
                                                    color: AppTheme.mc,
                                                  ),
                                                  label:
                                                      const Text('Laporan Disiplin'),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: AppTheme.navy,
                                                    side: const BorderSide(
                                                      color: AppTheme.slateBorder,
                                                    ),
                                                    alignment: Alignment.centerLeft,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                height: 44,
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      Navigator.pushNamed(
                                                    context,
                                                    '/reporting',
                                                  ),
                                                  icon: const Icon(
                                                    Icons.bar_chart_outlined,
                                                    size: 18,
                                                    color: AppTheme.navy,
                                                  ),
                                                  label:
                                                      const Text('Laporan Kehadiran'),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: AppTheme.navy,
                                                    side: const BorderSide(
                                                      color: AppTheme.slateBorder,
                                                    ),
                                                    alignment: Alignment.centerLeft,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                height: 44,
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      Navigator.pushNamed(
                                                    context,
                                                    '/booking',
                                                  ),
                                                  icon: const Icon(
                                                    Icons.meeting_room_outlined,
                                                    size: 18,
                                                    color: AppTheme.teal,
                                                  ),
                                                  label:
                                                      const Text('Tempahan Bilik'),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: AppTheme.navy,
                                                    side: const BorderSide(
                                                      color: AppTheme.slateBorder,
                                                    ),
                                                    alignment: Alignment.centerLeft,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: const [
                                            Text(
                                              'Kehadiran Mingguan',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.navy,
                                              ),
                                            ),
                                            Spacer(),
                                            Icon(
                                              Icons.circle,
                                              size: 8,
                                              color: AppTheme.teal,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Minggu ini',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Kadar kehadiran purata mengikut hari',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          height: 220,
                                          child: _buildWeeklyChart(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const DashSectionHeader(
                                          title: 'Aktiviti Terkini',
                                        ),
                                        const SizedBox(height: 12),
                                        if (_recentActivity.isEmpty)
                                          const Padding(
                                            padding:
                                                EdgeInsets.symmetric(vertical: 16),
                                            child: Center(
                                              child: Text(
                                                'Tiada aktiviti terkini.',
                                                style: TextStyle(
                                                  color: AppTheme.textMuted,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Column(
                                            children: _recentActivity
                                                .map(
                                                  (activity) => ActivityItem(
                                                    initials:
                                                        activity['initials'] as String,
                                                    name: activity['name'] as String,
                                                    action: activity['action'] as String,
                                                    timeAgo: activity['time'] as String,
                                                    color: AppTheme.teal,
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        DashSectionHeader(
                                          title: 'Jadual Hari Ini',
                                          actionLabel: 'Lihat Semua →',
                                          onAction: () =>
                                              Navigator.pushNamed(context, '/timetable'),
                                        ),
                                        const SizedBox(height: 8),
                                        if (_todayClasses.isEmpty)
                                          Column(
                                            children: const [
                                              Icon(
                                                Icons.event_available_outlined,
                                                size: 32,
                                                color: AppTheme.textMuted,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Tiada kelas hari ini.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: AppTheme.textMuted,
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          Column(
                                            children: _todayClasses
                                                .map(
                                                  (cls) => Column(
                                                    children: [
                                                      TodayClassItem(
                                                        timeRange:
                                                            '${cls['start_time']}–${cls['end_time']}',
                                                        subjectName:
                                                            cls['subject_name'] as String,
                                                        classCode:
                                                            cls['subject_code'] as String,
                                                        room: cls['room'] as String,
                                                        onTap: () =>
                                                            Navigator.pushNamed(
                                                          context,
                                                          '/timetable',
                                                        ),
                                                      ),
                                                      const Divider(
                                                        height: 1,
                                                        color: AppTheme.slateBorder,
                                                      ),
                                                    ],
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Text(
                                          'Tindakan Pantas',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.navy,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          height: 44,
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                Navigator.pushNamed(context, '/timetable'),
                                            icon: const Icon(
                                              Icons.how_to_reg_outlined,
                                              size: 18,
                                              color: AppTheme.teal,
                                            ),
                                            label: const Text('Ambil Kehadiran'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.navy,
                                              side: const BorderSide(
                                                color: AppTheme.slateBorder,
                                              ),
                                              alignment: Alignment.centerLeft,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 44,
                                          child: OutlinedButton.icon(
                                            onPressed: () => Navigator.pushNamed(
                                              context,
                                              '/discipline',
                                            ),
                                            icon: const Icon(
                                              Icons.report_problem_outlined,
                                              size: 18,
                                              color: AppTheme.mc,
                                            ),
                                            label: const Text('Laporan Disiplin'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.navy,
                                              side: const BorderSide(
                                                color: AppTheme.slateBorder,
                                              ),
                                              alignment: Alignment.centerLeft,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 44,
                                          child: OutlinedButton.icon(
                                            onPressed: () => Navigator.pushNamed(
                                              context,
                                              '/reporting',
                                            ),
                                            icon: const Icon(
                                              Icons.bar_chart_outlined,
                                              size: 18,
                                              color: AppTheme.navy,
                                            ),
                                            label:
                                                const Text('Laporan Kehadiran'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.navy,
                                              side: const BorderSide(
                                                color: AppTheme.slateBorder,
                                              ),
                                              alignment: Alignment.centerLeft,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 44,
                                          child: OutlinedButton.icon(
                                            onPressed: () => Navigator.pushNamed(
                                              context,
                                              '/booking',
                                            ),
                                            icon: const Icon(
                                              Icons.meeting_room_outlined,
                                              size: 18,
                                              color: AppTheme.teal,
                                            ),
                                            label: const Text('Tempahan Bilik'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.navy,
                                              side: const BorderSide(
                                                color: AppTheme.slateBorder,
                                              ),
                                              alignment: Alignment.centerLeft,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildWeeklyChart() {
    final hasData =
        _weeklyTrend.any((item) => (item['percent'] as double) > 0.0);

    if (!hasData) {
      return const Center(
        child: Text(
          'Tiada data kehadiran minggu ini.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    return BarChart(
      BarChartData(
        maxY: 100,
        minY: 0,
        barGroups: _weeklyTrend.asMap().entries.map((entry) {
          final index = entry.key;
          final percent = entry.value['percent'] as double;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: percent,
                width: 32,
                borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                gradient: const LinearGradient(
                  colors: [AppTheme.teal, AppTheme.navy],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ],
          );
        }).toList(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppTheme.slateBorder,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 20,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                const labels = ['Isn', 'Sel', 'Rab', 'Kha', 'Jum'];
                final index = value.toInt();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    labels[index],
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}