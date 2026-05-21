// lib/models/booking.dart
//
// Model tempahan bilik. Memetakan jadual `public.bookings`.
class Booking {
  final String? id;
  final int roomId;
  final String? roomName;
  final String userId;
  final String bookingDate; // 'YYYY-MM-DD'
  final String startTime;
  final String endTime;
  final String? purpose;
  final DateTime? createdAt;

  const Booking({
    this.id,
    required this.roomId,
    this.roomName,
    required this.userId,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    this.purpose,
    this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final rooms = json['rooms'];
    return Booking(
      id: json['id'] as String?,
      roomId: json['room_id'] as int,
      roomName: rooms is Map<String, dynamic>
          ? rooms['room_name'] as String?
          : null,
      userId: json['user_id'] as String,
      bookingDate: json['booking_date'].toString(),
      startTime: json['start_time'].toString(),
      endTime: json['end_time'].toString(),
      purpose: json['purpose'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'room_id': roomId,
        'user_id': userId,
        'booking_date': bookingDate,
        'start_time': startTime,
        'end_time': endTime,
        'purpose': purpose,
      };
}
