// lib/screens/admin_booking_monitor_screen.dart
//
// Skrin Pentadbir: Memantau dan menapis semua tempahan sistem.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/booking.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

class AdminBookingMonitorScreen extends StatefulWidget {
  const AdminBookingMonitorScreen({super.key});

  @override
  State<AdminBookingMonitorScreen> createState() => _AdminBookingMonitorScreenState();
}

class _AdminBookingMonitorScreenState extends State<AdminBookingMonitorScreen> {
  final _service = RoomService();
  
  List<Booking> _allBookings = [];
  List<Booking> _filteredBookings = [];
  List<Room> _rooms = [];
  
  bool _loading = true;
  DateTime? _filterDate;
  int? _selectedRoomId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    _allBookings = await _service.fetchAllBookingsGlobal();
    _rooms = await _service.fetchAllRooms();
    _filteredBookings = _allBookings;
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilters() {
    setState(() {
      _filteredBookings = _allBookings.where((b) {
        bool matchesDate = true;
        if (_filterDate != null) {
          final target = DateFormat('yyyy-MM-dd').format(_filterDate!);
          matchesDate = (b.bookingDate == target);
        }

        bool matchesRoom = true;
        if (_selectedRoomId != null) {
          matchesRoom = (b.roomId == _selectedRoomId);
        }

        return matchesDate && matchesRoom;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _filterDate = null;
      _selectedRoomId = null;
      _filteredBookings = _allBookings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Pemantauan Tempahan Bilik',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      _buildFilterPanel(),
                      const SizedBox(height: 16),
                      _buildResultsList(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFilterPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<int>(
              hint: const Text('Tapis mengikut Bilik'),
              value: _selectedRoomId,
              items: _rooms.map((r) {
                return DropdownMenuItem<int>(
                  value: r.id,
                  child: Text(r.roomName),
                );
              }).toList(),
              onChanged: (val) {
                _selectedRoomId = val;
                _applyFilters();
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_filterDate == null
                  ? 'Tapis Tarikh'
                  : DateFormat('d MMM yyyy', 'ms').format(_filterDate!)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 90)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  _filterDate = picked;
                  _applyFilters();
                }
              },
            ),
            if (_filterDate != null || _selectedRoomId != null)
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Set Semula', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_filteredBookings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Tiada rekod permohonan tempahan ditemui.',
              style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _filteredBookings.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final b = _filteredBookings[index];
          
          // Cross reference room names from the room list array safely
          final roomObj = _rooms.firstWhere((r) => r.id == b.roomId, 
              orElse: () => Room(id: b.roomId, roomName: 'Bilik ID: ${b.roomId}', status: ''));

          return ListTile(
            leading: const Icon(Icons.bookmark_outline, color: AppTheme.navy),
            title: Text(roomObj.roomName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Tarikh: ${b.bookingDate} | Masa: ${b.startTime.substring(0,5)} - ${b.endTime.substring(0,5)}'),
            trailing: Text(b.purpose ?? '-', style: const TextStyle(color: AppTheme.textMuted)),
          );
        },
      ),
    );
  }
}