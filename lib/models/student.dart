// lib/models/student.dart
//
// Model pelajar. Memetakan jadual `public.students`.
class Student {
  final String id;
  final String fullName;
  final String studentId;
  final String programId;
  final String? kelas;

  const Student({
    required this.id,
    required this.fullName,
    required this.studentId,
    required this.programId,
    this.kelas,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      fullName: (json['full_name'] ?? '') as String,
      studentId: (json['student_id'] ?? '') as String,
      programId: (json['program_id'] ?? '') as String,
      kelas: json['kelas'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'student_id': studentId,
        'program_id': programId,
        'kelas': kelas,
      };
}
