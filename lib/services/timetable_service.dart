// lib/services/timetable_service.dart
//
// Perkhidmatan untuk modul jadual waktu (M4 + M5).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/timetable_entry.dart';

class TimetableService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Ambil jadual waktu untuk seorang pensyarah, termasuk nama bilik.
  Future<List<TimetableEntry>> fetchLecturerTimetable(String lecturerId) async {
    if (SupabaseConfig.isPlaceholder) return _mockEntries();
    try {
      final data = await _client
          .from('timetable')
          .select('*, rooms(room_name)')
          .eq('lecturer_id', lecturerId);
      return (data as List)
          .map((row) => TimetableEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockEntries();
    }
  }

  /// Ambil semua entri jadual (untuk Admin / Ketua Program). Tapis ikut unit jika perlu.
  Future<List<TimetableEntry>> fetchAllTimetable({String? departmentUnit}) async {
    if (SupabaseConfig.isPlaceholder) return _mockEntries();
    try {
      var query = _client.from('timetable').select('*, rooms(room_name)');
      if (departmentUnit != null) {
        query = query.eq('department_unit', departmentUnit);
      }
      final data = await query;
      return (data as List)
          .map((row) => TimetableEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockEntries();
    }
  }

  /// Periksa sama ada sesi telah dihantar oleh pensyarah pada tarikh tertentu.
  Future<bool> checkSessionSubmitted({
    required String timetableId,
    required String attendanceDate,
  }) async {
    if (SupabaseConfig.isPlaceholder) return false;
    try {
      final result = await _client
          .from('attendance_records')
          .select()
          .eq('timetable_id', timetableId)
          .eq('attendance_date', attendanceDate);
      return (result as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Periksa konflik bilik sebelum memasukkan slot baru.
  /// Mengembalikan `true` jika tiada konflik.
  Future<bool> isRoomSlotFree({
    required int roomId,
    required String day,
    required String startTime,
    required String endTime,
  }) async {
    if (SupabaseConfig.isPlaceholder) return true;
    try {
      final conflicts = await _client
          .from('timetable')
          .select()
          .eq('room_id', roomId)
          .eq('day', day)
          .lt('start_time', endTime)
          .gt('end_time', startTime);
      return (conflicts as List).isEmpty;
    } catch (_) {
      return true;
    }
  }

  /// Masukkan entri jadual baru.
  Future<void> insertTimetable(TimetableEntry entry, {required String createdBy}) async {
    if (SupabaseConfig.isPlaceholder) return;
    final payload = entry.toJson()..['created_by'] = createdBy;
    await _client.from('timetable').insert(payload);
  }

  /// Padam entri.
  Future<void> deleteTimetable(String id) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client.from('timetable').delete().eq('id', id);
  }

  // -------------------- Mock --------------------
  List<TimetableEntry> _mockEntries() {
    const id1 = '11111111-1111-1111-1111-111111111111';
    const id2 = '22222222-2222-2222-2222-222222222222';
    const id3 = '33333333-3333-3333-3333-333333333333';
    return const [
      TimetableEntry(
        id: id1,
        subjectCode: 'DGS1013',
        subjectName: 'Asas Pengaturcaraan',
        departmentUnit: 'DGS',
        lecturerId: 'mock-user-id',
        lecturerName: 'Pengguna Demo',
        day: 'Isnin',
        startTime: '08:00:00',
        endTime: '10:00:00',
        roomId: 1,
        roomName: 'Bilik A1',
        session: '2025/01',
      ),
      TimetableEntry(
        id: id2,
        subjectCode: 'DGS2023',
        subjectName: 'Sistem Pangkalan Data',
        departmentUnit: 'DGS',
        lecturerId: 'mock-user-id',
        lecturerName: 'Pengguna Demo',
        day: 'Selasa',
        startTime: '10:00:00',
        endTime: '12:00:00',
        roomId: 2,
        roomName: 'Makmal B2',
        session: '2025/01',
      ),
      TimetableEntry(
        id: id3,
        subjectCode: 'DGS3033',
        subjectName: 'Pembangunan Aplikasi Mudah Alih',
        departmentUnit: 'DGS',
        lecturerId: 'mock-user-id',
        lecturerName: 'Pengguna Demo',
        day: 'Rabu',
        startTime: '14:00:00',
        endTime: '16:00:00',
        roomId: 3,
        roomName: 'Makmal C1',
        session: '2025/01',
      ),
    ];
  }
}
