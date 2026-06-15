// lib/services/reporting_service.dart
//
// Modul 3: Pelaporan & Pemantauan Kehadiran.
// Semua data diambil terus daripada Supabase tanpa mock atau fallback.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attendance_summary.dart';
import '../models/user_profile.dart';

class ReportingService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchAvailableClasses(UserProfile user) async {
    try {
      final query =
          _client.from('timetable').select('id, subject_code, subject_name, kelas');
      final data = await query.order('subject_code', ascending: true);
      if (data == null) return [];

      final grouped = <String, List<String>>{};
      for (final row in (data as List).cast<Map<String, dynamic>>()) {
        final label = '${row['subject_code'] ?? ''}-${row['subject_name'] ?? ''}';
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        grouped.putIfAbsent(label, () => []).add(id);
      }

      return grouped.entries
          .map((entry) => {
                'timetableId': entry.value.join(','),
                'label': entry.key,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> fetchAvailableSessions() async {
    try {
      final data = await _client
          .from('timetable')
          .select('session')
          .not('session', 'is', null)
          .order('session', ascending: false);
      if (data == null) return [];

      return (data as List)
          .map((row) => (row as Map<String, dynamic>)['session']?.toString())
          .whereType<String>()
          .where((session) => session.trim().isNotEmpty)
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> fetchAvailableSections() async {
    try {
      final data = await _client
          .from('students')
          .select('kelas')
          .not('kelas', 'is', null)
          .order('kelas', ascending: true);
      if (data == null) return [];

      return (data as List)
          .map((row) => (row as Map<String, dynamic>)['kelas']?.toString())
          .whereType<String>()
          .where((section) => section.trim().isNotEmpty)
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AttendanceSummary>> fetchAttendanceSummary(
    UserProfile user, {
    String? timetableId,
    String? session,
    String? section,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      var studentQuery =
          _client.from('students').select('id, full_name, student_id, program_id, kelas');
      if (timetableId != null || session != null) {
        final timetableScopes = await _fetchTimetableScopes(
          timetableId: timetableId,
          session: session,
        );
        if (timetableScopes.isEmpty) return [];

        final units = timetableScopes.map((scope) => scope.departmentUnit).toSet().toList();
        studentQuery = units.length == 1
            ? studentQuery.eq('program_id', units.first)
            : studentQuery.inFilter('program_id', units);

        final kelasList = timetableScopes
            .map((scope) => scope.kelas)
            .whereType<String>()
            .where((kelas) => kelas.trim().isNotEmpty)
            .toSet()
            .toList();
        if (kelasList.isNotEmpty) {
          studentQuery = kelasList.length == 1
              ? studentQuery.eq('kelas', kelasList.first)
              : studentQuery.inFilter('kelas', kelasList);
        }
      }
      if (section != null) {
        studentQuery = studentQuery.eq('kelas', section);
      }
      final studentData = await studentQuery.order('full_name', ascending: true);
      if (studentData == null) return [];
      final students = (studentData as List).cast<Map<String, dynamic>>();

      var attendanceQuery = _client.from('attendance_records').select(
            'attendance_date, attendance_status, student_id, timetable_id, '
            'timetable!inner(id, department_unit, lecturer_id, subject_code, session, kelas)',
          );
      if (timetableId != null) {
        final ids = _splitTimetableIds(timetableId);
        attendanceQuery = ids.length == 1
            ? attendanceQuery.eq('timetable_id', ids.first)
            : attendanceQuery.inFilter('timetable_id', ids);
      }
      if (session != null) {
        attendanceQuery = attendanceQuery.eq('timetable.session', session);
      }
      if (dateFrom != null) {
        attendanceQuery = attendanceQuery.gte('attendance_date', dateFrom);
      }
      if (dateTo != null) {
        attendanceQuery = attendanceQuery.lte('attendance_date', dateTo);
      }

      final attendanceData = await attendanceQuery;
      final rows = attendanceData == null
          ? <Map<String, dynamic>>[]
          : (attendanceData as List).cast<Map<String, dynamic>>();

      final recordsByStudent = <String, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        final studentId = row['student_id']?.toString() ?? '';
        if (studentId.isEmpty) continue;
        recordsByStudent.putIfAbsent(studentId, () => []).add(row);
      }

      final summaries = <AttendanceSummary>[];
      for (final student in students) {
        final id = student['id']?.toString() ?? '';
        final group = recordsByStudent[id] ?? const <Map<String, dynamic>>[];
        int hadir = 0;
        int takHadir = 0;
        for (final row in group) {
          final status = row['attendance_status']?.toString();
          if (status == 'Hadir') {
            hadir++;
          } else if (status == 'Tak Hadir') {
            takHadir++;
          }
        }

        final totalCounted = hadir + takHadir;
        final attendancePercent =
            totalCounted == 0 ? 100.0 : (hadir / totalCounted) * 100;
        final warningLevel =
            totalCounted == 0 ? 0 : _warningLevel(attendancePercent);
        final riskStatus =
            totalCounted == 0 ? 'Selamat' : _riskStatus(attendancePercent);

        final studentIdValue =
            student['student_id']?.toString() ?? student['id']?.toString() ?? '';
        final classId = student['kelas']?.toString() ??
            student['program_id']?.toString() ??
            '';

        summaries.add(
          AttendanceSummary(
            studentId: studentIdValue,
            studentName: student['full_name']?.toString() ?? '',
            classId: classId,
            attendancePercent: attendancePercent,
            totalAbsences: takHadir,
            countedRecords: totalCounted,
            warningLevel: warningLevel,
            riskStatus: riskStatus,
          ),
        );
      }

      return summaries;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchWarningNotifications(UserProfile user) async {
    try {
      final data = await _client
          .from('notifications')
          .select()
          .eq('recipient_role', user.role)
          .order('warning_level', ascending: false)
          .order('created_at', ascending: false);
      if (data == null) return [];
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, Map<String, dynamic>>> fetchWarningLetterActions(
    List<AttendanceSummary> summaries,
  ) async {
    try {
      final studentIds = summaries
          .map((summary) => summary.studentId)
          .where((id) => id.trim().isNotEmpty)
          .toSet()
          .toList();
      if (studentIds.isEmpty) return {};

      final data = await _client
          .from('warning_letter_actions')
          .select()
          .inFilter('student_id', studentIds);
      if (data == null) return {};

      final actions = <String, Map<String, dynamic>>{};
      for (final row in (data as List).cast<Map<String, dynamic>>()) {
        final studentId = row['student_id']?.toString();
        if (studentId == null || studentId.isEmpty) continue;
        actions[studentId] = row;
      }
      return actions;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> markWarningLetterSent({
    required AttendanceSummary summary,
    required UserProfile user,
    String? notes,
  }) async {
    final existing = await _client
        .from('warning_letter_actions')
        .select('id')
        .eq('student_id', summary.studentId)
        .maybeSingle();

    final payload = <String, dynamic>{
      'student_id': summary.studentId,
      'student_name': summary.studentName,
      'class_id': summary.classId,
      'attendance_percent':
          double.parse(summary.attendancePercent.toStringAsFixed(2)),
      'total_absences': summary.totalAbsences,
      'status': 'sent',
      'sent_at': DateTime.now().toUtc().toIso8601String(),
      'sent_by_user_id': user.id,
      'sent_by_name': user.fullName,
      'sent_by_role': user.role,
      'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
    };

    final Map<String, dynamic>? saved;
    if (existing == null) {
      saved = await _client
          .from('warning_letter_actions')
          .insert(payload)
          .select()
          .single();
    } else {
      saved = await _client
          .from('warning_letter_actions')
          .update(payload)
          .eq('id', existing['id'])
          .select()
          .single();
    }

    return saved ?? payload;
  }

  Future<void> generateWarningEscalations(List<AttendanceSummary> summaries) async {
    try {
      final payload = <Map<String, dynamic>>[];
      for (final summary in summaries) {
        if (summary.countedRecords == 0) continue;
        if (summary.warningLevel == 0) continue;
        final recipients = _recipientsForLevel(summary.warningLevel);
        for (final role in recipients) {
          payload.add({
            'recipient_role': role,
            'student_id': summary.studentId,
            'warning_level': summary.warningLevel,
            'is_read': false,
            'message':
                'Kehadiran ${summary.studentName} ialah ${summary.attendancePercent.toStringAsFixed(1)}%. Sila semak dan ambil tindakan susulan.',
          });
        }
      }
      if (payload.isNotEmpty) {
        await _client.from('notifications').insert(payload);
      }
    } catch (_) {
      // Do nothing on error.
    }
  }

  Future<void> markNotificationRead(dynamic id) async {
    if (id == null) return;
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllNotificationsRead(String role) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_role', role);
  }

  Future<List<Map<String, dynamic>>> fetchRawSessionTrend(
    UserProfile user, {
    String? timetableId,
    String? session,
    String? section,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      var query = _client.from('attendance_records').select(
            'attendance_date, attendance_status, timetable_id, '
            'students!inner(program_id, kelas), '
            'timetable!inner(lecturer_id, department_unit, subject_code, session, kelas)',
          );
      if (timetableId != null) {
        final ids = _splitTimetableIds(timetableId);
        query = ids.length == 1
            ? query.eq('timetable_id', ids.first)
            : query.inFilter('timetable_id', ids);
      }
      if (session != null) {
        query = query.eq('timetable.session', session);
      }
      if (section != null) {
        query = query.eq('students.kelas', section);
      }
      if (dateFrom != null) {
        query = query.gte('attendance_date', dateFrom);
      }
      if (dateTo != null) {
        query = query.lte('attendance_date', dateTo);
      }

      final data = await query;
      if (data == null) return [];

      final filteredRows = (data as List).cast<Map<String, dynamic>>();

      final trend = <String, Map<String, int>>{};
      for (final row in filteredRows) {
        final date = row['attendance_date']?.toString();
        if (date == null) continue;
        final status = row['attendance_status']?.toString();
        final entry = trend.putIfAbsent(date, () => {
          'hadir': 0,
          'takHadir': 0,
          'mc': 0,
          'ck': 0,
        });
        if (status == 'Hadir') {
          entry['hadir'] = entry['hadir']! + 1;
        } else if (status == 'Tak Hadir') {
          entry['takHadir'] = entry['takHadir']! + 1;
        } else if (status == 'MC') {
          entry['mc'] = entry['mc']! + 1;
        } else if (status == 'CK') {
          entry['ck'] = entry['ck']! + 1;
        }
      }

      final sorted = trend.entries.toList()
        ..sort((a, b) {
          final aDate = DateTime.tryParse(a.key);
          final bDate = DateTime.tryParse(b.key);
          if (aDate != null && bDate != null) {
            return aDate.compareTo(bDate);
          }
          return a.key.compareTo(b.key);
        });

      return sorted
          .map((entry) => {
                'date': entry.key,
                'hadir': entry.value['hadir'] ?? 0,
                'takHadir': entry.value['takHadir'] ?? 0,
                'mc': entry.value['mc'] ?? 0,
                'ck': entry.value['ck'] ?? 0,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  int _warningLevel(double percent) {
    if (percent <= 80) return 3;
    if (percent <= 90) return 2;
    if (percent <= 95) return 1;
    return 0;
  }

  List<String> _splitTimetableIds(String value) {
    return value
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<List<_TimetableScope>> _fetchTimetableScopes({
    String? timetableId,
    String? session,
  }) async {
    var query = _client.from('timetable').select('department_unit, kelas');

    if (timetableId != null) {
      final ids = _splitTimetableIds(timetableId);
      query = ids.length == 1
          ? query.eq('id', ids.first)
          : query.inFilter('id', ids);
    }
    if (session != null) {
      query = query.eq('session', session);
    }

    final data = await query;
    if (data == null) return [];

    final scopes = <String, _TimetableScope>{};
    for (final row in (data as List).cast<Map<String, dynamic>>()) {
      final departmentUnit = row['department_unit']?.toString();
      if (departmentUnit == null || departmentUnit.trim().isEmpty) continue;
      final kelas = row['kelas']?.toString();
      final key = '$departmentUnit|${kelas ?? ''}';
      scopes[key] = _TimetableScope(
        departmentUnit: departmentUnit,
        kelas: kelas == null || kelas.trim().isEmpty ? null : kelas,
      );
    }

    return scopes.values.toList();
  }

  String _riskStatus(double percent) {
    if (percent > 90) return 'Selamat';
    if (percent > 80) return 'Berisiko';
    return 'Kritikal';
  }

  List<String> _recipientsForLevel(int level) {
    switch (level) {
      case 1:
        return ['Lecturer', 'Ketua Program'];
      case 2:
        return ['Lecturer', 'Ketua Program', 'Ketua Jabatan'];
      case 3:
        return [
          'Lecturer',
          'Ketua Program',
          'Ketua Jabatan',
          'Timbalan Pengarah Akademik',
        ];
      default:
        return const [];
    }
  }
}

class _TimetableScope {
  final String departmentUnit;
  final String? kelas;

  const _TimetableScope({
    required this.departmentUnit,
    this.kelas,
  });
}
