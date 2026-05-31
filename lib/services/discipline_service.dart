// lib/services/discipline_service.dart
//
// Perkhidmatan laporan disiplin (Modul 2). Skop pertanyaan berdasarkan RBAC.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/discipline_report.dart';
import '../models/student.dart';
import '../models/user_profile.dart';

class DisciplineService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Ambil laporan disiplin dengan RBAC bersepadu.
  /// - Lecturer: hanya laporan sendiri
  /// - Ketua Program: semua dalam program (department_unit)
  /// - Ketua Jabatan: semua dalam jabatan
  /// - Admin: semua rekod
  Future<List<DisciplineReport>> fetchReports(UserProfile user) async {
    if (SupabaseConfig.isPlaceholder) return _mockReports(user);
    try {
      var query = _client
          .from('discipline_reports')
          .select('*, students(full_name), profiles!discipline_reports_reported_by_fkey(full_name)');

      switch (user.role) {
        case 'Lecturer':
          query = query.eq('reported_by', user.id);
          break;
        case 'Ketua Program':
          if (user.departmentUnit != null) {
            query = query.eq('program_id', user.departmentUnit!);
          }
          break;
        case 'Ketua Jabatan':
          if (user.departmentUnit != null) {
            query = query.eq('department_id', user.departmentUnit!);
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

  /// Ambil senarai pelajar (untuk dropdown borang).
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
        createdAt: now.subtract(const Duration(days: 10)),
      ),
    ];
  }
}
