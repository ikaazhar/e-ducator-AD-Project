// lib/models/timetable_entry.dart
//
// Model entri jadual waktu. Memetakan jadual `public.timetable`.

class TimetableEntry {
  final String id;
  final String subjectCode;
  final String subjectName;
  final String departmentUnit;
  final String? lecturerId;
  final String? lecturerName;
  final String day;
  final String startTime; // 'HH:MM:SS'
  final String endTime;
  final int? roomId;
  final String? roomName;
  final String? session;

  const TimetableEntry({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.departmentUnit,
    this.lecturerId,
    this.lecturerName,
    required this.day,
    required this.startTime,
    required this.endTime,
    this.roomId,
    this.roomName,
    this.session,
  });

  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    // Handle joined lecturer profile (profiles!lecturer_id)
    final profileJoin = json['profiles'];
    final String? lecturerName = profileJoin is Map<String, dynamic>
        ? profileJoin['full_name'] as String?
        : json['lecturer_name'] as String?;

    // Handle joined room
    final roomJoin = json['rooms'];
    final String? roomName = roomJoin is Map<String, dynamic>
        ? roomJoin['room_name'] as String?
        : json['room_name'] as String?;

    return TimetableEntry(
      id: json['id'] as String,
      subjectCode: (json['subject_code'] ?? '') as String,
      subjectName: (json['subject_name'] ?? '') as String,
      departmentUnit: (json['department_unit'] ?? '') as String,
      lecturerId: json['lecturer_id'] as String?,
      lecturerName: lecturerName,
      day: (json['day'] ?? 'Isnin') as String,
      startTime: (json['start_time'] ?? '00:00:00').toString(),
      endTime: (json['end_time'] ?? '00:00:00').toString(),
      roomId: json['room_id'] as int?,
      roomName: roomName,
      session: json['session'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'subject_code': subjectCode,
        'subject_name': subjectName,
        'department_unit': departmentUnit,
        'lecturer_id': lecturerId,
        'day': day,
        'start_time': startTime,
        'end_time': endTime,
        'room_id': roomId,
        'session': session,
      };

  /// Returns a display-friendly time slot string e.g. "08:00 - 10:00"
  String get timeSlot {
    String hhmm(String s) => s.length >= 5 ? s.substring(0, 5) : s;
    return '${hhmm(startTime)} - ${hhmm(endTime)}';
  }

  /// Tentukan jika slot ini sedang berlangsung berbanding waktu semasa.
  bool isCurrentlyOngoing(DateTime now) {
    if (!_dayMatches(now)) return false;
    final start = _parseDuration(startTime);
    final end = _parseDuration(endTime);
    final cur = Duration(hours: now.hour, minutes: now.minute);
    return cur >= start && cur < end;
  }

  /// Tentukan jika slot ini akan datang pada hari ini.
  bool isUpcomingToday(DateTime now) {
    if (!_dayMatches(now)) return false;
    final cur = Duration(hours: now.hour, minutes: now.minute);
    return cur < _parseDuration(startTime);
  }

  bool _dayMatches(DateTime now) {
    const map = {
      DateTime.monday: 'Isnin',
      DateTime.tuesday: 'Selasa',
      DateTime.wednesday: 'Rabu',
      DateTime.thursday: 'Khamis',
      DateTime.friday: 'Jumaat',
    };
    return map[now.weekday] == day;
  }

  Duration _parseDuration(String t) {
    final parts = t.split(':');
    return Duration(
      hours: int.tryParse(parts[0]) ?? 0,
      minutes: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }
}
