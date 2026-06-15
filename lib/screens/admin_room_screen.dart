// lib/screens/admin_room_screen.dart
//
// Skrin Admin untuk urus bilik (tambah, edit nama, ubah status, arkib).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/room.dart';
import '../providers/user_provider.dart';
import '../services/room_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

class AdminRoomScreen extends StatefulWidget {
  const AdminRoomScreen({super.key});

  @override
  State<AdminRoomScreen> createState() => _AdminRoomScreenState();
}

class _AdminRoomScreenState extends State<AdminRoomScreen> {
  final _service = RoomService();
  late Future<List<Room>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchAllRooms();
  }

  void _refresh() => setState(() => _future = _service.fetchAllRooms());

  Future<void> _addDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah Bilik'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nama Bilik'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _service.insertRoom(name);
      _refresh();
    }
  }

  Future<void> _editName(Room room) async {
    final ctrl = TextEditingController(text: room.roomName);
    final user = context.read<UserProvider>().profile;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Nama Bilik'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _service.updateRoom(
        id: room.id,
        roomName: name,
        updatedBy: user?.id,
      );
      _refresh();
    }
  }

  Future<void> _changeStatus(Room room) async {
    final user = context.read<UserProvider>().profile;
    String status = room.status;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tukar Status Bilik'),
        content: StatefulBuilder(
          builder: (ctx, setSt) => DropdownButtonFormField<String>(
            initialValue: status,
            items: kRoomStatuses
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setSt(() => status = v ?? status),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, status),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null && result != room.status) {
      await _service.updateRoom(id: room.id, status: result, updatedBy: user?.id);
      _refresh();
    }
  }

  Future<void> _archive(Room room) async {
    final user = context.read<UserProvider>().profile;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Arkib Bilik?'),
        content: Text('Arkibkan ${room.roomName}? Status akan ditetapkan kepada "Archived".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Arkib'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.archiveRoom(room.id, updatedBy: user?.id);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Urus Bilik',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.teal,
        foregroundColor: AppTheme.navy,
        onPressed: _addDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Bilik'),
      ),
      body: FutureBuilder<List<Room>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rooms = snap.data ?? const [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Nama Bilik')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Tindakan')),
                  ],
                  rows: rooms.map((r) {
                    Color c;
                    switch (r.status) {
                      case 'Available':
                        c = AppTheme.hadir;
                        break;
                      case 'Maintenance':
                        c = AppTheme.mc;
                        break;
                      default:
                        c = AppTheme.textMuted;
                    }
                    return DataRow(cells: [
                      DataCell(Text('${r.id}')),
                      DataCell(Text(r.roomName)),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: c),
                        ),
                        child: Text(r.status,
                            style: TextStyle(
                                color: c, fontWeight: FontWeight.w600)),
                      )),
                      DataCell(Row(children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppTheme.navy),
                          tooltip: 'Edit Nama',
                          onPressed: () => _editName(r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.swap_horiz, color: AppTheme.navy),
                          tooltip: 'Tukar Status',
                          onPressed: () => _changeStatus(r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.archive,
                              color: AppTheme.tidakHadir),
                          tooltip: 'Arkib',
                          onPressed: () => _archive(r),
                        ),
                      ])),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
