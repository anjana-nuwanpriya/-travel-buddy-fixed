import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/notification_service.dart';
import '../../utils/colors.dart';
import '../bookings/booking_requests_screen.dart';
import '../rides/my_rides_screen.dart';
import '../messages/messages_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  RealtimeChannel? _notificationChannel;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    final notifications = await _notificationService.getNotifications();

    if (mounted) {
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    }
  }

  void _subscribeToNotifications() {
    try {
      _notificationChannel = _notificationService.subscribeToNotifications(
        onNewNotification: (notification) {
          print('🔔 New notification received: $notification');

          // Add to list and show snackbar
          if (mounted) {
            setState(() {
              _notifications.insert(0, notification);
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(notification['title'] ?? 'New notification'),
                duration: Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'View',
                  onPressed: () {
                    _handleNotificationTap(notification);
                  },
                ),
              ),
            );
          }
        },
      );
    } catch (e) {
      print('❌ Error subscribing to notifications: $e');
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    // Mark as read
    await _notificationService.markAsRead(notification['id']);

    // Navigate based on type
    final type = notification['type'] as String?;
    final relatedId = notification['related_id'] as String?;

    if (!mounted) return;

    switch (type) {
      case 'booking_request':
        // Driver receives booking requests - navigate to booking requests screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookingRequestsScreen(),
          ),
        );
        break;

      case 'booking_confirmed':
      case 'booking_declined':
      case 'ride_started':
      case 'ride_completed':
        // ✅ UPDATED: Navigate to MyRidesScreen and open "Booked" tab (index 0)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => MyRidesScreen(initialTabIndex: 0),
          ),
          (route) => route.isFirst, // Keep only the first route (main screen)
        );
        break;

      case 'message':
        // Navigate to messages screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MessagesScreen(),
          ),
        );
        break;

      default:
        // Show notification details for unknown types
        _showNotificationDetails(notification);
    }

    // Refresh notifications
    _loadNotifications();
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification['title'] ?? 'Notification'),
        content: Text(notification['message'] ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_notifications.any((n) => n['is_read'] == false))
            TextButton(
              onPressed: () async {
                await _notificationService.markAllAsRead();
                _loadNotifications();
              },
              child: Text(
                'Mark all read',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadNotifications,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(vertical: 8),
                itemCount: _notifications.length,
                separatorBuilder: (context, index) => Divider(height: 1),
                itemBuilder: (context, index) {
                  return _buildNotificationCard(_notifications[index]);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'You\'re all caught up!\nNotifications will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['is_read'] == true;
    final type = notification['type'] as String?;
    final createdAt = notification['created_at'] != null
        ? DateTime.parse(notification['created_at'])
        : DateTime.now();

    // Get icon and color based on type
    IconData icon;
    Color iconColor;

    switch (type) {
      case 'booking_request':
        icon = Icons.calendar_month;
        iconColor = Colors.orange;
        break;
      case 'booking_confirmed':
        icon = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'booking_declined':
        icon = Icons.cancel;
        iconColor = Colors.red;
        break;
      case 'ride_started':
        icon = Icons.directions_car;
        iconColor = Colors.blue;
        break;
      case 'ride_completed':
        icon = Icons.flag;
        iconColor = Colors.green;
        break;
      case 'message':
        icon = Icons.message;
        iconColor = Colors.blue;
        break;
      case 'ride_update':
        icon = Icons.info;
        iconColor = AppColors.primary;
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Material(
      color: isRead ? Colors.white : Colors.blue[50],
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: iconColor),
              ),

              SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'] ?? 'Notification',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      notification['message'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _formatTime(createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: Icon(Icons.close, size: 20, color: Colors.grey[400]),
                onPressed: () async {
                  await _notificationService.deleteNotification(
                    notification['id'],
                  );
                  _loadNotifications();
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  @override
  void dispose() {
    if (_notificationChannel != null) {
      _notificationService.unsubscribe(_notificationChannel!);
    }
    super.dispose();
  }
}