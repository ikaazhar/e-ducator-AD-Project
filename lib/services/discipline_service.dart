// lib/services/discipline_service.dart
//
// Perkhidmatan laporan disiplin (Modul 2). Skop pertanyaan berdasarkan RBAC.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/discipline_report.dart';
import '../models/student.dart';
import '../models/timetable_entry.dart';
import '../models/user_profile.dart';
import 'timetable_service.dart';

class DisciplineService {
  SupabaseClient get _client => Supabase.instance.client;
  final TimetableService _timetable = TimetableService();

  /// Ambil laporan disiplin dengan RBAC bersepadu.
  /// - Lecturer: hanya laporan untuk pelajar dalam KELAS yang diajar
  /// - Ketua Program: semua dalam program/unit (department_unit)
  /// - Ketua Jabatan: semua dalam jabatan (department_id)
  /// - Admin: semua rekod
  /// - Timbalan Pengarah Akademik: tiada akses (senarai kosong)
  Future<List<DisciplineReport>> fetchReports(UserProfile user) async {
    if (user.role == 'Timbalan Pengarah Akademik') return const [];
    if (SupabaseConfig.isPlaceholder) return _mockReports(user);
    try {
      final base = _client
          .from('discipline_reports')
          .select('*, students(full_name, kelas), profiles!discipline_reports_reported_by_fkey(full_name)');

      // Lecturer: skop terhad kepada kelas yang diajar (program + kelas).
      if (user.role == 'Lecturer') {
        final courses = await _timetable.fetchLecturerTimetable(user.id);
        final scope = _LecturerScope.fromCourses(courses);
        if (scope.units.isEmpty) return const [];
        final data = await base
            .inFilter('program_id', scope.units)
            .order('created_at', ascending: false);
        return (data as List)
            .map((row) => DisciplineReport.fromJson(row as Map<String, dynamic>))
            .where((r) => scope.allows(r.programId, r.kelas))
            .toList();
      }

      dynamic query = base;
      switch (user.role) {
        case 'Ketua Program':
          if (user.departmentUnit != null) {
            query = base.eq('program_id', user.departmentUnit!);
          }
          break;
        case 'Ketua Jabatan':
          if (user.departmentUnit != null) {
            query = base.eq('department_id', user.departmentUnit!);
          }
          break;
        case 'Admin':
        default:
          break;
      }

      final data = await query.order('created_at', ascending: false);
      return (data as List)
          .map((row) => DisciplineReport.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockReports(user);
    }
  }

  /// Hantar laporan disiplin baru.
  Future<void> submitReport(DisciplineReport report) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client.from('discipline_reports').insert(report.toJson());
  }

  /// Kemaskini laporan sedia ada (Admin sahaja — dikuatkuasakan di lapisan UI).
  /// `.select()` mengembalikan baris yang terjejas; jika kosong bermakna
  /// tiada kebenaran (RLS) atau rekod tidak wujud — lemparkan ralat sebenar.
  Future<void> updateReport(int id, DisciplineReport report) async {
    if (SupabaseConfig.isPlaceholder) return;
    final res = await _client
        .from('discipline_reports')
        .update(report.toJson())
        .eq('id', id)
        .select();
    if ((res as List).isEmpty) {
      throw Exception(
          'Kemaskini tidak disimpan — semak kebenaran (RLS) untuk Admin.');
    }
  }

  /// Padam laporan (Admin sahaja — dikuatkuasakan di lapisan UI).
  Future<void> deleteReport(int id) async {
    if (SupabaseConfig.isPlaceholder) return;
    final res = await _client
        .from('discipline_reports')
        .delete()
        .eq('id', id)
        .select();
    if ((res as List).isEmpty) {
      throw Exception(
          'Padam tidak disimpan — semak kebenaran (RLS) untuk Admin.');
    }
  }

  /// Ambil kursus-kursus yang diajar oleh pensyarah (unik mengikut kursus + kelas),
  /// kerana satu kursus boleh diajar kepada beberapa kelas.
  Future<List<TimetableEntry>> fetchLecturerCourses(String lecturerId) async {
    final entries = await _timetable.fetchLecturerTimetable(lecturerId);
    final seen = <String>{};
    final unique = <TimetableEntry>[];
    for (final e in entries) {
      if (seen.add('${e.subjectCode}|${e.kelas ?? ''}')) unique.add(e);
    }
    return unique;
  }

  /// Ambil pelajar untuk pensyarah berdasarkan KELAS yang diajar.
  /// Hanya pelajar dalam pasangan (program, kelas) yang diajar dikembalikan.
  Future<List<Student>> fetchStudentsForLecturer(List<TimetableEntry> courses) async {
    final scope = _LecturerScope.fromCourses(courses);
    if (scope.units.isEmpty) return const [];
    if (SupabaseConfig.isPlaceholder) {
      return [
        for (final c in courses)
          ...List.generate(
            3,
            (i) => Student(
              id: 'stu-${c.departmentUnit}-${c.kelas ?? ""}-${i + 1}',
              fullName: 'Pelajar ${i + 1} (${c.kelas ?? c.departmentUnit})',
              studentId: '${c.departmentUnit}24${1000 + i}',
              programId: c.departmentUnit,
              kelas: c.kelas,
            ),
          ),
      ];
    }
    try {
      final data = await _client
          .from('students')
          .select()
          .inFilter('program_id', scope.units);
      return (data as List)
          .map((row) => Student.fromJson(row as Map<String, dynamic>))
          .where((s) => scope.allows(s.programId, s.kelas))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Ambil senarai pelajar untuk satu program (untuk kegunaan umum).
  Future<List<Student>> fetchStudents(String programId) async {
    if (SupabaseConfig.isPlaceholder) {
      return List.generate(
        6,
        (i) => Student(
          id: 'stu-$programId-${i + 1}',
          fullName: 'Pelajar ${i + 1}',
          studentId: '${programId}24${1000 + i}',
          programId: programId,
        ),
      );
    }
    try {
      final data = await _client
          .from('students')
          .select()
          .eq('program_id', programId);
      return (data as List)
          .map((row) => Student.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // -------------------- Mock --------------------
  List<DisciplineReport> _mockReports(UserProfile user) {
    final now = DateTime.now();
    return [
      DisciplineReport(
        id: 1,
        studentId: 'stu-dgs-1',
        studentName: 'Ahmad Bin Ali',
        issueType: 'Ketidakhadiran Kerap',
        severity: 'Tinggi',
        notes: 'Tidak hadir lebih 5 kali tanpa alasan.',
        reportedBy: user.id,
        reporterName: user.fullName,
        programId: 'DGS',
        departmentId: 'DGS',
        subjectCode: 'DGS1013',
        kelas: 'DGS1A',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      DisciplineReport(
        id: 2,
        studentId: 'stu-dgs-3',
        studentName: 'Muhammad Faiz Bin Rahman',
        issueType: 'Salah Laku',
        severity: 'Sederhana',
        notes: 'Mengganggu kelas.',
        reportedBy: user.id,
        reporterName: user.fullName,
        programId: 'DGS',
        departmentId: 'DGS',
        subjectCode: 'DGS2023',
        kelas: 'DGS2A',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      DisciplineReport(
        id: 3,
        studentId: 'stu-dgs-5',
        studentName: 'Lim Wei Jie',
        issueType: 'Plagiarisme',
        severity: 'Rendah',
        notes: 'Salinan tugasan dari rakan.',
        reportedBy: user.id,
        reporterName: user.fullName,
        programId: 'DGS',
        departmentId: 'DGS',
        subjectCode: 'DGS3033',
        kelas: 'DGS3A',
        createdAt: now.subtract(const Duration(days: 10)),
      ),
    ];
  }
}

/// Skop kelas seorang pensyarah, diterbitkan daripada jadual waktu.
/// Membenarkan pertanyaan/penapisan berdasarkan pasangan (program, kelas).
class _LecturerScope {
  /// Semua unit program yang diajar (untuk penapis `program_id IN (...)`).
  final List<String> units;

  /// Pasangan 'program|kelas' yang diajar secara khusus.
  final Set<String> _pairs;

  /// Unit yang mempunyai entri tanpa kelas — dibenarkan untuk semua kelas
  /// (sandaran apabila data kelas tidak lengkap).
  final Set<String> _unitsAllClasses;

  const _LecturerScope._(this.units, this._pairs, this._unitsAllClasses);

  factory _LecturerScope.fromCourses(List<TimetableEntry> courses) {
    final units = <String>{};
    final pairs = <String>{};
    final unitsAllClasses = <String>{};
    for (final c in courses) {
      final unit = c.departmentUnit;
      if (unit.isEmpty) continue;
      units.add(unit);
      final kelas = c.kelas;
      if (kelas == null || kelas.trim().isEmpty) {
        unitsAllClasses.add(unit);
      } else {
        pairs.add('$unit|$kelas');
      }
    }
    return _LecturerScope._(units.toList(), pairs, unitsAllClasses);
  }

  /// Adakah pasangan (program, kelas) ini termasuk dalam skop pensyarah?
  bool allows(String? programId, String? kelas) {
    if (programId == null) return false;
    if (_unitsAllClasses.contains(programId)) return true;
    return _pairs.contains('$programId|${kelas ?? ''}');
  }
}
