// lib/models/attendance_summary.dart
//
// Model ringkasan kehadiran terhitung untuk Modul 3 (Pelaporan).
class AttendanceSummary {
  final String studentId;
  final String studentName;
  final String classId;
  final double attendancePercent;
  final int totalAbsences;
  final int countedRecords;
  final int warningLevel; // 0, 1, 2, 3
  final String riskStatus; // 'Selamat', 'Berisiko', 'Kritikal'

  const AttendanceSummary({
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.attendancePercent,
    required this.totalAbsences,
    required this.countedRecords,
    required this.warningLevel,
    required this.riskStatus,
  });
}
