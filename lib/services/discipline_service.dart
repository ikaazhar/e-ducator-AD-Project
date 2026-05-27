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
  /// - Lecturer: semua laporan untuk pelajar dalam kursus yang diajar
  /// - Ketua Program: semua dalam program (department_unit)
  /// - Ketua Jabatan: semua dalam jabatan
  /// - Admin: semua rekod
  Future<List<DisciplineReport>> fetchReports(UserProfile user) async {
    if (SupabaseConfig.isPlaceholder) return _mockReports(user);
    try {
      final base = _client
          .from('discipline_reports')
          .select('*, students(full_name), profiles!discipline_reports_reported_by_fkey(full_name)');

      dynamic query = base;
      switch (user.role) {
        case 'Lecturer':
          final programUnits = await _lecturerProgramUnits(user.id);
          if (programUnits.isEmpty) return const [];
          query = base.inFilter('program_id', programUnits);
          break;
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
        case 'Timbalan Pengarah Akademik':
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
  Future<void> updateReport(int id, DisciplineReport report) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client.from('discipline_reports').update(report.toJson()).eq('id', id);
  }

  /// Padam laporan (Admin sahaja — dikuatkuasakan di lapisan UI).
  Future<void> deleteReport(int id) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client.from('discipline_reports').delete().eq('id', id);
  }

  /// Ambil kursus-kursus yang diajar oleh pensyarah (unik mengikut subject_code).
  Future<List<TimetableEntry>> fetchLecturerCourses(String lecturerId) async {
    final entries = await _timetable.fetchLecturerTimetable(lecturerId);
    final seen = <String>{};
    final unique = <TimetableEntry>[];
    for (final e in entries) {
      if (seen.add(e.subjectCode)) unique.add(e);
    }
    return unique;
  }

  /// Ambil pelajar untuk pensyarah berdasarkan unit program yang diajar.
  Future<List<Student>> fetchStudentsForLecturer(List<String> programUnits) async {
    if (programUnits.isEmpty) return const [];
    if (SupabaseConfig.isPlaceholder) {
      return [
        for (final p in programUnits) ...List.generate(
          3,
          (i) => Student(
            id: 'stu-$p-${i + 1}',
            fullName: 'Pelajar ${i + 1} ($p)',
            studentId: '${p}24${1000 + i}',
            programId: p,
          ),
        ),
      ];
    }
    try {
      final data = await _client
          .from('students')
          .select()
          .inFilter('program_id', programUnits);
      return (data as List)
          .map((row) => Student.fromJson(row as Map<String, dynamic>))
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

  Future<List<String>> _lecturerProgramUnits(String lecturerId) async {
    final entries = await _timetable.fetchLecturerTimetable(lecturerId);
    return entries.map((e) => e.departmentUnit).toSet().toList();
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
        createdAt: now.subtract(const Duration(days: 10)),
      ),
    ];
  }
}
