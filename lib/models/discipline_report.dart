// lib/models/discipline_report.dart
//
// Model laporan disiplin pelajar. Memetakan jadual `public.discipline_reports`.
class DisciplineReport {
  final int? id;
  final String studentId;
  final String? studentName;
  final String issueType;     // 'Ketidakhadiran Kerap', 'Salah Laku', 'Ketidaksopanan', 'Plagiarisme'
  final String severity;      // 'Rendah', 'Sederhana', 'Tinggi'
  final String? notes;
  final String? reportedBy;
  final String? reporterName;
  final String? programId;
  final String? departmentId;
  final String? subjectCode;
  final String? subjectName;
  final String? kelas;
  final DateTime? createdAt;

  const DisciplineReport({
    this.id,
    required this.studentId,
    this.studentName,
    required this.issueType,
    required this.severity,
    this.notes,
    this.reportedBy,
    this.reporterName,
    this.programId,
    this.departmentId,
    this.subjectCode,
    this.subjectName,
    this.kelas,
    this.createdAt,
  });

  factory DisciplineReport.fromJson(Map<String, dynamic> json) {
    final student = json['students'];
    final reporter = json['profiles'];
    return DisciplineReport(
      id: json['id'] as int?,
      studentId: json['student_id'] as String,
      studentName: student is Map<String, dynamic>
          ? student['full_name'] as String?
          : json['student_name'] as String?,
      kelas: student is Map<String, dynamic>
          ? student['kelas'] as String?
          : json['kelas'] as String?,
      issueType: (json['issue_type'] ?? 'Salah Laku') as String,
      severity: (json['severity'] ?? 'Rendah') as String,
      notes: json['notes'] as String?,
      reportedBy: json['reported_by'] as String?,
      reporterName: reporter is Map<String, dynamic>
          ? reporter['full_name'] as String?
          : null,
      programId: json['program_id'] as String?,
      departmentId: json['department_id'] as String?,
      subjectCode: json['subject_code'] as String?,
      subjectName: json['subject_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'issue_type': issueType,
        'severity': severity,
        'notes': notes,
        'reported_by': reportedBy,
        'program_id': programId,
        'department_id': departmentId,
        'subject_code': subjectCode,
      };

  DisciplineReport copyWith({
    String? studentId,
    String? studentName,
    String? issueType,
    String? severity,
    String? notes,
    String? subjectCode,
    String? subjectName,
  }) {
    return DisciplineReport(
      id: id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      issueType: issueType ?? this.issueType,
      severity: severity ?? this.severity,
      notes: notes ?? this.notes,
      reportedBy: reportedBy,
      reporterName: reporterName,
      programId: programId,
      departmentId: departmentId,
      subjectCode: subjectCode ?? this.subjectCode,
      subjectName: subjectName ?? this.subjectName,
      kelas: kelas,
      createdAt: createdAt,
    );
  }
}

const List<String> kIssueTypes = [
  'Ketidakhadiran Kerap',
  'Salah Laku',
  'Ketidaksopanan',
  'Plagiarisme',
];

const List<String> kSeverityLevels = ['Rendah', 'Sederhana', 'Tinggi'];
