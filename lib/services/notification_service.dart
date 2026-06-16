// lib/services/notification_service.dart
//
// Shared per-user notification data access.
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/app_notification.dart';
import '../models/attendance_summary.dart';
import '../models/user_profile.dart';

class NotificationService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchWarningNotifications(
    UserProfile user,
  ) async {
    if (SupabaseConfig.isPlaceholder) return [];
    try {
      final data = await _client
          .from('notifications')
          .select()
          .eq('notification_type', 'attendance_warning')
          .eq('recipient_id', user.id)
          .order('warning_level', ascending: false)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  Future<List<AppNotification>> fetchForUser(String userId) async {
    if (SupabaseConfig.isPlaceholder) return [];
    final rows = await _client
        .from('notifications')
        .select()
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((row) => AppNotification.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchRowsForUser(String userId) async {
    if (SupabaseConfig.isPlaceholder) return [];
    final rows = await _client
        .from('notifications')
        .select()
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<int> unreadCount(String userId) async {
    if (SupabaseConfig.isPlaceholder) return 0;
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('recipient_id', userId)
        .eq('is_read', false);
    return (rows as List).length;
  }

  Future<void> markNotificationRead({
    required dynamic id,
    required UserProfile user,
  }) async {
    if (SupabaseConfig.isPlaceholder || id == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('recipient_id', user.id);
  }

  Future<void> markAsRead(String notificationId) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllWarningNotificationsRead(UserProfile user) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('notification_type', 'attendance_warning')
        .eq('recipient_id', user.id);
  }

  Future<void> markAllAsRead(String userId) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', userId)
        .eq('is_read', false);
  }

  Future<void> generateWarningEscalations(
    List<AttendanceSummary> summaries, {
    required String timetableId,
  }) async {
    if (SupabaseConfig.isPlaceholder) return;
    try {
      final timetable =
          await _client
              .from('timetable')
              .select('id, lecturer_id, department_unit')
              .eq('id', timetableId)
              .maybeSingle();
      if (timetable == null) return;

      final lecturerId = timetable['lecturer_id']?.toString();
      final departmentUnit = timetable['department_unit']?.toString();

      final recipientIdsByRole = <String, Set<String>>{};

      void addRecipient(String role, String? userId) {
        if (userId == null || userId.isEmpty) return;
        recipientIdsByRole.putIfAbsent(role, () => <String>{}).add(userId);
      }

      addRecipient('Lecturer', lecturerId);

      if (departmentUnit != null && departmentUnit.isNotEmpty) {
        final departmentRows = await _client
            .from('profiles')
            .select('id, role')
            .eq('department_unit', departmentUnit)
            .eq('is_active', true)
            .inFilter('role', ['Ketua Program', 'Ketua Jabatan']);

        for (final row
            in (departmentRows as List).cast<Map<String, dynamic>>()) {
          final role = row['role']?.toString();
          final id = row['id']?.toString();
          if (role == null || role.isEmpty) continue;
          addRecipient(role, id);
        }
      }

      final tpaRows = await _client
          .from('profiles')
          .select('id')
          .eq('role', 'Timbalan Pengarah Akademik')
          .eq('is_active', true);
      for (final row in (tpaRows as List).cast<Map<String, dynamic>>()) {
        addRecipient(
          'Timbalan Pengarah Akademik',
          row['id']?.toString(),
        );
      }

      final payload = <Map<String, dynamic>>[];
      for (final summary in summaries) {
        if (summary.countedRecords == 0 || summary.warningLevel == 0) continue;
        debugPrint(
          'Generating notification for ${summary.studentName}: '
          'percent=${summary.attendancePercent.toStringAsFixed(2)}, '
          'level=${summary.warningLevel}',
        );
        final recipients = _recipientsForLevel(summary.warningLevel);
        for (final role in recipients) {
          final users = recipientIdsByRole[role] ?? const <String>{};
          for (final userId in users) {
            payload.add({
              'recipient_id': userId,
              'recipient_role': role,
              'warning_level': summary.warningLevel,
              'notification_type': 'attendance_warning',
              'is_read': false,
              'message':
                  'Kehadiran ${summary.studentName} ialah ${summary.attendancePercent.toStringAsFixed(1)}%. Sila semak dan ambil tindakan susulan.',
            });
          }
        }
      }
      if (payload.isNotEmpty) {
        await _client.from('notifications').insert(payload);
      }
    } catch (e) {
      debugPrint('generateWarningEscalations error: $e');
    }
  }

  Future<void> notifyBookingCancelled({
    required String recipientId,
    required String roomName,
    required String bookingDate,
    required String bookingId,
  }) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client.from('notifications').insert({
      'recipient_id': recipientId,
      'notification_type': 'booking_cancelled',
      'related_booking_id': bookingId,
      'message':
          'Tempahan anda untuk $roomName pada $bookingDate telah dibatalkan oleh Admin.',
      'is_read': false,
    });
  }

  Future<void> checkAndCreateBookingReminders(String userId) async {
    if (SupabaseConfig.isPlaceholder) return;

    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);

    try {
      final bookings = await _client
          .from('bookings')
          .select('id, booking_date, start_time, rooms(room_name)')
          .eq('user_id', userId)
          .eq('status', 'active')
          .inFilter('booking_date', [todayStr, tomorrowStr]);

      for (final row in (bookings as List)) {
        final bookingId = row['id'] as String;
        final date = row['booking_date'].toString();
        final startTime = row['start_time'].toString().substring(0, 5);
        final roomName =
            (row['rooms'] as Map<String, dynamic>?)?['room_name'] ?? 'Bilik';
        final isToday = date == todayStr;
        final type =
            isToday ? 'booking_reminder_today' : 'booking_reminder_tomorrow';

        final existing = await _client
            .from('notifications')
            .select('id')
            .eq('related_booking_id', bookingId)
            .eq('notification_type', type)
            .maybeSingle();

        if (existing == null) {
          final whenText = isToday ? 'HARI INI' : 'esok';
          await _client.from('notifications').insert({
            'recipient_id': userId,
            'notification_type': type,
            'related_booking_id': bookingId,
            'message':
                'Peringatan: Anda mempunyai tempahan $roomName $whenText pada $startTime.',
            'is_read': false,
          });
        }
      }
    } catch (_) {
      // Reminders are non-critical.
    }
  }

  List<String> _recipientsForLevel(int level) {
    switch (level) {
      case 1:
        return ['Lecturer', 'Ketua Program'];
      case 2:
        return ['Lecturer', 'Ketua Program', 'Ketua Jabatan'];
      case 3:
        return [
          'Lecturer',
          'Ketua Program',
          'Ketua Jabatan',
          'Timbalan Pengarah Akademik',
        ];
      default:
        return const [];
    }
  }
}
