import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/app_notification.dart';

class NotificationService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Fetch notifications for the current user.
  Future<List<AppNotification>> fetchForUser(String userId) async {
    if (SupabaseConfig.isPlaceholder) return [];
    final rows = await _client
        .from('notifications')
        .select()
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((r) => AppNotification.fromJson(r as Map<String, dynamic>))
        .toList();
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

  Future<void> markAsRead(String notificationId) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', userId)
        .eq('is_read', false);
  }

  /// Send a cancellation notification to the booking owner.
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

  /// Called on login: scans the user's bookings for today/tomorrow and
  /// creates reminder notifications if not already sent.
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
        final type = isToday ? 'booking_reminder_today' : 'booking_reminder_tomorrow';

        // Check if this reminder was already sent
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
      // Fail silently — reminders are non-critical
    }
  }
}