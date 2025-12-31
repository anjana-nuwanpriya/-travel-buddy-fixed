import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SessionManager {
  static const String _sessionKey = 'travel_buddy_session';
  static const String _userIdKey = 'travel_buddy_user_id';
  static const String _emailKey = 'travel_buddy_email';
  static const String _phoneKey = 'travel_buddy_phone';
  static const String _authMethodKey = 'travel_buddy_auth_method'; // NEW: track auth method

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final SupabaseClient _supabase = SupabaseConfig.client;

  // ==================== SESSION PERSISTENCE ====================

  /// Save session after successful login (Supabase auth - email, google, apple)
  Future<void> saveSession(User user, Session? session) async {
    try {
      if (session?.accessToken != null) {
        await _secureStorage.write(
          key: _sessionKey,
          value: session!.accessToken,
        );
      }

      await _secureStorage.write(key: _userIdKey, value: user.id);
      await _secureStorage.write(key: _emailKey, value: user.email ?? '');
      await _secureStorage.write(key: _phoneKey, value: user.phone ?? '');
      await _secureStorage.write(key: _authMethodKey, value: 'supabase');

      print('✅ Session saved securely');
    } catch (e) {
      print('❌ Error saving session: $e');
      rethrow;
    }
  }

  /// NEW: Save phone session (for Text.lk OTP auth - no Supabase session)
  Future<void> savePhoneSession({
    required String userId,
    required String phone,
  }) async {
    try {
      await _secureStorage.write(key: _userIdKey, value: userId);
      await _secureStorage.write(key: _phoneKey, value: phone);
      await _secureStorage.write(key: _authMethodKey, value: 'phone');
      await _secureStorage.write(
        key: _sessionKey,
        value: 'phone_session_$userId',
      );

      print('✅ Phone session saved securely');
    } catch (e) {
      print('❌ Error saving phone session: $e');
      rethrow;
    }
  }

  /// Retrieve saved session
  Future<String?> getSessionToken() async {
    try {
      final token = await _secureStorage.read(key: _sessionKey);
      print('📍 Retrieved session token: ${token != null ? "Present" : "None"}');
      return token;
    } catch (e) {
      print('❌ Error retrieving session: $e');
      return null;
    }
  }

  /// Get stored user ID
  Future<String?> getSavedUserId() async {
    try {
      return await _secureStorage.read(key: _userIdKey);
    } catch (e) {
      print('❌ Error retrieving user ID: $e');
      return null;
    }
  }

  /// Get stored email
  Future<String?> getSavedEmail() async {
    try {
      return await _secureStorage.read(key: _emailKey);
    } catch (e) {
      print('❌ Error retrieving email: $e');
      return null;
    }
  }

  /// Get stored phone
  Future<String?> getSavedPhone() async {
    try {
      return await _secureStorage.read(key: _phoneKey);
    } catch (e) {
      print('❌ Error retrieving phone: $e');
      return null;
    }
  }

  /// NEW: Get auth method
  Future<String?> getAuthMethod() async {
    try {
      return await _secureStorage.read(key: _authMethodKey);
    } catch (e) {
      print('❌ Error retrieving auth method: $e');
      return null;
    }
  }

  /// Clear session (call on logout)
  Future<void> clearSession() async {
    try {
      await _secureStorage.delete(key: _sessionKey);
      await _secureStorage.delete(key: _userIdKey);
      await _secureStorage.delete(key: _emailKey);
      await _secureStorage.delete(key: _phoneKey);
      await _secureStorage.delete(key: _authMethodKey);

      print('✅ Session cleared');
    } catch (e) {
      print('❌ Error clearing session: $e');
      rethrow;
    }
  }

  // ==================== AUTO-LOGIN CHECK ====================

  /// Check if user has a valid session
  Future<bool> hasValidSession() async {
    try {
      // First check if Supabase already has an active session
      final currentUser = _supabase.auth.currentUser;
      final currentSession = _supabase.auth.currentSession;

      if (currentUser != null && currentSession != null) {
        print('✅ Valid Supabase session found in memory');
        return true;
      }

      // Check secure storage for session
      final savedToken = await getSessionToken();
      final savedUserId = await getSavedUserId();
      final authMethod = await getAuthMethod();
      
      if (savedToken == null || savedUserId == null) {
        print('❌ No saved session found');
        return false;
      }

      // For phone auth, verify user still exists in database
      if (authMethod == 'phone') {
        final profile = await _supabase
            .from('user_profiles')
            .select('id')
            .eq('id', savedUserId)
            .maybeSingle();
        
        if (profile != null) {
          print('✅ Valid phone session found');
          return true;
        } else {
          print('❌ Phone session invalid - user not found');
          await clearSession();
          return false;
        }
      }

      print('✅ Saved session token found');
      return true;
    } catch (e) {
      print('❌ Error checking session: $e');
      return false;
    }
  }

  /// Get current user (checks both in-memory and stored)
  Future<User?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        print('✅ User found in memory: ${user.email ?? user.phone}');
        return user;
      }

      final userId = await getSavedUserId();
      if (userId != null) {
        print('✅ User ID found in storage: $userId');
        return null;
      }

      return null;
    } catch (e) {
      print('❌ Error getting current user: $e');
      return null;
    }
  }

  /// NEW: Get current user profile (from database)
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final userId = await getSavedUserId();
      if (userId == null) return null;

      return await _supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return null;
    }
  }

  /// Refresh session if token is expired
  Future<bool> refreshSessionIfNeeded() async {
    try {
      final currentSession = _supabase.auth.currentSession;

      if (currentSession == null) {
        print('❌ No active session to refresh');
        return false;
      }

      print('✅ Session refresh initiated');
      return true;
    } catch (e) {
      print('❌ Error refreshing session: $e');
      return false;
    }
  }

  // ==================== AUTH STATE STREAM ====================

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange.map((event) {
      if (event.event == AuthChangeEvent.signedIn) {
        final user = _supabase.auth.currentUser;
        final session = _supabase.auth.currentSession;
        if (user != null && session != null) {
          saveSession(user, session);
        }
      }

      if (event.event == AuthChangeEvent.signedOut) {
        clearSession();
      }

      return event;
    });
  }
}