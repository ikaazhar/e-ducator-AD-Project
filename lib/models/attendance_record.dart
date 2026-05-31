// lib/models/attendance_record.dart
//
// Model rekod kehadiran. Memetakan jadual `public.attendance_records`.
// Status WAJIB salah satu daripada: 'Hadir', 'Tak Hadir', 'MC', 'CK'.
class AttendanceRecord {
  final String? id;
  final String timetableId;
  final String studentId;
  final String attendanceDate; // 'YYYY-MM-DD'
  final String attendanceStatus;
  final String? markedBy;

  const AttendanceRecord({
    this.id,
    required this.timetableId,
    required this.studentId,
    required this.attendanceDate,
    required this.attendanceStatus,
    this.markedBy,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String?,
      timetableId: json['timetable_id'] as String,
      studentId: json['student_id'] as String,
      attendanceDate: json['attendance_date'].toString(),
      attendanceStatus: (json['attendance_status'] ?? 'Hadir') as String,
      markedBy: json['marked_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'timetable_id': timetableId,
        'student_id': studentId,
        'attendance_date': attendanceDate,
        'attendance_status': attendanceStatus,
        'marked_by': markedBy,
      };
}

/// Pilihan status kehadiran yang sah.
const List<String> kAttendanceStatuses = ['Hadir', 'Tak Hadir', 'MC', 'CK'];
