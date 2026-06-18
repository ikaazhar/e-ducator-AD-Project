// lib/screens/dashboards/student_class_management_screen.dart
//
// Skrin admin/Ketua Jabatan untuk menetapkan kelas kepada pelajar yang
// dimuat naik melalui CSV. Hanya menguruskan lajur `kelas` pada jadual
// `students`; tidak melibatkan jadual waktu atau kehadiran.
import 'package:flutter/material.dart';

import '../../models/student.dart';
import '../../services/attendance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';

class StudentClassManagementScreen extends StatefulWidget {
  final bool initialUnassignedOnly;

  const StudentClassManagementScreen({
    super.key,
    this.initialUnassignedOnly = true,
  });

  @override
  State<StudentClassManagementScreen> createState() =>
      _StudentClassManagementScreenState();
}

class _StudentClassManagementScreenState
    extends State<StudentClassManagementScreen> {
  final _service = AttendanceService();

  List<Student> _students = [];
  bool _loading = true;
  String? _programFilter;
  late bool _unassignedOnly;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _unassignedOnly = widget.initialUnassignedOnly;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _service.fetchAllStudents();
    if (!mounted) return;
    setState(() {
      _students = rows;
      _loading = false;
      _selectedIds.clear();
    });
  }

  List<String> get _programOptions {
    final set = _students.map((s) => s.programId).toSet().toList()..sort();
    return set;
  }

  List<Student> get _visibleStudents {
    return _students.where((s) {
      if (_programFilter != null && s.programId != _programFilter) {
        return false;
      }
      final assigned = s.kelas != null && s.kelas!.trim().isNotEmpty;
      if (_unassignedOnly && assigned) return false;
      return true;
    }).toList();
  }

  Future<void> _showAssignDialog(List<String> ids) async {
    final existingKelas = _students
        .map((s) => s.kelas)
        .where((k) => k != null && k.trim().isNotEmpty)
        .map((k) => k!)
        .toSet()
        .toList()
      ..sort();

    String? selected = existingKelas.isNotEmpty ? existingKelas.first : null;
    bool isNew = existingKelas.isEmpty;
    final ctrl = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(ids.length > 1
              ? 'Tetapkan Kelas (${ids.length} pelajar)'
              : 'Tetapkan Kelas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (existingKelas.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: isNew ? null : selected,
                  decoration: const InputDecoration(labelText: 'Kelas sedia ada'),
                  items: [
                    ...existingKelas.map(
                      (k) => DropdownMenuItem(value: k, child: Text(k)),
                    ),
                    const DropdownMenuItem(
                        value: '__new__', child: Text('+ Kelas Baru')),
                  ],
                  onChanged: (v) => setSt(() {
                    if (v == '__new__') {
                      isNew = true;
                    } else {
                      isNew = false;
                      selected = v;
                    }
                  }),
                ),
              if (isNew) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                      labelText: 'Kod kelas baharu (cth: DGS4A)'),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final value = isNew ? ctrl.text.trim() : (selected ?? '');
                Navigator.pop(context, value);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty) return;

    final res = await _service.bulkUpdateKelas(ids, result);
    if (!mounted) return;
    final updated = res['updated'] as int;
    final errors = List<String>.from(res['errors'] as List);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errors.isEmpty
            ? '$updated pelajar dikemaskini ke kelas $result.'
            : '$updated berjaya dikemaskini, ${errors.length} gagal.'),
        backgroundColor: errors.isEmpty ? AppTheme.navy : AppTheme.tidakHadir,
      ),
    );
    _load();
  }

  Widget _kelasChip(String? kelas) {
    final assigned = kelas != null && kelas.trim().isNotEmpty;
    final color = assigned ? AppTheme.teal : Colors.orange;
    final label = assigned ? kelas! : 'Belum Ditetapkan';
    final icon = assigned ? Icons.check_circle_outline : Icons.hourglass_empty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  DataRow _buildRow(Student s) {
    return DataRow(
      selected: _selectedIds.contains(s.id),
      onSelectChanged: (sel) {
        setState(() {
          if (sel == true) {
            _selectedIds.add(s.id);
          } else {
            _selectedIds.remove(s.id);
          }
        });
      },
      cells: [
        DataCell(Text(s.fullName)),
        DataCell(Text(s.studentId)),
        DataCell(Text(s.programId)),
        DataCell(_kelasChip(s.kelas)),
        DataCell(IconButton(
          tooltip: 'Tetapkan Kelas',
          icon: const Icon(Icons.edit_outlined, color: AppTheme.navy),
          onPressed: () => _showAssignDialog([s.id]),
        )),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: _programFilter,
            decoration: const InputDecoration(labelText: 'Program'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Semua Program')),
              ..._programOptions.map(
                (p) => DropdownMenuItem(value: p, child: Text(p)),
              ),
            ],
            onChanged: (v) => setState(() => _programFilter = v),
          ),
        ),
        const SizedBox(width: 16),
        Row(
          children: [
            const Text('Belum Ditetapkan Sahaja',
                style: TextStyle(fontSize: 13, color: AppTheme.textDark)),
            Switch(
              value: _unassignedOnly,
              activeThumbColor: AppTheme.teal,
              onChanged: (v) => setState(() => _unassignedOnly = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBulkActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text('${_selectedIds.length} pelajar dipilih',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppTheme.navy)),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _selectedIds.clear()),
            child: const Text('Kosongkan'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showAssignDialog(_selectedIds.toList()),
            icon: const Icon(Icons.class_outlined, size: 18),
            label: const Text('Tetapkan Kelas'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleStudents;
    return AppScaffold(
      title: 'Urus Kelas Pelajar',
      actions: [
        IconButton(
          tooltip: 'Muat Semula',
          icon: const Icon(Icons.refresh),
          onPressed: _load,
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterRow(),
                  const SizedBox(height: 16),
                  if (_selectedIds.isNotEmpty) ...[
                    _buildBulkActionBar(),
                    const SizedBox(height: 16),
                  ],
                  visible.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text('Tiada pelajar ditemui.',
                                style: TextStyle(color: AppTheme.textMuted)),
                          ),
                        )
                      : Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.navy,
                                ),
                                columns: const [
                                  DataColumn(label: Text('Nama')),
                                  DataColumn(label: Text('No. Pelajar')),
                                  DataColumn(label: Text('Program')),
                                  DataColumn(label: Text('Kelas')),
                                  DataColumn(label: Text('Tindakan')),
                                ],
                                rows: visible.map(_buildRow).toList(),
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }
}