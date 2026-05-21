// lib/services/room_service.dart
//
// Perkhidmatan tempahan bilik (Modul 6).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/booking.dart';
import '../models/room.dart';

class RoomService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Ambil semua bilik (untuk paparan Admin).
  Future<List<Room>> fetchAllRooms() async {
    if (SupabaseConfig.isPlaceholder) return _mockRooms();
    try {
      final data = await _client.from('rooms').select().order('room_name');
      return (data as List)
          .map((row) => Room.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockRooms();
    }
  }

  /// Ambil bilik yang status = 'Available'.
  Future<List<Room>> fetchAvailableRooms() async {
    if (SupabaseConfig.isPlaceholder) {
      return _mockRooms().where((r) => r.status == 'Available').toList();
    }
    try {
      final data = await _client
          .from('rooms')
          .select()
          .eq('status', 'Available')
          .order('room_name');
      return (data as List)
          .map((row) => Room.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _mockRooms().where((r) => r.status == 'Available').toList();
    }
  }

  /// Pencegahan tempahan berganda.
  Future<bool> isBookingSlotFree({
    required int roomId,
    required String bookingDate,
    required String startTime,
    required String endTime,
  }) async {
    if (SupabaseConfig.isPlaceholder) return true;
    try {
      final existing = await _client
          .from('bookings')
          .select()
          .eq('room_id', roomId)
          .eq('booking_date', bookingDate)
          .lt('start_time', endTime)
          .gt('end_time', startTime);
      return (existing as List).isEmpty;
    } catch (_) {
      return true;
    }
  }

  /// Periksa konflik dengan jadual tetap (timetable).
  Future<bool> isTimetableSlotFree({
    required int roomId,
    required String day,
    required String startTime,
    required String endTime,
  }) async {
    if (SupabaseConfig.isPlaceholder) return true;
    try {
      final locks = await _client
          .from('timetable')
          .select()
          .eq('room_id', roomId)
          .eq('day', day)
          .lt('start_time', endTime)
          .gt('end_time', startTime);
      return (locks as List).isEmpty;
    } catch (_) {
      return true;
    }
  }

  /// Cipta tempahan baharu.
  Future<void> createBooking(Booking booking) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client.from('bookings').insert(booking.toJson());
  }

  /// Ambil tempahan untuk satu bilik pada satu tarikh.
  Future<List<Booking>> fetchBookingsForRoomDate({
    required int roomId,
    required String date,
  }) async {
    if (SupabaseConfig.isPlaceholder) return const [];
    try {
      final data = await _client
          .from('bookings')
          .select('*, rooms(room_name)')
          .eq('room_id', roomId)
          .eq('booking_date', date);
      return (data as List)
          .map((row) => Booking.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Operasi Admin.
  Future<void> insertRoom(String roomName) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client.from('rooms').insert({'room_name': roomName, 'status': 'Available'});
  }

  Future<void> updateRoom({
    required int id,
    String? roomName,
    String? status,
    String? updatedBy,
  }) async {
    if (SupabaseConfig.isPlaceholder) return;
    final payload = <String, dynamic>{};
    if (roomName != null) payload['room_name'] = roomName;
    if (status != null) payload['status'] = status;
    if (updatedBy != null) payload['updated_by'] = updatedBy;
    payload['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _client.from('rooms').update(payload).eq('id', id);
  }

  /// Padam lembut: tetapkan status kepada 'Archived'.
  Future<void> archiveRoom(int id, {String? updatedBy}) =>
      updateRoom(id: id, status: 'Archived', updatedBy: updatedBy);

  // -------------------- Mock --------------------
  List<Room> _mockRooms() {
    return const [
      Room(id: 1, roomName: 'Bilik A1', status: 'Available'),
      Room(id: 2, roomName: 'Makmal B2', status: 'Available'),
      Room(id: 3, roomName: 'Makmal C1', status: 'Available'),
      Room(id: 4, roomName: 'Dewan Utama', status: 'Maintenance'),
      Room(id: 5, roomName: 'Bilik D3', status: 'Available'),
    ];
  }
}
