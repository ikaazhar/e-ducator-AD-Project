// lib/models/room.dart
//
// Model bilik. Memetakan jadual `public.rooms`.
class Room {
  final int id;
  final String roomName;
  final String status; // 'Available', 'Maintenance', 'Archived'
  final String? updatedBy;
  final DateTime? updatedAt;

  const Room({
    required this.id,
    required this.roomName,
    required this.status,
    this.updatedBy,
    this.updatedAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as int,
      roomName: (json['room_name'] ?? '') as String,
      status: (json['status'] ?? 'Available') as String,
      updatedBy: json['updated_by'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}

const List<String> kRoomStatuses = ['Available', 'Maintenance', 'Archived'];
