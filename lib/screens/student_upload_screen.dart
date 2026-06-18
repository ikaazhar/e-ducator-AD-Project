// lib/screens/student_upload_screen.dart
//
// Modul Admin: Muat naik data pelajar dalam pukal melalui CSV.
// Hanya boleh diakses oleh Admin dan Ketua Jabatan.
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

// Expected CSV columns (order doesn't matter, header required):
// full_name, student_id, program_id, kelas

class StudentUploadScreen extends StatefulWidget {
  const StudentUploadScreen({super.key});

  @override
  State<StudentUploadScreen> createState() => _StudentUploadScreenState();
}

class _StudentUploadScreenState extends State<StudentUploadScreen> {
  final _service = AttendanceService();

  List<Map<String, String>> _preview = [];
  List<String> _validationErrors = [];
  bool _loading = false;
  bool _submitted = false;
  int _insertedCount = 0;
  List<String> _insertErrors = [];
  String? _fileName;

  // ── CSV parsing ────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    setState(() {
      _preview = [];
      _validationErrors = [];
      _submitted = false;
      _insertErrors = [];
      _fileName = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    _fileName = file.name;
    final bytes = file.bytes;
    if (bytes == null) return;

    final content = utf8.decode(bytes);
    _parseCSV(content);
  }

  void _parseCSV(String content) {
    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length < 2) {
      setState(() => _validationErrors = ['Fail CSV kosong atau tiada data.']);
      return;
    }

    // Parse header
    final headers =
        lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
    final required = ['full_name', 'student_id', 'program_id'];
    final missing = required.where((r) => !headers.contains(r)).toList();
    if (missing.isNotEmpty) {
      setState(() => _validationErrors = [
            'Lajur berikut tiada dalam CSV: ${missing.join(', ')}',
            'Pastikan baris pertama mengandungi: ${required.join(', ')}',
          ]);
      return;
    }

    final rows = <Map<String, String>>[];
    final errors = <String>[];

    for (int i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',').map((c) => c.trim()).toList();
      if (cols.length < headers.length) {
        errors.add('Baris ${i + 1}: bilangan lajur tidak mencukupi.');
        continue;
      }
      final row = <String, String>{};
      for (int j = 0; j < headers.length; j++) {
        row[headers[j]] = cols[j];
      }
      // Validate required fields
      if ((row['full_name'] ?? '').isEmpty) {
        errors.add('Baris ${i + 1}: full_name kosong.');
        continue;
      }
      if ((row['student_id'] ?? '').isEmpty) {
        errors.add('Baris ${i + 1}: student_id kosong.');
        continue;
      }
      if ((row['program_id'] ?? '').isEmpty) {
        errors.add('Baris ${i + 1}: program_id kosong.');
        continue;
      }
      rows.add(row);
    }

    setState(() {
      _preview = rows;
      _validationErrors = errors;
      _fileName = _fileName;
    });
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_preview.isEmpty) return;
    setState(() => _loading = true);
    try {
      final payload = _preview
          .map((r) => {
                'full_name':  r['full_name']!,
                'student_id': r['student_id']!,
                'program_id': r['program_id']!,
              })
          .toList();

      final result = await _service.bulkInsertStudents(payload);
      setState(() {
        _insertedCount = result['inserted'] as int;
        _insertErrors  = List<String>.from(result['errors'] as List);
        _submitted     = true;
      });
    } catch (e) {
      _showSnack('Ralat: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.tidakHadir : AppTheme.navy,
    ));
  }

  void _reset() => setState(() {
        _preview = [];
        _validationErrors = [];
        _submitted = false;
        _insertErrors = [];
        _fileName = null;
        _insertedCount = 0;
      });

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().profile;
    final canAccess =
        user?.role == 'Admin' || user?.role == 'Ketua Jabatan';

    if (!canAccess) {
      return AppScaffold(
        title: 'Muat Naik Pelajar',
        body: const Center(
          child: Text('Akses ditolak. Hanya Admin dan Ketua Jabatan.',
              style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }

    return AppScaffold(
      title: 'Muat Naik Data Pelajar',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInstructions(),
            const SizedBox(height: 16),
            _buildUploadCard(),
            if (_validationErrors.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildErrorList(_validationErrors, 'Ralat Format CSV'),
            ],
            if (_submitted) ...[
              const SizedBox(height: 12),
              _buildResultCard(),
            ],
            if (_preview.isNotEmpty && !_submitted) ...[
              const SizedBox(height: 16),
              _buildPreviewTable(),
              const SizedBox(height: 16),
              _buildSubmitButton(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Instructions ───────────────────────────────────────────────────────────

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info_outline, color: AppTheme.teal, size: 16),
            SizedBox(width: 8),
            Text('Format CSV Diperlukan',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.teal,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Baris pertama mesti mengandungi pengepala berikut (susunan bebas):',
            style: TextStyle(fontSize: 12, color: AppTheme.textDark),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.navy.withValues (alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'full_name, student_id, program_id',
              style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Contoh baris data:\nAhmad Bin Ali, DGS24001, DGS',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Upload card ────────────────────────────────────────────────────────────

  Widget _buildUploadCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.upload_file_outlined,
                size: 48, color: AppTheme.teal.withValues(alpha: 0.7)),
            const SizedBox(height: 10),
            Text(
              _fileName ?? 'Tiada fail dipilih',
              style: TextStyle(
                fontSize: 13,
                color:
                    _fileName != null ? AppTheme.textDark : AppTheme.textMuted,
                fontWeight: _fileName != null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
            if (_preview.isNotEmpty && !_submitted) ...[
              const SizedBox(height: 4),
              Text(
                '${_preview.length} rekod ditemui',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.teal),
              ),
            ],
            const SizedBox(height: 14),
           ElevatedButton.icon(
            onPressed: _submitted ? _reset : _pickFile,
              icon: Icon(_submitted ? Icons.refresh : Icons.folder_open),
              label: Text(_submitted ? 'Muat Naik Baru' : 'Pilih Fail CSV'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preview table ──────────────────────────────────────────────────────────

  Widget _buildPreviewTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.table_rows_outlined,
              size: 16, color: AppTheme.navy),
          const SizedBox(width: 6),
          Text(
            'Pratonton — ${_preview.length} rekod',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.navy),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.slateBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.navy),
                headingTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
                dataRowMinHeight: 40,
                dataRowMaxHeight: 40,
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('Bil')),
                  DataColumn(label: Text('Nama Penuh')),
                  DataColumn(label: Text('No. Pelajar')),
                  DataColumn(label: Text('Program')),
                ],
                rows: _preview.asMap().entries.map((entry) {
                  final i = entry.key;
                  final r = entry.value;
                  return DataRow(cells: [
                    DataCell(Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted))),
                    DataCell(Text(r['full_name'] ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textDark))),
                    DataCell(Text(r['student_id'] ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textDark))),
                    DataCell(Text(r['program_id'] ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textDark))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Error list ─────────────────────────────────────────────────────────────

  Widget _buildErrorList(List<String> errors, String title) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.tidakHadir.withValues (alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.tidakHadir.withValues (alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.tidakHadir, size: 16),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.tidakHadir,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          ...errors.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            color: AppTheme.tidakHadir, fontSize: 12)),
                    Expanded(
                        child: Text(e,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textDark))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Result card ────────────────────────────────────────────────────────────

  Widget _buildResultCard() {
    final hasErrors = _insertErrors.isNotEmpty;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.hadir.withValues (alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.hadir.withOpacity(0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: AppTheme.hadir, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$_insertedCount rekod berjaya dimuat naik.',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.hadir,
                    fontSize: 14),
              ),
            ),
          ]),
        ),
        if (_insertedCount > 0) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/student-classes'),
              icon: const Icon(Icons.class_outlined),
              label: const Text('Tetapkan Kelas Sekarang'),
            ),
          ),
        ],
        if (hasErrors) ...[
          const SizedBox(height: 10),
          _buildErrorList(_insertErrors, 'Ralat Semasa Insert'),
        ],
      ],
    );
  }

  // ── Submit button ──────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _submit,
        icon: _loading
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.cloud_upload_outlined),
        label: Text(_loading
            ? 'Memuat naik...'
            : 'Simpan ${_preview.length} Rekod ke Sistem'),
      ),
    );
  }
}