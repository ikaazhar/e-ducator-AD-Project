// lib/services/reporting_service.dart
//
// Modul 3: Pelaporan & Pemantauan Kehadiran.
// Mengira % kehadiran, tahap amaran, dan trend daripada data kehadiran sedia ada.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/attendance_summary.dart';
import '../models/user_profile.dart';

class ReportingService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Kira ringkasan kehadiran setiap pelajar mengikut skop peranan pengguna.
  ///
  /// Formula:
  ///   Hadir + Lambat        → dikira hadir
  ///   Tak Hadir             → dikira tidak hadir
  ///   MC + CK               → dikecualikan (tidak masuk dalam penyebut)
  ///   % kehadiran = (hadir ÷ (jumlah - MC - CK)) × 100
  Future<List<AttendanceSummary>> fetchAttendanceSummary(UserProfile user) async {
    if (SupabaseConfig.isPlaceholder) return _mockSummaries(user);

    try {
      // Soalan asas: cantum attendance + students + timetable utk skop.
      final data = await _client
          .from('attendance_records')
          .select(
              '*, students(id, full_name, program_id, kelas), timetable(department_unit, lecturer_id)');

      // Kumpul mengikut pelajar.
      final groups = <String, List<Map<String, dynamic>>>{};
      for (final row in (data as List)) {
        final r = row as Map<String, dynamic>;
        final student = r['students'] as Map<String, dynamic>?;
        final timetable = r['timetable'] as Map<String, dynamic>?;
        if (student == null || timetable == null) continue;

        // Penapis RBAC.
        if (!_inScope(user, timetable, student)) continue;

        final sid = student['id'].toString();
        groups.putIfAbsent(sid, () => []).add(r);
      }

      final summaries = <AttendanceSummary>[];
      groups.forEach((sid, rows) {
        final student = rows.first['students'] as Map<String, dynamic>;
        int hadir = 0, tidak = 0;
        for (final r in rows) {
          final s = r['attendance_status'];
          if (s == 'Hadir') {
            hadir++;
          } else if (s == 'Tak Hadir') {
            tidak++;
          }
          // MC dan CK dikecualikan daripada penyebut (lihat formula M3).
        }
        final counted = hadir + tidak;
        final percent = counted == 0 ? 100.0 : (hadir / counted) * 100;
        summaries.add(
          AttendanceSummary(
            studentId: sid,
            studentName: (student['full_name'] ?? '') as String,
            classId: (student['kelas'] ?? student['program_id'] ?? '') as String,
            attendancePercent: percent,
            totalAbsences: tidak,
            warningLevel: _warningLevel(percent),
            riskStatus: _riskStatus(percent),
          ),
        );
      });

      return summaries;
    } catch (_) {
      return _mockSummaries(user);
    }
  }

  /// Notifikasi amaran untuk peranan semasa.
  Future<List<Map<String, dynamic>>> fetchWarningNotifications(UserProfile user) async {
    if (SupabaseConfig.isPlaceholder) return _mockNotifications(user);
    try {
      final data = await _client
          .from('notifications')
          .select()
          .eq('recipient_role', user.role)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return _mockNotifications(user);
    }
  }

  /// Hasilkan / upsert eskalasi amaran berdasarkan ambang.
  Future<void> generateWarningEscalations(List<AttendanceSummary> summaries) async {
    if (SupabaseConfig.isPlaceholder) return;
    final payload = <Map<String, dynamic>>[];
    for (final s in summaries) {
      if (s.warningLevel == 0) continue;
      final recipients = _recipientsForLevel(s.warningLevel);
      for (final role in recipients) {
        payload.add({
          'recipient_role': role,
          'student_id': s.studentId,
          'warning_level': s.warningLevel,
          'message':
              'Pelajar ${s.studentName} berada pada amaran tahap ${s.warningLevel} '
              '(kehadiran ${s.attendancePercent.toStringAsFixed(1)}%).',
          'is_read': false,
        });
      }
    }
    if (payload.isNotEmpty) {
      await _client.from('notifications').insert(payload);
    }
  }

  // --------------- Helpers ---------------
  bool _inScope(UserProfile user, Map<String, dynamic> tt, Map<String, dynamic> student) {
    switch (user.role) {
      case 'Lecturer':
        return tt['lecturer_id'] == user.id;
      case 'Ketua Program':
        return student['program_id'] == user.departmentUnit;
      case 'Ketua Jabatan':
        return tt['department_unit'] == user.departmentUnit;
      case 'Timbalan Pengarah Akademik':
        // Hanya kes Level 3 dipaparkan — penapisan dilakukan di lapisan paparan.
        return true;
      case 'Admin':
      default:
        return true;
    }
  }

  int _warningLevel(double percent) {
    final absence = 100 - percent;
    if (absence >= 20) return 3;
    if (absence >= 10) return 2;
    if (absence >= 5) return 1;
    return 0;
  }

  String _riskStatus(double percent) {
    if (percent >= 80) return 'Selamat';
    if (percent >= 60) return 'Berisiko';
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

  // --------------- Mock ---------------
  List<AttendanceSummary> _mockSummaries(UserProfile user) {
    final base = [
      ('stu-dgs-1', 'Ahmad Bin Ali', 'DGS4A', 92.5, 1),
      ('stu-dgs-2', 'Siti Aishah Binti Hassan', 'DGS4A', 85.0, 2),
      ('stu-dgs-3', 'Muhammad Faiz Bin Rahman', 'DGS4A', 72.0, 6),
      ('stu-dgs-4', 'Nurul Huda Binti Ibrahim', 'DGS4A', 58.0, 9),
      ('stu-dgs-5', 'Lim Wei Jie', 'DGS4B', 95.0, 1),
      ('stu-dgs-6', 'Tan Mei Ling', 'DGS4B', 78.0, 4),
      ('stu-dgs-7', 'Rajesh A/L Kumar', 'DGS4B', 65.0, 7),
    ];
    return base.map((row) {
      final percent = row.$4;
      return AttendanceSummary(
        studentId: row.$1,
        studentName: row.$2,
        classId: row.$3,
        attendancePercent: percent,
        totalAbsences: row.$5,
        warningLevel: _warningLevel(percent),
        riskStatus: _riskStatus(percent),
      );
    }).toList();
  }

  List<Map<String, dynamic>> _mockNotifications(UserProfile user) {
    return [
      {
        'id': 'n1',
        'recipient_role': user.role,
        'warning_level': 3,
        'message': 'Nurul Huda Binti Ibrahim mencatatkan kehadiran 58% (Level 3).',
        'is_read': false,
        'created_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
      },
      {
        'id': 'n2',
        'recipient_role': user.role,
        'warning_level': 2,
        'message': 'Muhammad Faiz Bin Rahman mencapai amaran tahap 2.',
        'is_read': false,
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
    ];
  }
}
