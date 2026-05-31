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
      var query = _client.from('timetable').select('id, subject_code, subject_name');
      if (user.role == 'Lecturer') {
        query = query.eq('lecturer_id', user.id);
      } 
      final departmentUnit = user.departmentUnit;
      if ((user.role == 'Ketua Program' || user.role == 'Ketua Jabatan') &&
          departmentUnit != null) {
        query = query.eq('department_unit', departmentUnit);
      }
      final data = await query.order('subject_code', ascending: true);
      if (data == null) return [];
      return (data as List)
          .cast<Map<String, dynamic>>()
          .map((row) {
            return {
              'timetableId': row['id'].toString(),
              'label': '${row['subject_code'] ?? ''} — ${row['subject_name'] ?? ''}',
            };
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AttendanceSummary>> fetchAttendanceSummary(
    UserProfile user, {
    String? timetableId,
    String? semester,
    String? programId,
    String? subjectCode,
    String? section,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      var query = _client.from('attendance_records').select(
            'attendance_date, attendance_status, student_id, timetable_id, '
            'students(id, full_name, student_id, program_id, kelas), '
            'timetable(id, department_unit, lecturer_id, subject_code, semester)',
          );
      if (timetableId != null) {
        query = query.eq('timetable_id', timetableId);
      }
      if (semester != null) {
        query = query.eq('semester', semester);
      }
      if (programId != null) {
        query = query.eq('students.program_id', programId);
      }
      if (subjectCode != null) {
        query = query.eq('timetable.subject_code', subjectCode);
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

      final rows = (data as List).cast<Map<String, dynamic>>();
      final filteredRows = rows.where((row) {
        final timetable = row['timetable'] as Map<String, dynamic>?;
        return timetable != null && _isInScope(user, timetable);
      }).toList();

      final groups = <String, List<Map<String, dynamic>>>{};
      for (final row in filteredRows) {
        final studentId = row['student_id']?.toString() ?? '';
        final timetableIdValue = row['timetable_id']?.toString() ?? '';
        final key = '$studentId|$timetableIdValue';
        groups.putIfAbsent(key, () => []).add(row);
      }

      final summaries = <AttendanceSummary>[];
      for (final group in groups.values) {
        final student = (group.first['students'] as Map<String, dynamic>?) ?? {};
        final timetable = (group.first['timetable'] as Map<String, dynamic>?) ?? {};

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

        final studentIdValue = student['id']?.toString() ?? student['student_id']?.toString() ?? '';
        final classId = student['kelas']?.toString() ??
            student['program_id']?.toString() ??
            timetable['subject_code']?.toString() ??
            '';

        summaries.add(
          AttendanceSummary(
            studentId: studentIdValue,
            studentName: student['full_name']?.toString() ?? '',
            classId: classId,
            attendancePercent: attendancePercent,
            totalAbsences: takHadir,
            warningLevel: _warningLevel(attendancePercent),
            riskStatus: _riskStatus(attendancePercent),
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

  Future<void> generateWarningEscalations(List<AttendanceSummary> summaries) async {
    try {
      final payload = <Map<String, dynamic>>[];
      for (final summary in summaries) {
        if (summary.warningLevel == 0) continue;
        final recipients = _recipientsForLevel(summary.warningLevel);
        for (final role in recipients) {
          payload.add({
            'recipient_role': role,
            'student_id': summary.studentId,
            'warning_level': summary.warningLevel,
            'is_read': false,
            'message':
                'Pelajar ${summary.studentName} mencatatkan kehadiran ${summary.attendancePercent.toStringAsFixed(1)}%',
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

  Future<List<Map<String, dynamic>>> fetchRawSessionTrend(
    UserProfile user, {
    String? timetableId,
    String? semester,
    String? programId,
    String? subjectCode,
    String? section,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      var query = _client.from('attendance_records').select(
            'attendance_date, attendance_status, timetable_id, '
            'students(program_id, kelas), '
            'timetable(lecturer_id, department_unit, subject_code, semester)',
          );
      if (timetableId != null) {
        query = query.eq('timetable_id', timetableId);
      }
      if (semester != null) {
        query = query.eq('semester', semester);
      }
      if (programId != null) {
        query = query.eq('students.program_id', programId);
      }
      if (subjectCode != null) {
        query = query.eq('timetable.subject_code', subjectCode);
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

      final rows = (data as List).cast<Map<String, dynamic>>();
      final filteredRows = rows.where((row) {
        final timetable = row['timetable'] as Map<String, dynamic>?;
        return timetable != null && _isInScope(user, timetable);
      }).toList();

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

  bool _isInScope(UserProfile user, Map<String, dynamic> timetable) {
    switch (user.role) {
      case 'Lecturer':
        return timetable['lecturer_id'] == user.id;
      case 'Ketua Program':
      case 'Ketua Jabatan':
        return timetable['department_unit'] == user.departmentUnit;
      case 'Timbalan Pengarah Akademik':
      case 'Admin':
      default:
        return true;
    }
  }

  int _warningLevel(double percent) {
    if (percent <= 80) return 3;
    if (percent <= 90) return 2;
    if (percent <= 95) return 1;
    return 0;
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
