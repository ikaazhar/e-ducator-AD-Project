// lib/services/timetable_service.dart
//
// Perkhidmatan untuk modul jadual waktu (M4 + M5).
// Pensyarah diambil terus dari jadual `profiles` menggunakan foreign key join.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/timetable_entry.dart';
import '../models/user_profile.dart';

class TimetableService {
  SupabaseClient get _client => Supabase.instance.client;

  // ─────────────────────────────────────────────
  // FETCH
  // ─────────────────────────────────────────────

  /// Ambil jadual untuk seorang pensyarah — nama pensyarah & bilik disertakan.
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

  /// Ambil semua entri jadual — untuk Admin / Ketua Program.
  /// Tapis ikut unit jabatan jika diperlukan.
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

  /// Ambil senarai pensyarah untuk unit jabatan tertentu dari `profiles`.
  /// Digunakan untuk dropdown dalam borang tambah entri.
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

  // ─────────────────────────────────────────────
  // CONFLICT CHECK
  // ─────────────────────────────────────────────

  /// Semak sama ada slot bilik bebas daripada konflik jadual tetap.
  /// Mengembalikan `true` jika tiada konflik (selamat untuk masukkan).
  /// Hantar [excludeId] semasa mengedit supaya entri semasa diabaikan.
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

  // ─────────────────────────────────────────────
  // INSERT / UPDATE / DELETE
  // ─────────────────────────────────────────────

  /// Masukkan entri jadual baru.
  Future<void> insertTimetable(
    TimetableEntry entry, {
    required String createdBy,
  }) async {
    if (SupabaseConfig.isPlaceholder) return;
    final payload = entry.toJson()..['created_by'] = createdBy;
    await _client.from('timetable').insert(payload);
  }

  /// Kemaskini entri sedia ada.
  Future<void> updateTimetable(
    String id,
    TimetableEntry entry,
  ) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client.from('timetable').update(entry.toJson()).eq('id', id);
  }

  /// Padam entri jadual.
  Future<void> deleteTimetable(String id) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client.from('timetable').delete().eq('id', id);
  }

  // ─────────────────────────────────────────────
  // ATTENDANCE INTEGRATION (M1)
  // ─────────────────────────────────────────────

  /// Semak sama ada kehadiran telah dihantar untuk sesi ini pada tarikh tertentu.
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

  // ─────────────────────────────────────────────
  // STATS (untuk summary bar di skrin M4)
  // ─────────────────────────────────────────────

  /// Kira statistik ringkasan jadual untuk unit tertentu (atau semua).
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
      var query = _client.from('timetable').select(
            'id, room_id, lecturer_id, day',
          );
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

  // ─────────────────────────────────────────────
  // MOCK DATA
  // ─────────────────────────────────────────────
  List<TimetableEntry> _mockEntries() {
    return const [
      TimetableEntry(
        id: '11111111-1111-1111-1111-111111111111',
        subjectCode: 'DED10044',
        subjectName: 'Teknologi Pendawaian Elektrik',
        departmentUnit: 'DED',
        lecturerId: 'mock-user-id',
        lecturerName: 'Pn. Syarifah',
        day: 'Isnin',
        startTime: '08:00:00',
        endTime: '12:00:00',
        roomId: 1,
        roomName: 'Wiring Bay 3',
        session: 'JAN-JUN 2026',
      ),
      TimetableEntry(
        id: '22222222-2222-2222-2222-222222222222',
        subjectCode: 'DUM10122',
        subjectName: 'Matematik Kejuruteraan',
        departmentUnit: 'DED',
        lecturerId: 'mock-user-id-2',
        lecturerName: 'Pn. Rafidah',
        day: 'Rabu',
        startTime: '08:00:00',
        endTime: '10:00:00',
        roomId: 2,
        roomName: 'PA BK 13',
        session: 'JAN-JUN 2026',
      ),
      TimetableEntry(
        id: '33333333-3333-3333-3333-333333333333',
        subjectCode: 'DKV10213',
        subjectName: 'Mesin Elektrik',
        departmentUnit: 'DED',
        lecturerId: 'mock-user-id-3',
        lecturerName: 'Pn. Norhatini',
        day: 'Rabu',
        startTime: '10:00:00',
        endTime: '13:00:00',
        roomId: 3,
        roomName: 'Elec Machine Lab',
        session: 'JAN-JUN 2026',
      ),
    ];
  }
}

// ─────────────────────────────────────────────
// STATS MODEL
// ─────────────────────────────────────────────
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
