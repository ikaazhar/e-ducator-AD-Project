// lib/screens/discipline_form_screen.dart
//
// Modul 2 — Halaman 2: Borang Laporan Disiplin.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/discipline_report.dart';
import '../models/student.dart';
import '../providers/user_provider.dart';
import '../services/discipline_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

class DisciplineFormScreen extends StatefulWidget {
  const DisciplineFormScreen({super.key});

  @override
  State<DisciplineFormScreen> createState() => _DisciplineFormScreenState();
}

class _DisciplineFormScreenState extends State<DisciplineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = DisciplineService();
  final _notesCtrl = TextEditingController();

  List<Student> _students = const [];
  Student? _selectedStudent;
  String _issueType = kIssueTypes.first;
  String _severity = 'Rendah';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().profile!;
    _students = await _service.fetchStudents(user.departmentUnit ?? 'DGS');
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila pilih pelajar.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final user = context.read<UserProvider>().profile!;
      await _service.submitReport(
        DisciplineReport(
          studentId: _selectedStudent!.id,
          issueType: _issueType,
          severity: _severity,
          notes: _notesCtrl.text.trim(),
          reportedBy: user.id,
          programId: _selectedStudent!.programId,
          departmentId: user.departmentUnit,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berjaya disimpan!')),
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
      title: 'Borang Laporan Disiplin',
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
                            DropdownButtonFormField<Student>(
                              initialValue: _selectedStudent,
                              decoration:
                                  const InputDecoration(labelText: 'Nama Pelajar'),
                              items: _students
                                  .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(
                                          '${s.fullName} (${s.studentId})')))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedStudent = v),
                              validator: (v) =>
                                  v == null ? 'Wajib pilih pelajar' : null,
                            ),
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
                                  : const Icon(Icons.send),
                              label: const Text('Hantar Laporan'),
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
}
