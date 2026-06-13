// lib/screens/timetable_upload_screen.dart
//
// Modul 4: Muat Naik Jadual Waktu.
// - Admin: CRUD penuh semua unit.
// - Ketua Program: CRUD untuk unit sendiri sahaja.
// - Ketua Jabatan / Pensyarah: Lihat sahaja.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  // Form controllers
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _sessionCtrl = TextEditingController();

  // Form state
  String _unit = kJabatanList.first;
  String _day = kHariList.first;
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  int? _roomId;
  String? _lecturerId;
  String? _kelas; // selected kelas from students table

  // Data
  List<Room> _rooms = const [];
  List<UserProfile> _lecturers = const [];
  List<String> _kelasList = const []; // distinct kelas from students
  List<TimetableEntry> _entries = const [];
  TimetableStats _stats = const TimetableStats(
    totalClasses: 0,
    roomsInUse: 0,
    lecturersScheduled: 0,
    classesToday: 0,
  );

  // UI state
  bool _loading = true;
  bool _saving = false;
  String _searchQuery = '';
  String? _filterDay;
  String? _filterKelas;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().profile;
    if (user?.role == 'Ketua Program' && user?.departmentUnit != null) {
      _unit = user!.departmentUnit!;
    }
    _bootstrap();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _sessionCtrl.dispose();
    super.dispose();
  }

  // ─── DATA LOADING ─────────────────────────────────────────

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadRooms(),
      _loadLecturers(),
      _loadKelas(),
      _loadEntries(),
    ]);
    await _loadStats();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRooms() async {
    _rooms = await _roomService.fetchAvailableRooms();
  }

  Future<void> _loadLecturers() async {
    _lecturers = await _service.fetchLecturersByUnit(_unit);
  }

  /// Load distinct kelas values from students table for selected unit
  Future<void> _loadKelas() async {
    _kelasList = await _service.fetchKelasByUnit(_unit);
    // Reset kelas selection if current value no longer valid
    if (_kelas != null && !_kelasList.contains(_kelas)) {
      _kelas = null;
    }
  }

  Future<void> _loadEntries() async {
    _entries = await _service.fetchAllTimetable(
      departmentUnit: _scopeUnit(),
    );
  }

  Future<void> _loadStats() async {
    _stats = await _service.fetchStats(departmentUnit: _scopeUnit());
  }

  String? _scopeUnit() {
    final user = context.read<UserProvider>().profile;
    if (user?.role == 'Ketua Program') return user?.departmentUnit;
    return null;
  }

  // ─── FORM HELPERS ──────────────────────────────────────────

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  bool _endAfterStart() {
    return _end.hour > _start.hour ||
        (_end.hour == _start.hour && _end.minute > _start.minute);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  // ─── SUBMIT ────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_kelas == null) {
      _showSnack('Sila pilih kelas / Please select a class.', isError: true);
      return;
    }
    if (_roomId == null) {
      _showSnack('Sila pilih bilik / Please select a room.', isError: true);
      return;
    }
    if (_lecturerId == null) {
      _showSnack('Sila pilih pensyarah / Please select a lecturer.', isError: true);
      return;
    }
    if (!_endAfterStart()) {
      _showSnack(
        'Waktu tamat mesti selepas waktu mula / End time must be after start time.',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final startStr = _formatTime(_start);
      final endStr = _formatTime(_end);

      final free = await _service.isRoomSlotFree(
        roomId: _roomId!,
        day: _day,
        startTime: startStr,
        endTime: endStr,
      );
      if (!free) {
        if (!mounted) return;
        _showSnack(
          'Bilik telah ditempah untuk slot ini / Room already occupied for this slot!',
          isError: true,
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
          startTime: startStr,
          endTime: endStr,
          roomId: _roomId,
          session: _sessionCtrl.text.trim().isEmpty ? null : _sessionCtrl.text.trim(),
          kelas: _kelas,
        ),
        createdBy: user.id,
      );

      if (!mounted) return;
      _showSnack('Jadual berjaya dimuat naik! / Schedule saved successfully!');
      _codeCtrl.clear();
      _nameCtrl.clear();
      setState(() {
        _lecturerId = null;
        _roomId = null;
        _kelas = null;
      });
      await _bootstrap();
    } catch (e) {
      if (mounted) _showSnack('Ralat: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── DELETE ────────────────────────────────────────────────

  Future<void> _confirmDelete(TimetableEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Padam Entri?'),
        content: Text('Padam ${e.subjectCode} – ${e.subjectName}\n${e.day} ${e.timeSlot}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.tidakHadir),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Padam'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.deleteTimetable(e.id);
    _showSnack('Entri telah dipadam.');
    await _bootstrap();
  }

  // ─── FILTER ────────────────────────────────────────────────

  List<TimetableEntry> get _filteredEntries {
    return _entries.where((e) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          e.subjectCode.toLowerCase().contains(q) ||
          e.subjectName.toLowerCase().contains(q) ||
          (e.lecturerName ?? '').toLowerCase().contains(q) ||
          (e.roomName ?? '').toLowerCase().contains(q) ||
          (e.kelas ?? '').toLowerCase().contains(q);
      final matchDay = _filterDay == null || e.day == _filterDay;
      final matchKelas = _filterKelas == null || e.kelas == _filterKelas;
      return matchSearch && matchDay && matchKelas;
    }).toList();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.tidakHadir : AppTheme.teal,
    ));
  }

  // ─── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().profile;
    final canWrite = user?.role == 'Admin' || user?.role == 'Ketua Program';

    return AppScaffold(
      title: 'Muat Naik Jadual Waktu / Upload Timetable',
      actions: [
        IconButton(
          tooltip: 'Muat semula',
          icon: const Icon(Icons.refresh),
          onPressed: _bootstrap,
        ),
      ],
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
                      _buildStatsBar(),
                      const SizedBox(height: 20),
                      if (canWrite) ...[
                        _buildForm(),
                        const SizedBox(height: 24),
                      ],
                      _buildListHeader(),
                      const SizedBox(height: 12),
                      _buildList(canWrite),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ─── STATS BAR ─────────────────────────────────────────────

  Widget _buildStatsBar() {
    return Row(
      children: [
        _statCard('Jumlah Kelas', _stats.totalClasses.toString(), Icons.class_, AppTheme.navy),
        const SizedBox(width: 12),
        _statCard('Bilik Digunakan', _stats.roomsInUse.toString(), Icons.meeting_room, AppTheme.teal),
        const SizedBox(width: 12),
        _statCard('Pensyarah Dijadualkan', _stats.lecturersScheduled.toString(), Icons.person, AppTheme.tealDark),
        const SizedBox(width: 12),
        _statCard('Kelas Hari Ini', _stats.classesToday.toString(), Icons.today, AppTheme.mc),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                  Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── FORM ──────────────────────────────────────────────────

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
                'Tambah Entri Jadual / Add Timetable Entry',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.navy),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // Subject Code
                  _wrapField(
                    width: 200,
                    child: TextFormField(
                      controller: _codeCtrl,
                      decoration: const InputDecoration(labelText: 'Kod Subjek / Subject Code'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                    ),
                  ),
                  // Subject Name
                  _wrapField(
                    width: 280,
                    child: TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nama Subjek / Subject Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                    ),
                  ),
                  // Unit / Jabatan
                  _wrapField(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(labelText: 'Jabatan / Unit'),
                      items: kJabatanList
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() {
                          _unit = v;
                          _lecturerId = null;
                          _kelas = null;
                        });
                        await Future.wait([_loadLecturers(), _loadKelas()]);
                        setState(() {});
                      },
                    ),
                  ),
                  // Kelas — fetched from students table
                  _wrapField(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      value: _kelas,
                      decoration: const InputDecoration(labelText: 'Kelas / Class'),
                      hint: const Text('Pilih kelas'),
                      items: _kelasList
                          .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                          .toList(),
                      onChanged: (v) => setState(() => _kelas = v),
                    ),
                  ),
                  // Lecturer — fetched from profiles
                  _wrapField(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      value: _lecturerId,
                      decoration: const InputDecoration(labelText: 'Pensyarah / Lecturer'),
                      hint: const Text('Pilih pensyarah'),
                      items: _lecturers
                          .map((l) => DropdownMenuItem(value: l.id, child: Text(l.fullName)))
                          .toList(),
                      onChanged: (v) => setState(() => _lecturerId = v),
                    ),
                  ),
                  // Day
                  _wrapField(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      value: _day,
                      decoration: const InputDecoration(labelText: 'Hari / Day'),
                      items: kHariList
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setState(() => _day = v ?? _day),
                    ),
                  ),
                  // Start time
                  _wrapField(
                    width: 160,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(isStart: true),
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text('Mula: ${_start.format(context)}'),
                    ),
                  ),
                  // End time
                  _wrapField(
                    width: 160,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(isStart: false),
                      icon: const Icon(Icons.access_time_filled, size: 18),
                      label: Text('Tamat: ${_end.format(context)}'),
                    ),
                  ),
                  // Room
                  _wrapField(
                    width: 220,
                    child: DropdownButtonFormField<int>(
                      value: _roomId,
                      decoration: const InputDecoration(labelText: 'Bilik / Room'),
                      hint: const Text('Pilih bilik'),
                      items: _rooms
                          .map((r) => DropdownMenuItem(value: r.id, child: Text(r.roomName)))
                          .toList(),
                      onChanged: (v) => setState(() => _roomId = v),
                    ),
                  ),
                  // Session
                  _wrapField(
                    width: 180,
                    child: TextFormField(
                      controller: _sessionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sesi / Session',
                        hintText: 'JAN-JUN 2026',
                      ),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Menyimpan...' : 'Simpan Entri'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrapField({required double width, required Widget child}) {
    return SizedBox(width: width, child: child);
  }

  // ─── LIST HEADER ───────────────────────────────────────────

  Widget _buildListHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Senarai Jadual / Timetable List',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.navy),
        ),
        const SizedBox(height: 10),
        // Search bar
        TextField(
          decoration: const InputDecoration(
            hintText: 'Cari subjek, pensyarah, bilik, kelas...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        const SizedBox(height: 8),
        // Day filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text('Hari: ', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
              FilterChip(
                label: const Text('Semua'),
                selected: _filterDay == null,
                onSelected: (_) => setState(() => _filterDay = null),
                selectedColor: AppTheme.teal.withOpacity(0.2),
              ),
              const SizedBox(width: 6),
              ...kHariList.map((d) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(d),
                      selected: _filterDay == d,
                      onSelected: (_) =>
                          setState(() => _filterDay = _filterDay == d ? null : d),
                      selectedColor: AppTheme.teal.withOpacity(0.2),
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Kelas filter chips
        if (_kelasList.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Kelas: ', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                FilterChip(
                  label: const Text('Semua'),
                  selected: _filterKelas == null,
                  onSelected: (_) => setState(() => _filterKelas = null),
                  selectedColor: AppTheme.teal.withOpacity(0.2),
                ),
                const SizedBox(width: 6),
                ..._kelasList.map((k) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(k),
                        selected: _filterKelas == k,
                        onSelected: (_) =>
                            setState(() => _filterKelas = _filterKelas == k ? null : k),
                        selectedColor: AppTheme.teal.withOpacity(0.2),
                      ),
                    )),
              ],
            ),
          ),
      ],
    );
  }

  // ─── LIST TABLE ────────────────────────────────────────────

  Widget _buildList(bool canWrite) {
    final filtered = _filteredEntries;

    if (filtered.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Tiada entri jadual. / No timetable entries found.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy),
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          columns: const [
            DataColumn(label: Text('Kod / Code')),
            DataColumn(label: Text('Nama Subjek / Subject')),
            DataColumn(label: Text('Kelas')),
            DataColumn(label: Text('Unit')),
            DataColumn(label: Text('Pensyarah / Lecturer')),
            DataColumn(label: Text('Hari / Day')),
            DataColumn(label: Text('Masa / Time')),
            DataColumn(label: Text('Bilik / Room')),
            DataColumn(label: Text('Sesi / Session')),
            DataColumn(label: Text('')),
          ],
          rows: filtered.map((e) {
            return DataRow(cells: [
              DataCell(Text(e.subjectCode,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(e.subjectName)),
              DataCell(_kelasBadge(e.kelas ?? '-')),
              DataCell(_unitBadge(e.departmentUnit)),
              DataCell(Text(e.lecturerName ?? '-')),
              DataCell(Text(e.day)),
              DataCell(Text(e.timeSlot)),
              DataCell(Text(e.roomName ?? '-')),
              DataCell(Text(e.session ?? '-')),
              DataCell(
                canWrite
                    ? IconButton(
                        tooltip: 'Padam / Delete',
                        icon: const Icon(Icons.delete_outline, color: AppTheme.tidakHadir),
                        onPressed: () => _confirmDelete(e),
                      )
                    : const SizedBox.shrink(),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _unitBadge(String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.teal.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(unit,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.tealDark)),
    );
  }

  Widget _kelasBadge(String kelas) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.navy.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(kelas,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.navy)),
    );
  }
}
