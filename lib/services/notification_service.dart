import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class NotificationService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'data': data,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Notification sent: $title');
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  /// Get user's notifications
  Future<List<Map<String, dynamic>>> getNotifications({
    bool unreadOnly = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      if (unreadOnly) {
        // Query for unread only
        final response = await _supabase
            .from('notifications')
            .select('*')
            .eq('user_id', userId)
            .eq('is_read', false)
            .order('created_at', ascending: false)
            .limit(50);

        return List<Map<String, dynamic>>.from(response);
      } else {
        // Query for all notifications
        final response = await _supabase
            .from('notifications')
            .select('*')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(50);

        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      return [];
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      print('✅ Notification marked as read');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      print('✅ All notifications marked as read');
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);

      print('✅ Notification deleted');
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  /// Subscribe to new notifications
  RealtimeChannel subscribeToNotifications({
    required Function(Map<String, dynamic>) onNewNotification,
  }) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final channel = _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            print('🔔 New notification: ${payload.newRecord}');
            onNewNotification(payload.newRecord);
          },
        )
        .subscribe();

    return channel;
  }

  /// Unsubscribe from notifications
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }

  /// Create a manual notification (for testing or special cases)
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedId,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'related_id': relatedId,
      });

      print('✅ Notification created');
    } catch (e) {
      print('❌ Error creating notification: $e');
    }
  }
}
