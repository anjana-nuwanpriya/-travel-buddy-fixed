import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ride.dart';
import '../models/booking.dart';

class ApiService {
  static const String baseUrl = 'https://your-api-server.com/api';
  static String? _authToken;

  // Initialize with stored token
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
  }

  // Authentication
  static Future<Map<String, dynamic>> login(String phone, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'otp': otp}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _authToken = data['token'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _authToken!);

      return data;
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  static Future<void> logout() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Generic HTTP methods
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  static Future<dynamic> _get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  static Future<dynamic> _post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  static Future<dynamic> _put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  static Future<dynamic> _delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/$endpoint'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      logout(); // Token expired
      throw Exception('Authentication failed');
    } else {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  // Ride APIs
  static Future<List<Ride>> searchRides({
    required String from,
    required String to,
    required DateTime date,
    Map<String, dynamic>? filters,
  }) async {
    final queryParams = {
      'from': from,
      'to': to,
      'date': date.toIso8601String(),
      if (filters != null) ...filters,
    };

    final uri = Uri.parse('$baseUrl/rides/search').replace(
      queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())),
    );

    final response = await http.get(uri, headers: _headers);
    final data = _handleResponse(response);

    return (data['rides'] as List)
        .map((rideJson) => Ride.fromJson(rideJson))
        .toList();
  }

  static Future<Ride> getRideDetails(String rideId) async {
    final data = await _get('rides/$rideId');
    return Ride.fromJson(data['ride']);
  }

  static Future<Booking> bookRide({
    required String rideId,
    required int seats,
    required String paymentMethod,
    String? paymentId,
  }) async {
    final data = await _post('bookings', {
      'rideId': rideId,
      'seats': seats,
      'paymentMethod': paymentMethod,
      if (paymentId != null) 'paymentId': paymentId,
    });

    return Booking.fromJson(data['booking']);
  }

  static Future<Ride> publishRide(Map<String, dynamic> rideData) async {
    final data = await _post('rides', rideData);
    return Ride.fromJson(data['ride']);
  }

  static Future<List<Booking>> getMyBookings() async {
    final data = await _get('bookings/my');
    return (data['bookings'] as List)
        .map((booking) => Booking.fromJson(booking))
        .toList();
  }

  static Future<List<Ride>> getMyPublishedRides() async {
    final data = await _get('rides/my');
    return (data['rides'] as List).map((ride) => Ride.fromJson(ride)).toList();
  }

  // User APIs - Commented out until User model has fromJson method
  /*
  static Future<User> getProfile() async {
    final data = await _get('user/profile');
    return User.fromJson(data['user']);
  }

  static Future<User> updateProfile(Map<String, dynamic> profileData) async {
    final data = await _put('user/profile', profileData);
    return User.fromJson(data['user']);
  }
  */

  // Messaging APIs - Commented out until MessageThread and ChatMessage models are created
  /*
  static Future<List<MessageThread>> getMessageThreads() async {
    final data = await _get('messages/threads');
    return (data['threads'] as List)
        .map((thread) => MessageThread.fromJson(thread))
        .toList();
  }

  static Future<List<ChatMessage>> getChatMessages(String chatId) async {
    final data = await _get('messages/chat/$chatId');
    return (data['messages'] as List)
        .map((message) => ChatMessage.fromJson(message))
        .toList();
  }

  static Future<ChatMessage> sendMessage(String chatId, String message) async {
    final data = await _post('messages/send', {
      'chatId': chatId,
      'message': message,
    });
    return ChatMessage.fromJson(data['message']);
  }
  */
}
