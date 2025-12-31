import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';

/// Text.lk SMS Service for OTP Authentication
/// Integrates with Text.lk SMS Gateway Sri Lanka
/// This is a standalone service - does NOT modify any existing code
class TextLkSmsService {
  static final TextLkSmsService _instance = TextLkSmsService._internal();
  factory TextLkSmsService() => _instance;
  TextLkSmsService._internal();

  // ==================== TEXT.LK CONFIGURATION ====================
  static const String _apiKey = '2384|ommR1IUGjhPhmx50tPOxm76NPVh4bc05agRAsjKz841307b4';
  static const String _senderId = 'Ride Buddy';
  static const String _apiUrl = 'https://app.text.lk/api/v3/sms/send';
  
  // OTP Configuration
  static const int otpLength = 6;
  static const int otpExpiryMinutes = 5;
  static const int maxAttempts = 3;

  // ==================== SEND OTP ====================
  
  /// Send OTP to phone number
  /// [phoneNumber] - Phone number (e.g., 0771234567 or +94771234567)
  /// [purpose] - 'signup' or 'signin'
  Future<Map<String, dynamic>> sendOtp({
    required String phoneNumber,
    required String purpose,
  }) async {
    try {
      // Format phone number
      final formattedPhone = formatPhoneNumber(phoneNumber);
      debugPrint('📱 [TEXT.LK] Sending OTP to: $formattedPhone');

      // Check if there's an existing unexpired OTP
      final existingOtp = await _getExistingOtp(formattedPhone);
      if (existingOtp != null) {
        final expiresAt = DateTime.parse(existingOtp['expires_at']);
        final now = DateTime.now().toUtc();
        
        if (expiresAt.isAfter(now)) {
          final remainingSeconds = expiresAt.difference(now).inSeconds;
          debugPrint('⏳ Existing OTP still valid for $remainingSeconds seconds');
          
          return {
            'success': false,
            'message': 'Please wait ${remainingSeconds}s before requesting a new OTP',
            'remainingSeconds': remainingSeconds,
            'rateLimited': true,
          };
        }
      }

      // Generate new OTP
      final otp = _generateOtp();
      debugPrint('🔐 Generated OTP: $otp');

      // Prepare message
      final message = 'Your Travel Buddy verification code is: $otp. Valid for $otpExpiryMinutes minutes. Do not share this code with anyone.';

      // Send SMS via Text.lk API
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'recipient': formattedPhone,
          'sender_id': _senderId,
          'type': 'plain',
          'message': message,
        }),
      );

      debugPrint('📨 Text.lk Response Status: ${response.statusCode}');
      debugPrint('📨 Text.lk Response Body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && 
          (responseData['status'] == 'success' || responseData['status'] == 'pending')) {
        
        // Store OTP in database
        await _storeOtp(
          phoneNumber: formattedPhone,
          otpCode: otp,
        );

        debugPrint('✅ OTP sent and stored successfully');
        
        return {
          'success': true,
          'message': 'OTP sent successfully',
          'phoneNumber': formattedPhone,
          'expiresInMinutes': otpExpiryMinutes,
        };
      } else {
        debugPrint('❌ Text.lk API Error: ${responseData['message']}');
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      debugPrint('❌ Error sending OTP: $e');
      return {
        'success': false,
        'message': 'Failed to send OTP. Please try again.',
        'error': e.toString(),
      };
    }
  }

  // ==================== VERIFY OTP ====================
  
  /// Verify OTP entered by user
  Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    try {
      final formattedPhone = formatPhoneNumber(phoneNumber);
      debugPrint('🔐 [TEXT.LK] Verifying OTP for: $formattedPhone');

      // Get stored OTP from database
      final storedOtp = await _getExistingOtp(formattedPhone);

      if (storedOtp == null) {
        debugPrint('❌ No OTP found for this phone number');
        return {
          'success': false,
          'message': 'No OTP found. Please request a new one.',
          'notFound': true,
        };
      }

      // Check if OTP has expired
      final expiresAt = DateTime.parse(storedOtp['expires_at']);
      if (DateTime.now().toUtc().isAfter(expiresAt)) {
        debugPrint('❌ OTP has expired');
        await _deleteOtp(formattedPhone);
        return {
          'success': false,
          'message': 'OTP has expired. Please request a new one.',
          'expired': true,
        };
      }

      // Check attempt count
      final attemptCount = storedOtp['attempt_count'] ?? 0;
      if (attemptCount >= maxAttempts) {
        debugPrint('❌ Maximum attempts exceeded');
        await _deleteOtp(formattedPhone);
        return {
          'success': false,
          'message': 'Maximum attempts exceeded. Please request a new OTP.',
          'maxAttemptsExceeded': true,
        };
      }

      // Verify OTP
      if (storedOtp['otp_code'] == otpCode) {
        debugPrint('✅ OTP verified successfully');
        
        // Mark as verified
        await _markOtpVerified(formattedPhone);
        
        return {
          'success': true,
          'message': 'Phone number verified successfully',
          'phoneNumber': formattedPhone,
        };
      } else {
        debugPrint('❌ Invalid OTP');
        
        // Increment attempt count
        await _incrementAttemptCount(formattedPhone);
        
        final remainingAttempts = maxAttempts - (attemptCount + 1);
        return {
          'success': false,
          'message': 'Invalid OTP. $remainingAttempts attempts remaining.',
          'remainingAttempts': remainingAttempts,
        };
      }
    } catch (e) {
      debugPrint('❌ Error verifying OTP: $e');
      return {
        'success': false,
        'message': 'Verification failed. Please try again.',
        'error': e.toString(),
      };
    }
  }

  // ==================== RESEND OTP ====================
  
  /// Resend OTP to phone number
  Future<Map<String, dynamic>> resendOtp({
    required String phoneNumber,
    required String purpose,
  }) async {
    final formattedPhone = formatPhoneNumber(phoneNumber);
    
    // Delete existing OTP
    await _deleteOtp(formattedPhone);
    
    // Send new OTP
    return sendOtp(phoneNumber: phoneNumber, purpose: purpose);
  }

  // ==================== PHONE NUMBER FORMATTING ====================

  /// Format phone number to international format (94XXXXXXXXX)
  String formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Handle Sri Lankan numbers
    if (digits.startsWith('0')) {
      // Local format: 0771234567 -> 94771234567
      digits = '94${digits.substring(1)}';
    } else if (digits.startsWith('94')) {
      // Already in international format
    } else if (digits.length == 9) {
      // Just the number without prefix: 771234567 -> 94771234567
      digits = '94$digits';
    }
    
    return digits;
  }

  /// Check if phone number is valid Sri Lankan number
  bool isValidSriLankanNumber(String phone) {
    final formatted = formatPhoneNumber(phone);
    // Sri Lankan mobile numbers: 94 + 7X + 7 digits
    final regex = RegExp(r'^947[0-9]{8}$');
    return regex.hasMatch(formatted);
  }

  /// Get formatted display number
  String getDisplayNumber(String phone) {
    final formatted = formatPhoneNumber(phone);
    if (formatted.length == 11 && formatted.startsWith('94')) {
      // Format as +94 77 123 4567
      return '+${formatted.substring(0, 2)} ${formatted.substring(2, 4)} ${formatted.substring(4, 7)} ${formatted.substring(7)}';
    }
    return phone;
  }

  // ==================== PRIVATE DATABASE METHODS ====================

  /// Generate random OTP
  String _generateOtp() {
    final random = Random.secure();
    String otp = '';
    for (int i = 0; i < otpLength; i++) {
      otp += random.nextInt(10).toString();
    }
    return otp;
  }

  /// Store OTP in database (using existing otp_attempts table)
  Future<void> _storeOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    final expiresAt = DateTime.now().toUtc().add(Duration(minutes: otpExpiryMinutes));
    
    // Delete any existing OTP for this phone
    await _deleteOtp(phoneNumber);
    
    // Insert new OTP
    await SupabaseConfig.client.from('otp_attempts').insert({
      'phone_number': phoneNumber,
      'otp_code': otpCode,
      'attempt_count': 0,
      'max_attempts': maxAttempts,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    
    debugPrint('✅ OTP stored in database');
  }

  /// Get existing OTP from database
  Future<Map<String, dynamic>?> _getExistingOtp(String phoneNumber) async {
    try {
      final response = await SupabaseConfig.client
          .from('otp_attempts')
          .select()
          .eq('phone_number', phoneNumber)
          .isFilter('verified_at', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      return response;
    } catch (e) {
      debugPrint('❌ Error getting OTP: $e');
      return null;
    }
  }

  /// Delete OTP from database
  Future<void> _deleteOtp(String phoneNumber) async {
    try {
      await SupabaseConfig.client
          .from('otp_attempts')
          .delete()
          .eq('phone_number', phoneNumber);
      
      debugPrint('✅ Existing OTP deleted');
    } catch (e) {
      debugPrint('❌ Error deleting OTP: $e');
    }
  }

  /// Increment attempt count
  Future<void> _incrementAttemptCount(String phoneNumber) async {
    try {
      final current = await _getExistingOtp(phoneNumber);
      if (current != null) {
        final newCount = (current['attempt_count'] ?? 0) + 1;
        
        await SupabaseConfig.client
            .from('otp_attempts')
            .update({'attempt_count': newCount})
            .eq('phone_number', phoneNumber);
      }
    } catch (e) {
      debugPrint('❌ Error incrementing attempt count: $e');
    }
  }

  /// Mark OTP as verified
  Future<void> _markOtpVerified(String phoneNumber) async {
    try {
      await SupabaseConfig.client
          .from('otp_attempts')
          .update({'verified_at': DateTime.now().toUtc().toIso8601String()})
          .eq('phone_number', phoneNumber);
      
      debugPrint('✅ OTP marked as verified');
    } catch (e) {
      debugPrint('❌ Error marking OTP as verified: $e');
    }
  }
}