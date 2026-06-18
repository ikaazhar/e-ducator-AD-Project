// lib/services/timetable_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/timetable_entry.dart';
import '../models/user_profile.dart';

class TimetableService {
  SupabaseClient get _client => Supabase.instance.client;

  // ─── FETCH ───────────────────────────────────────────────

  Future<List<TimetableEntry>> fetchLecturerTimetable(String lecturerId) async {
    if (SupabaseConfig.isPlaceholder) return _mockEntries();
    try {
      final data = await _client
          .from('timetable')
          .select('*, profiles!lecturer_id(full_name), rooms(room_name)')
          .eq('lecturer_id', lecturerId)
          .order('day')
          .order('start_time');
      return (data as List)
          .map((row) => TimetableEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockEntries();
    }
  }

  Future<List<TimetableEntry>> fetchAllTimetable({
    String? departmentUnit,
  }) async {
    if (SupabaseConfig.isPlaceholder) return _mockEntries();
    try {
      var query = _client
          .from('timetable')
          .select('*, profiles!lecturer_id(full_name), rooms(room_name)');
      if (departmentUnit != null) {
        query = query.eq('department_unit', departmentUnit);
      }
      final data = await query.order('day').order('start_time');
      return (data as List)
          .map((row) => TimetableEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockEntries();
    }
  }

  /// Ambil senarai pensyarah dari profiles mengikut unit jabatan.
  Future<List<UserProfile>> fetchLecturersByUnit(String departmentUnit) async {
    if (SupabaseConfig.isPlaceholder) {
      return [
        UserProfile(
          id: 'mock-user-id',
          fullName: 'Pengguna Demo',
          email: 'lecturer@ikmjb.edu.my',
          role: 'Lecturer',
          departmentUnit: departmentUnit,
        ),
      ];
    }
    try {
      final data = await _client
          .from('profiles')
          .select('id, full_name, email, role, department_unit')
          .eq('role', 'Lecturer')
          .eq('department_unit', departmentUnit)
          .order('full_name');
      return (data as List)
          .map((r) => UserProfile.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Ambil senarai kelas (kelas) yang unik dari jadual students
  /// mengikut program_id — digunakan untuk dropdown kelas dalam borang M4.
  Future<List<String>> fetchKelasByUnit(String departmentUnit) async {
    if (SupabaseConfig.isPlaceholder) {
      return ['${departmentUnit}4A', '${departmentUnit}4B'];
    }
    try {
      // Fetch kelas from both students table AND timetable table so that
      // newly created classes (with no students yet) still appear in the dropdown.
      final results = await Future.wait([
        _client
            .from('students')
            .select('kelas')
            .eq('program_id', departmentUnit),
        _client
            .from('timetable')
            .select('kelas')
            .eq('department_unit', departmentUnit),
      ]);

      final all = <String>{};
      for (final data in results) {
        for (final r in (data as List)) {
          final k = (r as Map<String, dynamic>)['kelas'] as String?;
          if (k != null && k.isNotEmpty) all.add(k);
        }
      }
      final sorted = all.toList()..sort();
      return sorted;
    } catch (_) {
      return const [];
    }
  }

  // ─── CONFLICT CHECK ──────────────────────────────────────

  Future<bool> isRoomSlotFree({
    required int roomId,
    required String day,
    required String startTime,
    required String endTime,
    String? excludeId,
  }) async {
    if (SupabaseConfig.isPlaceholder) return true;
    try {
      var query = _client
          .from('timetable')
          .select('id')
          .eq('room_id', roomId)
          .eq('day', day)
          .lt('start_time', endTime)
          .gt('end_time', startTime);
      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }
      final conflicts = await query;
      return (conflicts as List).isEmpty;
    } catch (_) {
      return true;
    }
  }

  // ─── INSERT / UPDATE / DELETE ────────────────────────────

  Future<void> insertTimetable(
    TimetableEntry entry, {
    required String createdBy,
  }) async {
    if (SupabaseConfig.isPlaceholder) return;
    final payload = entry.toJson()..['created_by'] = createdBy;
    await _client.from('timetable').insert(payload);
  }

  Future<void> updateTimetable(String id, TimetableEntry entry) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client.from('timetable').update(entry.toJson()).eq('id', id);
  }

  Future<void> deleteTimetable(String id) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client.from('timetable').delete().eq('id', id);
  }

  // ─── ATTENDANCE INTEGRATION ──────────────────────────────

  Future<bool> checkSessionSubmitted({
    required String timetableId,
    required String attendanceDate,
  }) async {
    if (SupabaseConfig.isPlaceholder) return false;
    try {
      final result = await _client
          .from('attendance_records')
          .select('id')
          .eq('timetable_id', timetableId)
          .eq('attendance_date', attendanceDate);
      return (result as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ─── STATS ───────────────────────────────────────────────

  Future<TimetableStats> fetchStats({String? departmentUnit}) async {
    if (SupabaseConfig.isPlaceholder) {
      return const TimetableStats(
        totalClasses: 3,
        roomsInUse: 3,
        lecturersScheduled: 1,
        classesToday: 1,
      );
    }
    try {
      var query = _client.from('timetable').select('id, room_id, lecturer_id, day');
      if (departmentUnit != null) {
        query = query.eq('department_unit', departmentUnit);
      }
      final data = await query;
      final list = data as List;
      final today = _todayMalay();
      final todayList = list.where((e) => e['day'] == today).toList();
      final rooms = list.map((e) => e['room_id']).toSet();
      final lecturers = list.map((e) => e['lecturer_id']).toSet();
      return TimetableStats(
        totalClasses: list.length,
        roomsInUse: rooms.length,
        lecturersScheduled: lecturers.length,
        classesToday: todayList.length,
      );
    } catch (_) {
      return const TimetableStats(
        totalClasses: 0,
        roomsInUse: 0,
        lecturersScheduled: 0,
        classesToday: 0,
      );
    }
  }

  String _todayMalay() {
    const map = {
      DateTime.monday: 'Isnin',
      DateTime.tuesday: 'Selasa',
      DateTime.wednesday: 'Rabu',
      DateTime.thursday: 'Khamis',
      DateTime.friday: 'Jumaat',
    };
    return map[DateTime.now().weekday] ?? '';
  }

  // ─── MOCK DATA ───────────────────────────────────────────

  List<TimetableEntry> _mockEntries() {
    return const [
      TimetableEntry(
        id: '11111111-1111-1111-1111-111111111111',
        subjectCode: 'DGS1013',
        subjectName: 'Asas Pengaturcaraan',
        departmentUnit: 'DGS',
        lecturerId: 'mock-user-id',
        lecturerName: 'Pn. Syarifah',
        day: 'Isnin',
        startTime: '08:00:00',
        endTime: '10:00:00',
        roomId: 1,
        roomName: 'Bilik Kuliah 1',
        session: 'JAN-JUN 2026',
        kelas: 'DGS4A',
      ),
      TimetableEntry(
        id: '22222222-2222-2222-2222-222222222222',
        subjectCode: 'DGS2023',
        subjectName: 'Sistem Pangkalan Data',
        departmentUnit: 'DGS',
        lecturerId: 'mock-user-id-2',
        lecturerName: 'En. Rafidah',
        day: 'Selasa',
        startTime: '10:00:00',
        endTime: '12:00:00',
        roomId: 2,
        roomName: 'Comp Lab 1',
        session: 'JAN-JUN 2026',
        kelas: 'DGS4B',
      ),
      TimetableEntry(
        id: '33333333-3333-3333-3333-333333333333',
        subjectCode: 'DPP1013',
        subjectName: 'Asas Pemasaran',
        departmentUnit: 'DPP',
        lecturerId: 'mock-user-id-3',
        lecturerName: 'Pn. Norhatini',
        day: 'Rabu',
        startTime: '14:00:00',
        endTime: '16:00:00',
        roomId: 3,
        roomName: 'Bilik Kuliah 2',
        session: 'JAN-JUN 2026',
        kelas: 'DPP4A',
      ),
    ];
  }
}

// ─── STATS MODEL ─────────────────────────────────────────
class TimetableStats {
  final int totalClasses;
  final int roomsInUse;
  final int lecturersScheduled;
  final int classesToday;

  const TimetableStats({
    required this.totalClasses,
    required this.roomsInUse,
    required this.lecturersScheduled,
    required this.classesToday,
  });
}
