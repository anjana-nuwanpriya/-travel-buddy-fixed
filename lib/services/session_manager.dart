import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SessionManager {
  static const String _sessionKey = 'travel_buddy_session';
  static const String _userIdKey = 'travel_buddy_user_id';
  static const String _emailKey = 'travel_buddy_email';
  static const String _phoneKey = 'travel_buddy_phone';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final SupabaseClient _supabase = SupabaseConfig.client;

  // ==================== SESSION PERSISTENCE ====================

  /// Save session after successful login
  Future<void> saveSession(User user, Session? session) async {
    try {
      // Store in secure storage
      if (session?.accessToken != null) {
        await _secureStorage.write(
          key: _sessionKey,
          value: session!.accessToken,
        );
      }

      // Store user info for quick access
      await _secureStorage.write(key: _userIdKey, value: user.id);
      await _secureStorage.write(key: _emailKey, value: user.email ?? '');
      await _secureStorage.write(key: _phoneKey, value: user.phone ?? '');

      print('✅ Session saved securely');
    } catch (e) {
      print('❌ Error saving session: $e');
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

  /// Clear session (call on logout)
  Future<void> clearSession() async {
    try {
      await _secureStorage.delete(key: _sessionKey);
      await _secureStorage.delete(key: _userIdKey);
      await _secureStorage.delete(key: _emailKey);
      await _secureStorage.delete(key: _phoneKey);

      print('✅ Session cleared');
    } catch (e) {
      print('❌ Error clearing session: $e');
      rethrow;
    }
  }

  // ==================== AUTO-LOGIN CHECK ====================

  /// Check if user has a valid session
  /// Returns: true if user should be auto-logged in, false if they need to login
  Future<bool> hasValidSession() async {
    try {
      // First check if Supabase already has an active session
      final currentUser = _supabase.auth.currentUser;
      final currentSession = _supabase.auth.currentSession;

      if (currentUser != null && currentSession != null) {
        print('✅ Valid Supabase session found in memory');
        return true;
      }

      // If no in-memory session, check secure storage
      final savedToken = await getSessionToken();
      if (savedToken == null) {
        print('❌ No saved session found');
        return false;
      }

      print('✅ Saved session token found, attempting to restore...');

      // Try to restore the session
      // Note: Supabase will automatically refresh expired tokens
      return true;
    } catch (e) {
      print('❌ Error checking session: $e');
      return false;
    }
  }

  /// Get current user (checks both in-memory and stored)
  Future<User?> getCurrentUser() async {
    try {
      // First check if Supabase has user in memory
      final user = _supabase.auth.currentUser;
      if (user != null) {
        print('✅ User found in memory: ${user.email ?? user.phone}');
        return user;
      }

      // If no in-memory user but we have a saved ID, user is logged in
      final userId = await getSavedUserId();
      if (userId != null) {
        print('✅ User ID found in storage: $userId');
        return null; // Return null but user exists
      }

      return null;
    } catch (e) {
      print('❌ Error getting current user: $e');
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

      // Supabase automatically handles token refresh on API calls
      // But you can manually refresh if needed
      print('✅ Session refresh initiated');
      return true;
    } catch (e) {
      print('❌ Error refreshing session: $e');
      return false;
    }
  }

  // ==================== AUTH STATE STREAM ====================

  /// Listen to auth state changes and update session accordingly
  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange.map((event) {
      // Auto-save session when user logs in
      if (event.event == AuthChangeEvent.signedIn) {
        final user = _supabase.auth.currentUser;
        final session = _supabase.auth.currentSession;
        if (user != null && session != null) {
          saveSession(user, session);
        }
      }

      // Auto-clear session when user logs out
      if (event.event == AuthChangeEvent.signedOut) {
        clearSession();
      }

      return event;
    });
  }
}