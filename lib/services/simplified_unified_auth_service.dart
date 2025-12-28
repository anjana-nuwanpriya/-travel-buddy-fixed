import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import '../config/supabase_config.dart';
import 'session_manager.dart';

/// Unified Auth Service with Native Google Sign-In
/// Provides the best UX for mobile apps - native account picker, no browser redirect
class SimplifiedUnifiedAuthService {
  static final SimplifiedUnifiedAuthService _instance =
      SimplifiedUnifiedAuthService._internal();

  factory SimplifiedUnifiedAuthService() {
    return _instance;
  }

  SimplifiedUnifiedAuthService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final SessionManager _sessionManager = SessionManager();
  
  // ✅ Native Google Sign-In configuration
  // Use your Web Client ID from Google Cloud Console
  // (NOT the Android client ID - use the Web one for Supabase)
  static const String _googleWebClientId = 
      '187097738490-9ovt2i9c26tvgq187k6g08srr49fc1qk.apps.googleusercontent.com';
  
  // For iOS, you also need the iOS client ID
  static const String _googleIOSClientId = 
      '187097738490-XXXXXXXXXXXXXXXXXXXXXXXXXXXX.apps.googleusercontent.com'; // Replace with your iOS client ID
  
  late final GoogleSignIn _googleSignIn;

  /// Initialize the auth service (call this in main.dart after Supabase init)
  Future<void> initialize() async {
    debugPrint('🔐 Initializing Auth Service...');
    
    // Initialize Google Sign-In
    _googleSignIn = GoogleSignIn(
      // Use web client ID for server auth code
      serverClientId: _googleWebClientId,
      scopes: [
        'email',
        'profile',
      ],
    );
    
    debugPrint('✅ Auth Service initialized');
  }

  /// Dispose resources
  void dispose() {
    // No cleanup needed for native Google Sign-In
  }

  // ==================== SIGN IN - PHONE ====================

  /// SIGN IN - Phone (Step 1: Send OTP)
  Future<Map<String, dynamic>> sendSignInOTP(String phoneNumber) async {
    try {
      debugPrint('📱 [SIGN IN] Sending OTP to: $phoneNumber');

      final existingUser = await _supabase
          .from('user_profiles')
          .select()
          .eq('phone', phoneNumber)
          .maybeSingle();

      if (existingUser == null) {
        debugPrint('❌ Phone not found');
        return {
          'success': false,
          'message': 'Phone not registered. Please create an account.',
          'accountNotFound': true,
        };
      }

      await _supabase.auth.signInWithOtp(
        phone: phoneNumber,
        shouldCreateUser: false,
      );

      debugPrint('✅ OTP sent');
      return {
        'success': true,
        'message': 'OTP sent successfully',
        'phoneNumber': phoneNumber,
      };
    } on AuthException catch (e) {
      debugPrint('❌ Auth Error: ${e.message}');
      return {'success': false, 'message': e.message};
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {'success': false, 'message': 'Failed to send OTP: $e'};
    }
  }

  /// SIGN IN - Phone (Step 2: Verify OTP)
  Future<Map<String, dynamic>> verifySignInOTP(
    String phoneNumber,
    String otp,
  ) async {
    try {
      debugPrint('🔐 [SIGN IN] Verifying OTP');

      final response = await _supabase.auth.verifyOTP(
        phone: phoneNumber,
        token: otp,
        type: OtpType.sms,
      );

      if (response.user != null) {
        debugPrint('✅ OTP verified - SIGN IN SUCCESS');

        final profile = await _supabase
            .from('user_profiles')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        await _sessionManager.saveSession(response.user!, response.session);

        return {
          'success': true,
          'message': 'Signed in successfully',
          'user': response.user,
          'profile': profile,
          'session': response.session,
        };
      } else {
        return {'success': false, 'message': 'Invalid OTP'};
      }
    } on AuthException catch (e) {
      debugPrint('❌ Auth Error: ${e.message}');
      return {'success': false, 'message': e.message};
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {'success': false, 'message': 'Failed to verify OTP: $e'};
    }
  }

  // ==================== SIGN IN - EMAIL ====================

  /// SIGN IN - Email & Password
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('📧 [SIGN IN] Email: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('✅ Signed in with email');

        final profile = await _supabase
            .from('user_profiles')
            .select()
            .eq('id', response.user!.id)
            .single();

        await _sessionManager.saveSession(response.user!, response.session);

        return {
          'success': true,
          'message': 'Signed in successfully',
          'user': response.user,
          'profile': profile,
          'session': response.session,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to sign in',
        };
      }
    } on AuthException catch (e) {
      debugPrint('❌ Auth Error: ${e.message}');

      if (e.message.contains('Invalid login credentials')) {
        return {
          'success': false,
          'message': 'Incorrect email or password',
        };
      }
      if (e.message.contains('Email not confirmed')) {
        return {
          'success': false,
          'message': 'Please verify your email first',
        };
      }

      return {'success': false, 'message': e.message};
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {'success': false, 'message': 'Sign in failed: $e'};
    }
  }

  // ==================== SIGN UP - PHONE ====================

  /// SIGN UP - Phone (Step 1: Send OTP)
  Future<Map<String, dynamic>> sendSignUpOTP(String phoneNumber) async {
    try {
      debugPrint('📱 [SIGN UP] Sending OTP to: $phoneNumber');

      final existingUser = await _supabase
          .from('user_profiles')
          .select()
          .eq('phone', phoneNumber)
          .maybeSingle();

      if (existingUser != null) {
        debugPrint('❌ Phone already registered');
        return {
          'success': false,
          'message': 'Phone already registered. Please sign in instead.',
          'accountExists': true,
        };
      }

      await _supabase.auth.signInWithOtp(
        phone: phoneNumber,
        shouldCreateUser: true,
      );

      debugPrint('✅ OTP sent');
      return {
        'success': true,
        'message': 'OTP sent successfully',
        'phoneNumber': phoneNumber,
      };
    } on AuthException catch (e) {
      debugPrint('❌ Auth Error: ${e.message}');
      return {'success': false, 'message': e.message};
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {'success': false, 'message': 'Failed to send OTP: $e'};
    }
  }

  /// SIGN UP - Phone (Step 2: Verify OTP + Save basic info)
  Future<Map<String, dynamic>> verifySignUpOTPAndCreateProfile({
    required String phoneNumber,
    required String otp,
    required String fullName,
    required String email,
    required DateTime dateOfBirth,
    String? gender,
    String? photoUrl,
  }) async {
    try {
      debugPrint('🔐 [SIGN UP] Verifying OTP and creating profile');

      final response = await _supabase.auth.verifyOTP(
        phone: phoneNumber,
        token: otp,
        type: OtpType.sms,
      );

      if (response.user == null) {
        return {'success': false, 'message': 'Invalid OTP'};
      }

      final profile = {
        'id': response.user!.id,
        'phone': phoneNumber,
        'email': email,
        'full_name': fullName,
        'display_name': fullName,
        'avatar_url': photoUrl,
        'date_of_birth': dateOfBirth.toIso8601String(),
        'gender': gender,
        'auth_method': 'phone',
        'phone_verified': true,
        'email_verified': false,
        'profile_completed': false,
        'signup_completed_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('user_profiles').insert(profile);

      await _sessionManager.saveSession(response.user!, response.session);

      debugPrint('✅ SIGN UP SUCCESS');
      return {
        'success': true,
        'message': 'Account created successfully',
        'user': response.user,
        'profile': profile,
        'session': response.session,
      };
    } on AuthException catch (e) {
      debugPrint('❌ Auth Error: ${e.message}');
      return {'success': false, 'message': e.message};
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {'success': false, 'message': 'Sign up failed: $e'};
    }
  }

  // ==================== SIGN UP - EMAIL ====================

  /// SIGN UP - Email (Step 1: Create account)
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('📧 [SIGN UP] Email: $email');

      final existing = await _supabase
          .from('user_profiles')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (existing != null) {
        debugPrint('❌ Email already registered');
        return {
          'success': false,
          'message': 'Email already registered. Please sign in instead.',
          'accountExists': true,
        };
      }

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('✅ Email signup successful');

        return {
          'success': true,
          'message': 'Verification email sent. Please check your inbox.',
          'user': response.user,
          'session': response.session,
          'email': email,
        };
      } else {
        return {'success': false, 'message': 'Failed to create account'};
      }
    } on AuthException catch (e) {
      debugPrint('❌ Auth Error: ${e.message}');

      if (e.message.contains('already registered')) {
        return {
          'success': false,
          'message': 'Email already registered. Please sign in instead.',
          'accountExists': true,
        };
      }

      return {'success': false, 'message': e.message};
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {'success': false, 'message': 'Sign up failed: $e'};
    }
  }

  /// SIGN UP - Email (Step 2: Complete profile after verification)
  Future<Map<String, dynamic>> completeEmailSignUp({
    required String email,
    required String fullName,
    required String phoneNumber,
    required DateTime dateOfBirth,
    String? gender,
    String? photoUrl,
  }) async {
    try {
      debugPrint('📝 [SIGN UP] Creating profile for email signup');

      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No authenticated user'};
      }

      final profile = {
        'id': user.id,
        'email': email,
        'phone': phoneNumber,
        'full_name': fullName,
        'display_name': fullName,
        'avatar_url': photoUrl,
        'date_of_birth': dateOfBirth.toIso8601String(),
        'gender': gender,
        'auth_method': 'email',
        'phone_verified': false,
        'email_verified': true,
        'profile_completed': false,
        'signup_completed_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('user_profiles').insert(profile);

      debugPrint('✅ Profile created');
      return {
        'success': true,
        'message': 'Account created successfully',
        'user': user,
        'profile': profile,
      };
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {'success': false, 'message': 'Failed to create profile: $e'};
    }
  }

  // ==================== NATIVE GOOGLE SIGN-IN ====================
  
  /// ✅ NATIVE Google Sign-In - Best UX!
  /// Shows the native Google account picker (same as YouTube, Gmail, etc.)
  /// No browser redirect, seamless experience
  Future<Map<String, dynamic>> signUpWithGoogle(BuildContext context) async {
    try {
      debugPrint('🔍 [GOOGLE] Starting native Google Sign-In...');

      // Show loading indicator
      _showLoadingDialog(context, 'Signing in with Google...');

      // Trigger native Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        _hideLoadingDialog(context);
        debugPrint('❌ User cancelled Google Sign-In');
        return {
          'success': false,
          'message': 'Sign in cancelled',
        };
      }

      debugPrint('✅ Google account selected: ${googleUser.email}');

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      debugPrint('📍 ID Token: ${idToken != null ? "Present" : "Missing"}');
      debugPrint('📍 Access Token: ${accessToken != null ? "Present" : "Missing"}');

      if (idToken == null) {
        _hideLoadingDialog(context);
        debugPrint('❌ No ID token received from Google');
        return {
          'success': false,
          'message': 'Failed to get authentication token from Google',
        };
      }

      // Sign in to Supabase with the Google ID token
      debugPrint('📍 Signing in to Supabase with Google ID token...');
      
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      _hideLoadingDialog(context);

      if (response.user != null) {
        debugPrint('✅ Supabase authentication successful!');
        debugPrint('📍 User ID: ${response.user!.id}');
        debugPrint('📍 Email: ${response.user!.email}');

        // Save session
        await _sessionManager.saveSession(response.user!, response.session);

        // Check if profile exists
        final existingProfile = await _supabase
            .from('user_profiles')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        if (existingProfile == null) {
          // Create new profile
          final profile = {
            'id': response.user!.id,
            'email': response.user!.email ?? googleUser.email,
            'full_name': googleUser.displayName ?? 
                        response.user!.userMetadata?['full_name'] ?? 
                        response.user!.userMetadata?['name'] ?? 'User',
            'display_name': googleUser.displayName ?? 
                           response.user!.userMetadata?['full_name'] ?? 
                           response.user!.userMetadata?['name'] ?? 'User',
            'avatar_url': googleUser.photoUrl ?? 
                         response.user!.userMetadata?['avatar_url'] ?? 
                         response.user!.userMetadata?['picture'],
            'auth_method': 'google',
            'email_verified': true,
            'phone_verified': false,
            'profile_completed': false,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          await _supabase.from('user_profiles').insert(profile);
          debugPrint('✅ New profile created');

          return {
            'success': true,
            'message': 'Account created successfully!',
            'user': response.user,
            'profile': profile,
            'session': response.session,
            'requiresBasicInfo': true,
            'googleName': googleUser.displayName,
            'googleEmail': googleUser.email,
            'googlePhoto': googleUser.photoUrl,
          };
        } else {
          debugPrint('✅ Existing profile found');

          return {
            'success': true,
            'message': 'Signed in successfully!',
            'user': response.user,
            'profile': existingProfile,
            'session': response.session,
          };
        }
      } else {
        debugPrint('❌ Supabase authentication failed');
        return {
          'success': false,
          'message': 'Authentication failed',
        };
      }
    } on AuthException catch (e) {
      _hideLoadingDialog(context);
      debugPrint('❌ Auth Error: ${e.message}');
      return {
        'success': false,
        'message': 'Google sign-in failed: ${e.message}',
      };
    } catch (e) {
      _hideLoadingDialog(context);
      debugPrint('❌ Error: $e');
      return {
        'success': false,
        'message': 'Google sign-in failed: $e',
      };
    }
  }

  /// Show loading dialog
  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  /// Hide loading dialog
  void _hideLoadingDialog(BuildContext context) {
    if (context.mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }
  }

  // ==================== SIGN UP - APPLE ====================

  Future<Map<String, dynamic>> signUpWithApple() async {
    try {
      debugPrint('🍎 [APPLE] Starting Apple OAuth');

      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        return {
          'success': false,
          'message': 'Apple Sign-In is not available on this device',
        };
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      debugPrint('✅ Apple authentication successful');

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
      );

      if (response.user != null) {
        debugPrint('✅ Supabase authentication successful');

        final existing = await _supabase
            .from('user_profiles')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        String fullName = '';
        if (credential.givenName != null || credential.familyName != null) {
          fullName =
              '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
                  .trim();
        }

        if (existing == null) {
          final profile = {
            'id': response.user!.id,
            'email': credential.email,
            'full_name': fullName,
            'display_name': fullName,
            'auth_method': 'apple',
            'email_verified': true,
            'phone_verified': false,
            'profile_completed': false,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          await _supabase.from('user_profiles').insert(profile);

          return {
            'success': true,
            'message': 'Apple account created. Please complete basic info.',
            'user': response.user,
            'profile': profile,
            'requiresBasicInfo': true,
            'session': response.session,
            'appleName': fullName,
            'appleEmail': credential.email,
          };
        } else {
          await _sessionManager.saveSession(response.user!, response.session);

          return {
            'success': true,
            'message': 'Signed in with Apple successfully',
            'user': response.user,
            'profile': existing,
            'session': response.session,
          };
        }
      } else {
        return {'success': false, 'message': 'Failed to authenticate'};
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('❌ Apple Auth Error: ${e.code} - ${e.message}');
      return {'success': false, 'message': 'Apple sign-in cancelled'};
    } on AuthException catch (e) {
      debugPrint('❌ Auth Error: ${e.message}');
      return {'success': false, 'message': 'Apple sign-in failed: ${e.message}'};
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {'success': false, 'message': 'Apple sign-in failed: $e'};
    }
  }

  // ==================== COMMON METHODS ====================

  Future<void> signOut() async {
    try {
      // Sign out from Google
      await _googleSignIn.signOut();
      
      // Sign out from Supabase
      await _supabase.auth.signOut();
      await _sessionManager.clearSession();
      
      debugPrint('✅ User signed out successfully');
    } catch (e) {
      debugPrint('❌ Error signing out: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      return await _supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('❌ Error fetching profile: $e');
      return null;
    }
  }

  bool isLoggedIn() => _supabase.auth.currentUser != null;

  User? get currentUser => _supabase.auth.currentUser;

  Session? get currentSession => _supabase.auth.currentSession;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}