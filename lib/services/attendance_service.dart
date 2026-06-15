// lib/services/attendance_service.dart
//
// Perkhidmatan rekod kehadiran untuk Modul 1.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/attendance_record.dart';
import '../models/student.dart';

class AttendanceService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Ambil senarai pelajar berdasarkan unit/program.
  Future<List<Student>> fetchStudentsByUnit(String departmentUnit, {String? kelas}) async {
    if (SupabaseConfig.isPlaceholder) return _mockStudents(departmentUnit, kelas: kelas);
    try {
      var query = _client
          .from('students')
          .select()
          .eq('program_id', departmentUnit);
      if (kelas != null && kelas.isNotEmpty) {
        query = query.eq('kelas', kelas);
      }
      final data = await query.order('full_name');
      return (data as List)
          .map((row) => Student.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockStudents(departmentUnit, kelas: kelas);
    }
  }

  /// Ambil rekod kehadiran sedia ada untuk satu sesi pada satu tarikh.
  /// Mengembalikan peta `student_id -> attendance_status`.
  Future<Map<String, String>> fetchExistingAttendance({
    required String timetableId,
    required String attendanceDate,
  }) async {
    if (SupabaseConfig.isPlaceholder) return {};
    try {
      final data = await _client
          .from('attendance_records')
          .select()
          .eq('timetable_id', timetableId)
          .eq('attendance_date', attendanceDate);
      final map = <String, String>{};
      for (final row in (data as List)) {
        final r = AttendanceRecord.fromJson(row as Map<String, dynamic>);
        map[r.studentId] = r.attendanceStatus;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// Hantar rekod kehadiran dalam pukal.
  Future<void> submitAttendance(List<AttendanceRecord> records) async {
    if (SupabaseConfig.isPlaceholder) return;
    final payload = records.map((r) => r.toJson()).toList();
    await _client.from('attendance_records').insert(payload);
  }

  // -------------------- Mock --------------------
  List<Student> _mockStudents(String unit, {String? kelas}) {
    final names = [
      'Ahmad Bin Ali',
      'Siti Aishah Binti Hassan',
      'Muhammad Faiz Bin Rahman',
      'Nurul Huda Binti Ibrahim',
      'Lim Wei Jie',
      'Tan Mei Ling',
      'Rajesh A/L Kumar',
      'Priya A/P Vijay',
      'Aiman Bin Yusof',
      'Nur Adila Binti Zainal',
    ];
    final effectiveKelas = kelas ?? '${unit}4A';
    return List.generate(names.length, (i) {
      return Student(
        id: 'stu-${unit.toLowerCase()}-${i + 1}',
        fullName: names[i],
        studentId: '${unit}24${(1000 + i)}',
        programId: unit,
        kelas: effectiveKelas,
      );
    });
  }
}
