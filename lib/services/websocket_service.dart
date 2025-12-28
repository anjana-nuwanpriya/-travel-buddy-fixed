import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/message.dart';

class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance =>
      _instance ??= WebSocketService._internal();

  WebSocketService._internal();

  WebSocketChannel? _channel;
  Stream<dynamic>? _stream;

  // Message callbacks
  Function(ChatMessage)? onMessageReceived;
  Function(String)? onUserStatusChanged;
  Function()? onConnectionStatusChanged;

  bool get isConnected => _channel != null;

  void connect(String userId) {
    try {
      // Replace with your WebSocket server URL
      _channel = IOWebSocketChannel.connect(
        'ws://your-server.com/ws?userId=$userId',
      );
      _stream = _channel!.stream.asBroadcastStream();

      _stream!.listen(
        (data) => _handleMessage(data),
        onError: (error) => _handleError(error),
        onDone: () => _handleDisconnection(),
      );

      onConnectionStatusChanged?.call();
    } catch (e) {
      print('WebSocket connection error: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _stream = null;
    onConnectionStatusChanged?.call();
  }

  void sendMessage(String chatId, String message) {
    if (!isConnected) return;

    final messageData = {
      'type': 'message',
      'chatId': chatId,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _channel!.sink.add(jsonEncode(messageData));
  }

  void joinChat(String chatId) {
    if (!isConnected) return;

    final joinData = {'type': 'join', 'chatId': chatId};

    _channel!.sink.add(jsonEncode(joinData));
  }

  void _handleMessage(dynamic data) {
    try {
      final Map<String, dynamic> message = jsonDecode(data);

      switch (message['type']) {
        case 'message':
          final chatMessage = ChatMessage(
            id: message['id'],
            senderId: message['senderId'],
            message: message['message'],
            timestamp: DateTime.parse(message['timestamp']),
            isRead: false,
            type: MessageType.text,
          );
          onMessageReceived?.call(chatMessage);
          break;

        case 'user_status':
          onUserStatusChanged?.call(message['status']);
          break;
      }
    } catch (e) {
      print('Error handling WebSocket message: $e');
    }
  }

  void _handleError(error) {
    print('WebSocket error: $error');
    disconnect();
  }

  void _handleDisconnection() {
    print('WebSocket disconnected');
    _channel = null;
    _stream = null;
    onConnectionStatusChanged?.call();
  }
}
