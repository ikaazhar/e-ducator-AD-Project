// lib/screens/attendance_screen.dart
//
// Modul 1: Perekodan Kehadiran.
import 'package:flutter/material.dart';

import '../models/attendance_record.dart';
import '../models/student.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/attendance_row.dart';
import '../widgets/bulk_action_dropdown.dart';

class AttendanceScreen extends StatefulWidget {
  final String timetableId;
  final String subjectName;
  final String subjectCode;
  final String departmentUnit;
  final String attendanceDate;
  final String userId;
  final bool initialReadOnly;

  const AttendanceScreen({
    super.key,
    required this.timetableId,
    required this.subjectName,
    required this.subjectCode,
    required this.departmentUnit,
    required this.attendanceDate,
    required this.userId,
    this.initialReadOnly = false,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _service = AttendanceService();
  List<Student> _students = [];
  Map<String, String?> _status = {};
  bool _loading = true;
  bool _isReadOnly = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _isReadOnly = widget.initialReadOnly;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final students = await _service.fetchStudentsByUnit(widget.departmentUnit);
      final existing = await _service.fetchExistingAttendance(
        timetableId: widget.timetableId,
        attendanceDate: widget.attendanceDate,
      );

      _students = students;
      _status = {for (final s in students) s.id: existing[s.id]};

      if (existing.isNotEmpty) {
        _isReadOnly = true;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ralat berlaku. Sila cuba semula.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _hadirCount => _status.values.where((s) => s == 'Hadir').length;
  int get _totalStudents => _students.length;
  bool get _allFilled => _status.values.every((v) => v != null);

  void _applyBulk(String status) {
    setState(() {
      for (final s in _students) {
        _status[s.id] = status;
      }
    });
  }

  Future<void> _submit() async {
    if (!_allFilled || _submitting) return;
    setState(() => _submitting = true);
    try {
      final records = _students
          .map((s) => AttendanceRecord(
                timetableId: widget.timetableId,
                studentId: s.id,
                attendanceDate: widget.attendanceDate,
                attendanceStatus: _status[s.id]!,
                markedBy: widget.userId,
              ))
          .toList();
      await _service.submitAttendance(records);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kehadiran berjaya direkodkan!')),
      );
      setState(() => _isReadOnly = true);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ralat berlaku. Sila cuba semula.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subjectName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali ke Jadual',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppTheme.slate,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _header(),
                if (_isReadOnly) _readOnlyBanner(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: BulkActionDropdown(
                    onSelected: _applyBulk,
                    enabled: !_isReadOnly,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _students.length,
                    itemBuilder: (_, i) {
                      final s = _students[i];
                      return AttendanceRow(
                        rowNumber: i + 1,
                        studentName: s.fullName,
                        studentId: s.studentId,
                        selected: _status[s.id],
                        readOnly: _isReadOnly,
                        onStatusChanged: (v) =>
                            setState(() => _status[s.id] = v),
                      );
                    },
                  ),
                ),
                _submitBar(),
              ],
            ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.subjectName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.subjectCode} • ${widget.attendanceDate}',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.teal.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Bilangan Pelajar Hadir: $_hadirCount / $_totalStudents',
              style: const TextStyle(
                color: AppTheme.tealDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyBanner() {
    return Container(
      width: double.infinity,
      color: AppTheme.teal.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Icon(Icons.lock, color: AppTheme.tealDark, size: 18),
          SizedBox(width: 8),
          Text(
            'Telah Dihantar — Rekod Kehadiran Dikunci',
            style: TextStyle(color: AppTheme.tealDark, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _submitBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _isReadOnly
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.lock),
                    label: const Text('Rekod Telah Dikunci'),
                  )
                : ElevatedButton.icon(
                    onPressed:
                        (_allFilled && !_submitting) ? _submit : null,
                    icon: _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Hantar Kehadiran'),
                  ),
          ),
        ],
      ),
    );
  }
}
