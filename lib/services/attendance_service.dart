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

  /// Tambah pelajar dalam pukal ke jadual `students`.
  Future<Map<String, dynamic>> bulkInsertStudents(
      List<Map<String, dynamic>> rows) async {
    if (SupabaseConfig.isPlaceholder) {
      return {'inserted': rows.length, 'errors': <String>[]};
    }
    final errors = <String>[];
    int inserted = 0;
    for (final row in rows) {
      try {
        await _client.from('students').upsert(row, onConflict: 'student_id');
        inserted++;
      } catch (e) {
        errors.add('${row['student_id']}: $e');
      }
    }
    return {'inserted': inserted, 'errors': errors};
  }

  /// Ambil semua pelajar (boleh ditapis mengikut program).
  Future<List<Student>> fetchAllStudents({String? programId}) async {
    if (SupabaseConfig.isPlaceholder) {
      final base = (programId != null && programId.isNotEmpty)
          ? _mockStudents(programId)
          : [..._mockStudents('DGS'), ..._mockStudents('DPP')];
      return base.asMap().entries.map((e) {
        if (e.key.isEven) {
          return Student(
            id: e.value.id,
            fullName: e.value.fullName,
            studentId: e.value.studentId,
            programId: e.value.programId,
            kelas: null,
          );
        }
        return e.value;
      }).toList();
    }
    try {
      var query = _client.from('students').select();
      if (programId != null && programId.isNotEmpty) {
        query = query.eq('program_id', programId);
      }
      final data = await query.order('full_name');
      return (data as List)
          .map((row) => Student.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Kemaskini kelas untuk satu pelajar.
  Future<void> updateStudentKelas(String id, String? kelas) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client.from('students').update({'kelas': kelas}).eq('id', id);
  }

/// Kemaskini kelas untuk beberapa pelajar serentak.
Future<Map<String, dynamic>> bulkUpdateKelas(
    List<String> ids, String kelas) async {
  if (SupabaseConfig.isPlaceholder) {
    return {'updated': ids.length, 'errors': <String>[]};
  }
  final errors = <String>[];
  int updated = 0;
  for (final id in ids) {
    try {
      await _client.from('students').update({'kelas': kelas}).eq('id', id);
      updated++;
    } catch (e) {
      errors.add('$id: $e');
    }
  }
  return {'updated': updated, 'errors': errors};
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
