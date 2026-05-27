// lib/screens/room_booking_screen.dart
//
// Modul 6: Tempahan Bilik.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/booking.dart';
import '../models/room.dart';
import '../providers/user_provider.dart';
import '../services/room_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

class RoomBookingScreen extends StatefulWidget {
  const RoomBookingScreen({super.key});

  @override
  State<RoomBookingScreen> createState() => _RoomBookingScreenState();
}

class _RoomBookingScreenState extends State<RoomBookingScreen> {
  final _service = RoomService();
  final _purposeCtrl = TextEditingController();

  // FIX 1: Set the default state date directly to tomorrow (1 day ahead)
  static DateTime get _tomorrow => DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ).add(const Duration(days: 1));

  DateTime _date = _tomorrow;
  Room? _room;
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);

  List<Room> _rooms = const [];
  List<Booking> _bookingsForRoom = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    _rooms = await _service.fetchAvailableRooms();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadBookings() async {
    if (_room == null) return;
    _bookingsForRoom = await _service.fetchBookingsForRoomDate(
      roomId: _room!.id,
      date: DateFormat('yyyy-MM-dd').format(_date),
    );
    if (mounted) setState(() {});
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _dayOfWeek(DateTime d) {
    const map = {
      DateTime.monday: 'Isnin',
      DateTime.tuesday: 'Selasa',
      DateTime.wednesday: 'Rabu',
      DateTime.thursday: 'Khamis',
      DateTime.friday: 'Jumaat',
      DateTime.saturday: 'Sabtu',
      DateTime.sunday: 'Ahad',
    };
    return map[d.weekday]!;
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    // Calculate tomorrow cleanly to strip out current hour/minute variables
    final tomorrowDate = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(tomorrowDate) ? tomorrowDate : _date,
      // Change from past/today selection to lock it to tomorrow onwards
      firstDate: tomorrowDate,
      lastDate: DateTime(today.year + 1),
    );

    if (picked != null) {
      setState(() => _date = picked);
      await _loadBookings();
    }
  }

  Future<void> _submit() async {
    if (_room == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila pilih bilik.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);
      final startStr = _formatTime(_start);
      final endStr = _formatTime(_end);

      final ttFree = await _service.isTimetableSlotFree(
        roomId: _room!.id,
        day: _dayOfWeek(_date),
        startTime: startStr,
        endTime: endStr,
      );
      if (!ttFree) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Jadual Tetap / Timetable Conflict — slot ini dikunci.')),
        );
        return;
      }

      final bookingFree = await _service.isBookingSlotFree(
        roomId: _room!.id,
        bookingDate: dateStr,
        startTime: startStr,
        endTime: endStr,
      );
      if (!bookingFree) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bilik sudah ditempah untuk slot masa ini!')),
        );
        return;
      }

      if (!mounted) return;
      final user = context.read<UserProvider>().profile!;
      await _service.createBooking(Booking(
        roomId: _room!.id,
        userId: user.id,
        bookingDate: dateStr,
        startTime: startStr,
        endTime: endStr,
        purpose: _purposeCtrl.text.trim(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tempahan berjaya!')),
      );
      _purposeCtrl.clear();
      await _loadBookings();
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
      title: 'Tempahan Bilik',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      _form(),
                      const SizedBox(height: 16),
                      _slotsView(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _form() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Borang Tempahan',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppTheme.navy, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int>(
                    initialValue: _room?.id,
                    decoration: const InputDecoration(labelText: 'Bilik'),
                    items: _rooms
                        .map((r) => DropdownMenuItem(
                            value: r.id, child: Text(r.roomName)))
                        .toList(),
                    onChanged: (v) async {
                      setState(() {
                        _room = _rooms.firstWhere((r) => r.id == v);
                      });
                      await _loadBookings();
                    },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event),
                    label: Text(DateFormat('d MMM yyyy', 'ms').format(_date)),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: context, initialTime: _start);
                      if (t != null) setState(() => _start = t);
                    },
                    child: Text('Mula: ${_start.format(context)}'),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: context, initialTime: _end);
                      if (t != null) setState(() => _end = t);
                    },
                    child: Text('Tamat: ${_end.format(context)}'),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _purposeCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Tujuan Tempahan'),
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
                    : const Icon(Icons.check),
                label: const Text('Hantar Tempahan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotsView() {
    if (_room == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Pilih bilik untuk lihat tempahan semasa.',
              style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tempahan untuk ${_room!.roomName} '
              '(${DateFormat('d MMM', 'ms').format(_date)})',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppTheme.navy),
            ),
            const SizedBox(height: 8),
            if (_bookingsForRoom.isEmpty)
              const Text('Tiada tempahan pada tarikh ini.',
                  style: TextStyle(color: AppTheme.textMuted))
            else
              ..._bookingsForRoom.map((b) {
                String fmt(String s) => s.length >= 5 ? s.substring(0, 5) : s;
                return ListTile(
                  leading:
                      const Icon(Icons.event_available, color: AppTheme.teal),
                  title: Text('${fmt(b.startTime)} - ${fmt(b.endTime)}'),
                  subtitle: Text(b.purpose ?? '-'),
                );
              }),
          ],
        ),
      ),
    );
  }
}
