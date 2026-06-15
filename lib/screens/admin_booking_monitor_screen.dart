// lib/screens/admin_booking_monitor_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // NEW

import '../models/booking.dart';
import '../models/room.dart';
import '../providers/user_provider.dart'; // NEW
import '../services/room_service.dart';
import '../services/notification_service.dart'; // NEW
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

class AdminBookingMonitorScreen extends StatefulWidget {
  const AdminBookingMonitorScreen({super.key});

  @override
  State<AdminBookingMonitorScreen> createState() => _AdminBookingMonitorScreenState();
}

class _AdminBookingMonitorScreenState extends State<AdminBookingMonitorScreen> {
  final _service = RoomService();
  final _notifService = NotificationService(); // NEW

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
    _applyFilters(); // CHANGED: re-apply current filters instead of overwrite
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

      // NEW: sort so active/upcoming bookings show first, past/cancelled last
      _filteredBookings.sort((a, b) {
        if (a.isCancelled != b.isCancelled) {
          return a.isCancelled ? 1 : -1;
        }
        if (a.isPast != b.isPast) {
          return a.isPast ? 1 : -1;
        }
        return b.bookingDate.compareTo(a.bookingDate);
      });
    });
  }

  void _clearFilters() {
    setState(() {
      _filterDate = null;
      _selectedRoomId = null;
    });
    _applyFilters();
  }

  // NEW: cancel booking flow
  Future<void> _cancelBooking(Booking booking, Room room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Tempahan'),
        content: Text(
          'Adakah anda pasti ingin membatalkan tempahan ${room.roomName} '
          'pada ${booking.bookingDate}?\n\nPemohon akan dimaklumkan.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Tidak')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirmed != true || booking.id == null) return;

    final adminId = context.read<UserProvider>().profile?.id ?? '';

    try {
      await _service.cancelBooking(
        bookingId: booking.id!,
        cancelledBy: adminId,
      );

      await _notifService.notifyBookingCancelled(
        recipientId: booking.userId,
        roomName: room.roomName,
        bookingDate: booking.bookingDate,
        bookingId: booking.id!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tempahan dibatalkan. Pemohon telah dimaklumkan.'),
          backgroundColor: Colors.orange,
        ),
      );
      await _bootstrap();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ralat: $e'), backgroundColor: Colors.red),
      );
    }
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

          final roomObj = _rooms.firstWhere((r) => r.id == b.roomId,
              orElse: () => Room(id: b.roomId, roomName: 'Bilik ID: ${b.roomId}', status: ''));

          // NEW: visual states
          final isPast = b.isPast;
          final isCancelled = b.isCancelled;
          final dimmed = isPast || isCancelled;

          final titleColor = dimmed ? Colors.grey.shade500 : AppTheme.navy;
          final subtitleColor = dimmed ? Colors.grey.shade400 : AppTheme.textMuted;

          return ListTile(
            leading: Icon(
              isCancelled
                  ? Icons.cancel_outlined
                  : Icons.bookmark_outline,
              color: isCancelled
                  ? Colors.red.shade300
                  : (dimmed ? Colors.grey.shade400 : AppTheme.navy),
            ),
            title: Row(
              children: [
                Text(
                  roomObj.roomName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    decoration: isCancelled
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                if (isCancelled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'Dibatalkan',
                      style: TextStyle(fontSize: 10, color: Colors.red.shade600, fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else if (isPast) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Selesai',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              'Tarikh: ${b.bookingDate} | Masa: ${b.startTime.substring(0, 5)} - ${b.endTime.substring(0, 5)}',
              style: TextStyle(color: subtitleColor),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(b.purpose ?? '-',
                    style: TextStyle(color: subtitleColor)),
                // NEW: cancel button — only for active, non-past bookings
                if (!isCancelled && !isPast) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Batalkan Tempahan',
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _cancelBooking(b, roomObj),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}