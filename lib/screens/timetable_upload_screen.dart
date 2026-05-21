// lib/screens/timetable_upload_screen.dart
//
// Modul 4: Muat Naik Jadual Waktu.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/room.dart';
import '../models/timetable_entry.dart';
import '../models/user_profile.dart';
import '../providers/user_provider.dart';
import '../services/room_service.dart';
import '../services/timetable_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

class TimetableUploadScreen extends StatefulWidget {
  const TimetableUploadScreen({super.key});

  @override
  State<TimetableUploadScreen> createState() => _TimetableUploadScreenState();
}

class _TimetableUploadScreenState extends State<TimetableUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = TimetableService();
  final _roomService = RoomService();

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _sessionCtrl = TextEditingController();
  String _unit = kJabatanList.first;
  String _day = kHariList.first;
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  int? _roomId;
  String? _lecturerId;

  List<Room> _rooms = const [];
  List<UserProfile> _lecturers = const [];
  List<TimetableEntry> _entries = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().profile;
    if (user?.role == 'Ketua Program' && user?.departmentUnit != null) {
      _unit = user!.departmentUnit!;
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    _rooms = await _roomService.fetchAvailableRooms();
    _lecturers = await _fetchLecturers();
    _entries = await _service.fetchAllTimetable(
      departmentUnit: _scopeUnit(),
    );
    if (mounted) setState(() => _loading = false);
  }

  String? _scopeUnit() {
    final user = context.read<UserProvider>().profile;
    if (user?.role == 'Ketua Program') return user?.departmentUnit;
    return null;
  }

  Future<List<UserProfile>> _fetchLecturers() async {
    if (SupabaseConfig.isPlaceholder) {
      return [
        UserProfile(
          id: 'mock-user-id',
          fullName: 'Pengguna Demo',
          email: 'lecturer@ikmjb.edu.my',
          role: 'Lecturer',
          departmentUnit: _unit,
        ),
      ];
    }
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('role', 'Lecturer')
          .eq('department_unit', _unit);
      return (data as List)
          .map((r) => UserProfile.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: _start);
    if (t != null) setState(() => _start = t);
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(context: context, initialTime: _end);
    if (t != null) setState(() => _end = t);
  }

  bool _isAfter(TimeOfDay a, TimeOfDay b) {
    return a.hour > b.hour || (a.hour == b.hour && a.minute > b.minute);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila pilih bilik.')),
      );
      return;
    }
    if (!_isAfter(_end, _start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waktu tamat mesti selepas waktu mula.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final free = await _service.isRoomSlotFree(
        roomId: _roomId!,
        day: _day,
        startTime: _formatTime(_start),
        endTime: _formatTime(_end),
      );
      if (!free) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bilik telah ditempah untuk slot ini / Room already occupied!')),
        );
        return;
      }
      if (!mounted) return;
      final user = context.read<UserProvider>().profile!;
      await _service.insertTimetable(
        TimetableEntry(
          id: '',
          subjectCode: _codeCtrl.text.trim(),
          subjectName: _nameCtrl.text.trim(),
          departmentUnit: _unit,
          lecturerId: _lecturerId,
          day: _day,
          startTime: _formatTime(_start),
          endTime: _formatTime(_end),
          roomId: _roomId,
          session: _sessionCtrl.text.trim(),
        ),
        createdBy: user.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jadual berjaya dimuat naik!')),
      );
      _codeCtrl.clear();
      _nameCtrl.clear();
      await _bootstrap();
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

  Future<void> _delete(TimetableEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Padam Entri?'),
        content: Text('Padam ${e.subjectName} (${e.day} ${e.timeSlot})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Padam'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.deleteTimetable(e.id);
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().profile;
    final canWrite =
        user?.role == 'Admin' || user?.role == 'Ketua Program';

    return AppScaffold(
      title: 'Muat Naik Jadual Waktu',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (canWrite) _buildForm(),
                      const SizedBox(height: 24),
                      const Text(
                        'Senarai Jadual',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildList(canWrite),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tambah Entri Jadual',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextFormField(
                      controller: _codeCtrl,
                      decoration: const InputDecoration(labelText: 'Kod Subjek'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Wajib' : null,
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nama Subjek'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Wajib' : null,
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'Jabatan/Unit'),
                      items: kJabatanList
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) async {
                        setState(() => _unit = v ?? _unit);
                        _lecturers = await _fetchLecturers();
                        setState(() {});
                      },
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      initialValue: _lecturerId,
                      decoration: const InputDecoration(labelText: 'Pensyarah'),
                      items: _lecturers
                          .map((l) => DropdownMenuItem(
                                value: l.id,
                                child: Text(l.fullName),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _lecturerId = v),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      initialValue: _day,
                      decoration: const InputDecoration(labelText: 'Hari'),
                      items: kHariList
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setState(() => _day = v ?? _day),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: OutlinedButton(
                      onPressed: _pickStart,
                      child: Text('Mula: ${_start.format(context)}'),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: OutlinedButton(
                      onPressed: _pickEnd,
                      child: Text('Tamat: ${_end.format(context)}'),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<int>(
                      initialValue: _roomId,
                      decoration: const InputDecoration(labelText: 'Bilik'),
                      items: _rooms
                          .map((r) => DropdownMenuItem(
                                value: r.id,
                                child: Text(r.roomName),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _roomId = v),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextFormField(
                      controller: _sessionCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Sesi (cth: 2025/01)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Simpan Entri'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(bool canWrite) {
    if (_entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Tiada entri jadual.')),
        ),
      );
    }
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.navy,
          ),
          columns: const [
            DataColumn(label: Text('Subjek')),
            DataColumn(label: Text('Kod')),
            DataColumn(label: Text('Unit')),
            DataColumn(label: Text('Hari')),
            DataColumn(label: Text('Masa')),
            DataColumn(label: Text('Bilik')),
            DataColumn(label: Text('Sesi')),
            DataColumn(label: Text('')),
          ],
          rows: _entries.map((e) {
            return DataRow(cells: [
              DataCell(Text(e.subjectName)),
              DataCell(Text(e.subjectCode)),
              DataCell(Text(e.departmentUnit)),
              DataCell(Text(e.day)),
              DataCell(Text(e.timeSlot)),
              DataCell(Text(e.roomName ?? '-')),
              DataCell(Text(e.session ?? '-')),
              DataCell(canWrite
                  ? IconButton(
                      icon: const Icon(Icons.delete, color: AppTheme.tidakHadir),
                      onPressed: () => _delete(e),
                    )
                  : const SizedBox.shrink()),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
