class MessageThread {
  final String id;
  final String rideId;
  final String participantName;
  final String participantImage;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isActive;

  MessageThread({
    required this.id,
    required this.rideId,
    required this.participantName,
    required this.participantImage,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isActive,
  });
}

class ChatMessage {
  final String id;
  final String senderId;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.message,
    required this.timestamp,
    required this.isRead,
    required this.type,
  });
}

enum MessageType { text, image, location, system }
