class AppNotification {
  final String id;
  final String? recipientId;
  final String? recipientRole;
  final String notificationType; // 'booking_cancelled' | 'booking_reminder' | 'attendance_warning'
  final String message;
  final String? relatedBookingId;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    this.recipientId,
    this.recipientRole,
    required this.notificationType,
    required this.message,
    this.relatedBookingId,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      recipientId: json['recipient_id'] as String?,
      recipientRole: json['recipient_role'] as String?,
      notificationType: json['notification_type'] as String? ?? 'attendance_warning',
      message: json['message'] as String? ?? '',
      relatedBookingId: json['related_booking_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}