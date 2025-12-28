import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/colors.dart';
import '../../services/message_service.dart';
import '../../services/simplified_unified_auth_service.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _messageService = MessageService();
  final _authService = SimplifiedUnifiedAuthService();

  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  RealtimeChannel? _conversationChannel;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _subscribeToConversations();
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final conversations = await _messageService.getConversations();

    if (!mounted) return;

    // Load unread counts for each conversation
    for (var conv in conversations) {
      final unread = await _messageService.getUnreadCount(conv['id']);
      conv['unread_count'] = unread;
    }

    if (!mounted) return;

    setState(() {
      _conversations = conversations;
      _isLoading = false;
    });
  }

  void _subscribeToConversations() {
    _conversationChannel = _messageService.subscribeToConversations(
      onConversationUpdate: (data) {
        if (mounted) {
          _loadConversations();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Messages',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _conversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadConversations,
                  child: ListView.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _buildConversationTile(_conversations[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final currentUserId = _authService.currentUser?.id;
    final isParticipant1 = conversation['participant1_id'] == currentUserId;
    final otherUser = isParticipant1
        ? conversation['participant2']
        : conversation['participant1'];

    final userName = otherUser?['full_name'] ?? 'Unknown User';
    final avatarUrl = otherUser?['avatar_url'];
    final lastMessage = conversation['last_message'] ?? '';
    final lastMessageTime = DateTime.parse(conversation['last_message_time']);
    final unreadCount = conversation['unread_count'] ?? 0;
    final rideInfo = conversation['ride'];

    return Container(
      color: unreadCount > 0 ? AppColors.messageUnread : Colors.white,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      userName[0].toUpperCase(),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                userName,
                style: TextStyle(
                  fontWeight: unreadCount > 0
                      ? FontWeight.bold
                      : FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatTime(lastMessageTime),
              style: TextStyle(
                fontSize: 12,
                color: unreadCount > 0
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight: unreadCount > 0
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rideInfo != null) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${rideInfo['from_location']} → ${rideInfo['to_location']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 4),
            Text(
              lastMessage,
              style: TextStyle(
                fontSize: 14,
                color: unreadCount > 0
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: unreadCount > 0
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        onTap: () => _openChat(conversation),
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
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.message_outlined,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Messages Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Start chatting with other travelers\nwhen you book or offer rides',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(Map<String, dynamic> conversation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(conversation: conversation),
      ),
    );
    if (mounted) {
      _loadConversations();
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  @override
  void dispose() {
    if (_conversationChannel != null) {
      _messageService.unsubscribe(_conversationChannel!);
    }
    super.dispose();
  }
}