import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class MessageService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  /// Get all conversations for current user
  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // First get conversations
      final conversations = await _supabase
          .from('conversations')
          .select('*')
          .or('participant1_id.eq.$userId,participant2_id.eq.$userId')
          .order('last_message_time', ascending: false);

      // Then manually fetch related data
      List<Map<String, dynamic>> enrichedConversations = [];

      for (var conv in conversations) {
        // Get participant profiles
        final participant1 = await _supabase
            .from('user_profiles')
            .select('id, full_name, avatar_url')
            .eq('id', conv['participant1_id'])
            .maybeSingle();

        final participant2 = await _supabase
            .from('user_profiles')
            .select('id, full_name, avatar_url')
            .eq('id', conv['participant2_id'])
            .maybeSingle();

        // Get ride info
        Map<String, dynamic>? ride;
        if (conv['ride_id'] != null) {
          ride = await _supabase
              .from('rides')
              .select('from_location, to_location')
              .eq('id', conv['ride_id'])
              .maybeSingle();
        }

        // Add to enriched list
        enrichedConversations.add({
          ...conv,
          'participant1': participant1,
          'participant2': participant2,
          'ride': ride,
        });
      }

      return enrichedConversations;
    } catch (e) {
      print('❌ Error fetching conversations: $e');
      return [];
    }
  }

  /// Get or create conversation
  Future<String?> getOrCreateConversation({
    required String rideId,
    required String otherUserId,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final existing = await _supabase
          .from('conversations')
          .select('id')
          .eq('ride_id', rideId)
          .or(
            'and(participant1_id.eq.$currentUserId,participant2_id.eq.$otherUserId),'
            'and(participant1_id.eq.$otherUserId,participant2_id.eq.$currentUserId)',
          )
          .maybeSingle();

      if (existing != null) return existing['id'] as String;

      final response = await _supabase
          .from('conversations')
          .insert({
            'ride_id': rideId,
            'participant1_id': currentUserId,
            'participant2_id': otherUserId,
            'last_message': 'Conversation started',
          })
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      print('❌ Error creating conversation: $e');
      return null;
    }
  }

  /// Get unread count
  Future<int> getUnreadCount(String conversationId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .eq('is_read', false)
          .neq('sender_id', userId);

      return (response as List).length;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Get messages
  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    try {
      // Get messages
      final messages = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      // Enrich with sender info
      List<Map<String, dynamic>> enrichedMessages = [];

      for (var message in messages) {
        final sender = await _supabase
            .from('user_profiles')
            .select('id, full_name, avatar_url')
            .eq('id', message['sender_id'])
            .maybeSingle();

        enrichedMessages.add({...message, 'sender': sender});
      }

      return enrichedMessages;
    } catch (e) {
      print('❌ Error fetching messages: $e');
      return [];
    }
  }

  /// Send message
  Future<bool> sendMessage({
    required String conversationId,
    required String message,
    String messageType = 'text',
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': userId,
        'message': message,
        'message_type': messageType,
        'is_read': false,
      });

      print('✅ Message sent');
      return true;
    } catch (e) {
      print('❌ Error sending message: $e');
      return false;
    }
  }

  /// Mark as read
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_read', false);

      print('✅ Messages marked as read');
    } catch (e) {
      print('❌ Error marking as read: $e');
    }
  }

  /// Subscribe to new messages
  RealtimeChannel subscribeToMessages({
    required String conversationId,
    required Function(Map<String, dynamic>) onNewMessage,
  }) {
    final channel = _supabase
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            print('🔔 New message: ${payload.newRecord}');
            onNewMessage(payload.newRecord);
          },
        )
        .subscribe();

    return channel;
  }

  /// Subscribe to conversations
  RealtimeChannel subscribeToConversations({
    required Function(Map<String, dynamic>) onConversationUpdate,
  }) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final channel = _supabase
        .channel('conversations:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            print('🔔 Conversation updated');
            onConversationUpdate(payload.newRecord);
          },
        )
        .subscribe();

    return channel;
  }

  /// Unsubscribe
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }
}
