// lib/screens/discipline_form_screen.dart
//
// Modul 2 — Halaman 2: Borang Laporan Disiplin (Cipta + Edit).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/discipline_report.dart';
import '../models/student.dart';
import '../models/timetable_entry.dart';
import '../providers/user_provider.dart';
import '../services/discipline_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

class DisciplineFormScreen extends StatefulWidget {
  /// Laporan untuk diedit (mod Admin). Jika null → mod cipta (pensyarah).
  final DisciplineReport? report;

  const DisciplineFormScreen({super.key, this.report});

  @override
  State<DisciplineFormScreen> createState() => _DisciplineFormScreenState();
}

class _DisciplineFormScreenState extends State<DisciplineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = DisciplineService();
  final _notesCtrl = TextEditingController();

  DisciplineReport? _editing;
  bool get _isEdit => _editing != null;

  List<TimetableEntry> _courses = const [];
  List<Student> _students = const [];
  TimetableEntry? _selectedCourse;
  Student? _selectedStudent;
  String _issueType = kIssueTypes.first;
  String _severity = 'Rendah';
  bool _loading = true;
  bool _saving = false;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    // Utamakan parameter konstruktor; sandaran kepada argumen laluan bernama.
    final routeArg = ModalRoute.of(context)?.settings.arguments;
    final arg = widget.report ?? (routeArg is DisciplineReport ? routeArg : null);
    if (arg != null) {
      _editing = arg;
      _issueType = kIssueTypes.contains(arg.issueType) ? arg.issueType : kIssueTypes.first;
      _severity = kSeverityLevels.contains(arg.severity) ? arg.severity : 'Rendah';
      _notesCtrl.text = arg.notes ?? '';
    }
    _load();
  }

  Future<void> _load() async {
    if (_isEdit) {
      // Mod edit (Admin): tiada perlu muat dropdown kursus/pelajar.
      if (mounted) setState(() => _loading = false);
      return;
    }
    final user = context.read<UserProvider>().profile!;
    _courses = await _service.fetchLecturerCourses(user.id);
    _students = await _service.fetchStudentsForLecturer(_courses);
    if (mounted) setState(() => _loading = false);
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'Tinggi':
        return AppTheme.severityTinggi;
      case 'Sederhana':
        return AppTheme.severitySederhana;
      default:
        return AppTheme.severityRendah;
    }
  }

  List<Student> get _studentsForSelectedCourse {
    if (_selectedCourse == null) return _students;
    final course = _selectedCourse!;
    return _students
        .where((s) =>
            s.programId == course.departmentUnit &&
            (course.kelas == null || s.kelas == course.kelas))
        .toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit) {
      if (_selectedCourse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sila pilih kursus.')),
        );
        return;
      }
      if (_selectedStudent == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sila pilih pelajar.')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final user = context.read<UserProvider>().profile!;
      if (_isEdit) {
        final updated = _editing!.copyWith(
          issueType: _issueType,
          severity: _severity,
          notes: _notesCtrl.text.trim(),
        );
        await _service.updateReport(_editing!.id!, updated);
      } else {
        await _service.submitReport(
          DisciplineReport(
            studentId: _selectedStudent!.id,
            issueType: _issueType,
            severity: _severity,
            notes: _notesCtrl.text.trim(),
            reportedBy: user.id,
            programId: _selectedStudent!.programId,
            departmentId: user.departmentUnit,
            subjectCode: _selectedCourse!.subjectCode,
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Berjaya dikemaskini!' : 'Berjaya disimpan!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ralat: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit Laporan Disiplin' : 'Borang Laporan Disiplin',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isEdit) ..._readonlyContext() else ..._lecturerInputs(),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _issueType,
                              decoration:
                                  const InputDecoration(labelText: 'Jenis Isu'),
                              items: kIssueTypes
                                  .map((t) =>
                                      DropdownMenuItem(value: t, child: Text(t)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _issueType = v ?? _issueType),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tahap Keseriusan',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: kSeverityLevels.map((s) {
                                final selected = _severity == s;
                                final c = _severityColor(s);
                                return Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 4),
                                    child: InkWell(
                                      onTap: () =>
                                          setState(() => _severity = s),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? c
                                              : c.withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: c,
                                            width: selected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            s,
                                            style: TextStyle(
                                              color: selected ? Colors.white : c,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _notesCtrl,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                labelText: 'Catatan / Nota Kesalahan',
                                alignLabelWithHint: true,
                              ),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Wajib' : null,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _saving ? null : _submit,
                              icon: _saving
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(_isEdit ? Icons.save : Icons.send),
                              label: Text(_isEdit ? 'Simpan Perubahan' : 'Hantar Laporan'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  List<Widget> _lecturerInputs() {
    if (_courses.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Anda tiada kursus yang diperuntukkan. Sila hubungi pentadbir.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      ];
    }
    final filteredStudents = _studentsForSelectedCourse;
    return [
      DropdownButtonFormField<TimetableEntry>(
        initialValue: _selectedCourse,
        decoration: const InputDecoration(labelText: 'Kursus'),
        items: _courses
            .map((c) => DropdownMenuItem(
                value: c,
                child: Text(
                    '${c.subjectCode} — ${c.subjectName} (${c.kelas ?? c.departmentUnit})')))
            .toList(),
        onChanged: (v) => setState(() {
          _selectedCourse = v;
          // Tetapkan semula pilihan pelajar jika tidak lagi dalam kelas dipilih.
          if (_selectedStudent != null &&
              v != null &&
              (_selectedStudent!.programId != v.departmentUnit ||
                  (v.kelas != null && _selectedStudent!.kelas != v.kelas))) {
            _selectedStudent = null;
          }
        }),
        validator: (v) => v == null ? 'Wajib pilih kursus' : null,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<Student>(
        initialValue:
            filteredStudents.contains(_selectedStudent) ? _selectedStudent : null,
        decoration: const InputDecoration(labelText: 'Nama Pelajar'),
        items: filteredStudents
            .map((s) => DropdownMenuItem(
                value: s,
                child: Text('${s.fullName} (${s.studentId})')))
            .toList(),
        onChanged: (v) => setState(() => _selectedStudent = v),
        validator: (v) => v == null ? 'Wajib pilih pelajar' : null,
      ),
    ];
  }

  List<Widget> _readonlyContext() {
    final r = _editing!;
    return [
      _readonlyField('Pelajar', r.studentName ?? r.studentId),
      const SizedBox(height: 12),
      _readonlyField('Kursus', r.subjectCode ?? '-'),
      const SizedBox(height: 12),
      _readonlyField('Program', r.programId ?? '-'),
    ];
  }

  Widget _readonlyField(String label, String value) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
      ),
      child: Text(value, style: const TextStyle(color: AppTheme.navy)),
    );
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }
}
