import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Configuration - CORRECTED VERSION
/// Fixed for supabase_flutter: ^2.10.3+
class SupabaseConfig {
  // ==================== CONSTANTS ====================
  /// Your Supabase Project URL
  /// Get from: Supabase Dashboard → Settings → API → Project URL
  static const String supabaseUrl = 'https://qgeefajkplektjzroxex.supabase.co';
  
  /// Your Supabase Anon Key
  /// Get from: Supabase Dashboard → Settings → API → anon public key
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFnZWVmYWprcGxla3RqenJveGV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk0ODU4NDYsImV4cCI6MjA3NTA2MTg0Nn0.MZPfdHQQqPArJRYygNbiSAgyDkiWe8-f7oTqCgolZuU';

  // ==================== PRIVATE VARIABLES ====================
  static late SupabaseClient _client;
  static bool _isInitialized = false;

  // ==================== INITIALIZATION ====================

  /// Initialize Supabase - Call this in main() before runApp()
  static Future<void> initialize({
    String? url,
    String? anonKey,
    bool debug = false,
  }) async {
    try {
      debugPrint('🔵 Initializing Supabase...');
      final finalUrl = url ?? supabaseUrl;
      final finalAnonKey = anonKey ?? supabaseAnonKey;
      
      debugPrint('📍 URL: $finalUrl');

      await Supabase.initialize(
        url: finalUrl,
        anonKey: finalAnonKey,
        debug: debug,
      );

      _client = Supabase.instance.client;
      _isInitialized = true;

      debugPrint('✅ Supabase initialized successfully');
      debugPrint('📊 Current User: ${_client.auth.currentUser?.email}');
    } catch (e) {
      debugPrint('❌ Supabase initialization failed: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  // ==================== STATUS CHECKS ====================

  /// Check if Supabase is initialized
  static bool get isInitialized => _isInitialized;

  /// Check if user is logged in
  static bool get isLoggedIn => _client.auth.currentUser != null;

  /// Check if user has a valid session
  static bool get hasValidSession => _client.auth.currentSession != null;

  // ==================== GETTERS ====================

  /// Get Supabase client instance
  static SupabaseClient get client {
    if (!_isInitialized) {
      throw Exception('Supabase not initialized. Call SupabaseConfig.initialize() in main()');
    }
    return _client;
  }

  /// Get current authenticated user
  static User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (e) {
      debugPrint('⚠️ Error getting current user: $e');
      return null;
    }
  }

  /// Get current user ID
  static String? get currentUserId {
    try {
      return _client.auth.currentUser?.id;
    } catch (e) {
      debugPrint('⚠️ Error getting user ID: $e');
      return null;
    }
  }

  /// Get current user email
  static String? get currentUserEmail {
    try {
      return _client.auth.currentUser?.email;
    } catch (e) {
      debugPrint('⚠️ Error getting user email: $e');
      return null;
    }
  }

  /// Get current user phone
  static String? get currentUserPhone {
    try {
      return _client.auth.currentUser?.phone;
    } catch (e) {
      debugPrint('⚠️ Error getting user phone: $e');
      return null;
    }
  }

  /// Get current session
  static Session? get currentSession {
    try {
      return _client.auth.currentSession;
    } catch (e) {
      debugPrint('⚠️ Error getting session: $e');
      return null;
    }
  }

  /// Get access token
  static String? get accessToken {
    try {
      return _client.auth.currentSession?.accessToken;
    } catch (e) {
      debugPrint('⚠️ Error getting access token: $e');
      return null;
    }
  }

  // ==================== AUTH OPERATIONS ====================

  /// Sign out current user
  static Future<void> signOut() async {
    try {
      debugPrint('🔓 Signing out user...');
      await _client.auth.signOut();
      debugPrint('✅ User signed out successfully');
    } catch (e) {
      debugPrint('❌ Error signing out: $e');
      rethrow;
    }
  }

  /// Check if user session is still valid
  static Future<bool> isSessionValid() async {
    try {
      if (!isLoggedIn) {
        return false;
      }

      final session = _client.auth.currentSession;
      if (session == null) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error checking session validity: $e');
      return false;
    }
  }

  // ==================== USER PROFILE OPERATIONS ====================

  /// Get user profile from user_profiles table
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      debugPrint('📍 Fetching profile for user: $userId');

      final response = await _client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        debugPrint('✅ Profile found');
      } else {
        debugPrint('⚠️ Profile not found');
      }

      return response;
    } catch (e) {
      debugPrint('❌ Error fetching profile: $e');
      return null;
    }
  }

  /// Get current user's profile
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('⚠️ No user logged in');
      return null;
    }
    return getUserProfile(userId);
  }

  /// Create new user profile
  static Future<Map<String, dynamic>> createUserProfile({
    required String userId,
    required String email,
    required String fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    try {
      debugPrint('📝 Creating user profile for: $userId');

      final profile = {
        'id': userId,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'avatar_url': avatarUrl,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('user_profiles')
          .insert(profile)
          .select()
          .single();

      debugPrint('✅ Profile created successfully');
      return response;
    } catch (e) {
      debugPrint('❌ Error creating profile: $e');
      rethrow;
    }
  }

  /// Update user profile
  static Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('📝 Updating profile for user: $userId');

      // Add updated_at timestamp
      data['updated_at'] = DateTime.now().toIso8601String();

      await _client
          .from('user_profiles')
          .update(data)
          .eq('id', userId);

      debugPrint('✅ Profile updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      rethrow;
    }
  }

  /// Update current user's profile
  static Future<void> updateCurrentUserProfile(
    Map<String, dynamic> data,
  ) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('No user logged in');
    }
    return updateUserProfile(userId, data);
  }

  /// Delete user profile
  static Future<void> deleteUserProfile(String userId) async {
    try {
      debugPrint('🗑️ Deleting profile for user: $userId');

      await _client
          .from('user_profiles')
          .delete()
          .eq('id', userId);

      debugPrint('✅ Profile deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting profile: $e');
      rethrow;
    }
  }

  // ==================== DATABASE OPERATIONS ====================

  /// Generic select query
  static Future<List<Map<String, dynamic>>> select(
    String table, {
    String? columns,
  }) async {
    try {
      final query = _client.from(table).select(columns ?? '*');
      final response = await query;
      return response.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Error selecting from $table: $e');
      rethrow;
    }
  }

  /// Generic insert operation
  static Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _client
          .from(table)
          .insert(data)
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('❌ Error inserting into $table: $e');
      rethrow;
    }
  }

  /// Generic update operation
  static Future<void> update(
    String table,
    String columnId,
    String valueId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _client
          .from(table)
          .update(data)
          .eq(columnId, valueId);
    } catch (e) {
      debugPrint('❌ Error updating $table: $e');
      rethrow;
    }
  }

  /// Generic delete operation
  static Future<void> delete(
    String table,
    String columnId,
    String valueId,
  ) async {
    try {
      await _client
          .from(table)
          .delete()
          .eq(columnId, valueId);
    } catch (e) {
      debugPrint('❌ Error deleting from $table: $e');
      rethrow;
    }
  }

  // ==================== STREAMS ====================

  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges {
    try {
      return _client.auth.onAuthStateChange;
    } catch (e) {
      debugPrint('❌ Error getting auth state changes: $e');
      return const Stream.empty();
    }
  }

  /// Listen to user changes
  static Stream<User?> get userChanges {
    return authStateChanges.map((event) => event.session?.user).distinct();
  }

  // ==================== ERROR HANDLING ====================

  /// Handle Supabase errors gracefully
  static String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    }
    if (error is AuthException) {
      return error.message;
    }
    return error.toString();
  }

  // ==================== DEBUG UTILITIES ====================

  /// Print debug info
  static void printDebugInfo() {
    debugPrint('=== Supabase Debug Info ===');
    debugPrint('Initialized: $_isInitialized');
    debugPrint('Logged In: $isLoggedIn');
    debugPrint('Has Valid Session: $hasValidSession');
    debugPrint('User ID: $currentUserId');
    debugPrint('User Email: $currentUserEmail');
    debugPrint('User Phone: $currentUserPhone');
    debugPrint('Session Expires At: ${currentSession?.expiresAt}');
    debugPrint('=========================');
  }

  /// Reset (for testing only - be careful!)
  static Future<void> reset() async {
    try {
      await signOut();
      _client = Supabase.instance.client;
      debugPrint('✅ Supabase reset');
    } catch (e) {
      debugPrint('❌ Error resetting Supabase: $e');
    }
  }
}