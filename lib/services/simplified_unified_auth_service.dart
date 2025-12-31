import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import '../config/supabase_config.dart';
import 'session_manager.dart';
import 'textlk_sms_service.dart';

/// Unified Auth Service with Native Google Sign-In + Text.lk SMS
/// - Google/Apple/Email auth: unchanged (uses Supabase)
/// - Phone auth: now uses Text.lk SMS Gateway
class SimplifiedUnifiedAuthService {
  static final SimplifiedUnifiedAuthService _instance =
      SimplifiedUnifiedAuthService._internal();

  factory SimplifiedUnifiedAuthService() {
    return _instance;
  }

  SimplifiedUnifiedAuthService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final SessionManager _sessionManager = SessionManager();
  final TextLkSmsService _smsService = TextLkSmsService();
  
  // ✅ Native Google Sign-In configuration
  static const String _googleWebClientId = 
      '187097738490-9ovt2i9c26tvgq187k6g08srr49fc1qk.apps.googleusercontent.com';
  
  static const String _googleIOSClientId = 
      '187097738490-XXXXXXXXXXXXXXXXXXXXXXXXXXXX.apps.googleusercontent.com';
  
  late final GoogleSignIn _googleSignIn;

  // Expose SMS service for UI formatting
  TextLkSmsService get smsService => _smsService;

  /// Initialize the auth service (call this in main.dart after Supabase init)
  Future<void> initialize() async {
    debugPrint('🔐 Initializing Auth Service...');
    
    _googleSignIn = GoogleSignIn(
      serverClientId: _googleWebClientId,
      scopes: ['email', 'profile'],
    );
    
    debugPrint('✅ Auth Service initialized');
  }

  void dispose() {}

  // ==================== SIGN IN - PHONE (Text.lk) ====================

  /// SIGN IN - Phone (Step 1: Send OTP via Text.lk)
  Future<Map<String, dynamic>> sendSignInOTP(String phoneNumber) async {
    try {
      debugPrint('📱 [SIGN IN] Sending OTP to: $phoneNumber');

      final formattedPhone = _smsService.formatPhoneNumber(phoneNumber);

      // Check if phone is registered (check both formats)
      var existingUser = await _supabase
          .from('user_profiles')
          .select()
          .eq('phone', formattedPhone)
          .maybeSingle();

      existingUser ??= await _supabase
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

      // Send OTP via Text.lk
      final result = await _smsService.sendOtp(
        phoneNumber: phoneNumber,
        purpose: 'signin',
      );

      return result;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {'success': false, 'message': 'Failed to send OTP: $e'};
    }
  }

  /// SIGN IN - Phone (Step 2: Verify OTP via Text.lk)
  Future<Map<String, dynamic>> verifySignInOTP(
    String phoneNumber,
    String otp,
  ) async {
    try {
      debugPrint('🔐 [SIGN IN] Verifying OTP');

      // Verify OTP via Text.lk service
      final verifyResult = await _smsService.verifyOtp(
        phoneNumber: phoneNumber,
        otpCode: otp,
      );

      if (!verifyResult['success']) {
        return verifyResult;
      }

      // OTP verified - get user profile
      final formattedPhone = _smsService.formatPhoneNumber(phoneNumber);
      
      var profile = await _supabase
          .from('user_profiles')
          .select()
          .eq('phone', formattedPhone)
          .maybeSingle();
      
      profile ??= await _supabase
          .from('user_profiles')
          .select()
          .eq('phone', phoneNumber)
          .maybeSingle();

      if (profile == null) {
        return {
          'success': false,
          'message': 'User profile not found',
        };
      }

      // Save session for phone auth
      await _sessionManager.savePhoneSession(
        userId: profile['id'],
        phone: formattedPhone,
      );

      debugPrint('✅ OTP verified - SIGN IN SUCCESS');
      return {
        'success': true,
        'message': 'Signed in successfully',
        'profile': profile,
        'userId': profile['id'],
      };
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {'success': false, 'message': 'Failed to verify OTP: $e'};
    }
  }

  /// Resend Sign In OTP
  Future<Map<String, dynamic>> resendSignInOTP(String phoneNumber) async {
    return _smsService.resendOtp(phoneNumber: phoneNumber, purpose: 'signin');
  }

  // ==================== SIGN UP - PHONE (Text.lk) ====================

  /// SIGN UP - Phone (Step 1: Send OTP via Text.lk)
  Future<Map<String, dynamic>> sendSignUpOTP(String phoneNumber) async {
    try {
      debugPrint('📱 [SIGN UP] Sending OTP to: $phoneNumber');

      final formattedPhone = _smsService.formatPhoneNumber(phoneNumber);

      // Check if phone already registered
      var existingUser = await _supabase
          .from('user_profiles')
          .select()
          .eq('phone', formattedPhone)
          .maybeSingle();

      existingUser ??= await _supabase
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

      // Send OTP via Text.lk
      final result = await _smsService.sendOtp(
        phoneNumber: phoneNumber,
        purpose: 'signup',
      );

      return result;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {'success': false, 'message': 'Failed to send OTP: $e'};
    }
  }

  /// SIGN UP - Phone (Step 2: Verify OTP + Save basic info)
  /// This is the ORIGINAL method signature - kept for backward compatibility
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

      // Verify OTP via Text.lk
      final verifyResult = await _smsService.verifyOtp(
        phoneNumber: phoneNumber,
        otpCode: otp,
      );

      if (!verifyResult['success']) {
        return verifyResult;
      }

      // Create user ID (since we're not using Supabase Auth for phone)
      final userId = DateTime.now().millisecondsSinceEpoch.toString() + 
                    _smsService.formatPhoneNumber(phoneNumber).substring(2);

      final formattedPhone = _smsService.formatPhoneNumber(phoneNumber);

      final profile = {
        'id': userId,
        'phone': formattedPhone,
        'email': email,
        'full_name': fullName,
        'display_name': fullName,
        'avatar_url': photoUrl,
        'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
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

      await _sessionManager.savePhoneSession(
        userId: userId,
        phone: formattedPhone,
      );

      debugPrint('✅ SIGN UP SUCCESS');
      return {
        'success': true,
        'message': 'Account created successfully',
        'profile': profile,
        'userId': userId,
      };
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {'success': false, 'message': 'Sign up failed: $e'};
    }
  }

  /// Resend Sign Up OTP
  Future<Map<String, dynamic>> resendSignUpOTP(String phoneNumber) async {
    return _smsService.resendOtp(phoneNumber: phoneNumber, purpose: 'signup');
  }

  

  /// Create Phone User Profile (called AFTER OTP is already verified)
  /// This method does NOT re-verify OTP - use when phoneVerified: true is passed
  Future<Map<String, dynamic>> createPhoneUserProfile({
    required String phoneNumber,
    required String fullName,
    required String email,
    required DateTime dateOfBirth,
    String? gender,
    String? photoUrl,
  }) async {
    try {
      debugPrint('📝 [SIGN UP] Creating profile for verified phone user');

      final formattedPhone = _smsService.formatPhoneNumber(phoneNumber);

      // Check if phone already exists
      var existingUser = await _supabase
          .from('user_profiles')
          .select()
          .eq('phone', formattedPhone)
          .maybeSingle();

      if (existingUser != null) {
        return {
          'success': false,
          'message': 'Phone already registered',
          'accountExists': true,
        };
      }

      // Generate user ID for phone auth (no Supabase Auth user)
      final userId = 'phone_${DateTime.now().millisecondsSinceEpoch}_${formattedPhone.substring(2, 7)}';

      final profile = {
        'id': userId,
        'phone': formattedPhone,
        'email': email.isNotEmpty ? email : null,
        'full_name': fullName,
        'display_name': fullName,
        'avatar_url': photoUrl,
        'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
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

      // Save phone session
      await _sessionManager.savePhoneSession(
        userId: userId,
        phone: formattedPhone,
      );

      debugPrint('✅ Phone user profile created successfully');
      return {
        'success': true,
        'message': 'Account created successfully',
        'profile': profile,
        'userId': userId,
      };
    } catch (e) {
      debugPrint('❌ Error creating phone profile: $e');
      return {'success': false, 'message': 'Failed to create account: $e'};
    }
  }

  // ==================== SIGN IN - EMAIL (UNCHANGED) ====================

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

  // ==================== SIGN UP - EMAIL (UNCHANGED) ====================

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

  // ==================== NATIVE GOOGLE SIGN-IN (UNCHANGED) ====================
  
  /// ✅ NATIVE Google Sign-In - Best UX!
  Future<Map<String, dynamic>> signUpWithGoogle(BuildContext context) async {
    try {
      debugPrint('🔍 [GOOGLE] Starting native Google Sign-In...');

      _showLoadingDialog(context, 'Signing in with Google...');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _hideLoadingDialog(context);
        debugPrint('❌ User cancelled Google Sign-In');
        return {
          'success': false,
          'message': 'Sign in cancelled',
        };
      }

      debugPrint('✅ Google account selected: ${googleUser.email}');

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

        await _sessionManager.saveSession(response.user!, response.session);

        final existingProfile = await _supabase
            .from('user_profiles')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        if (existingProfile == null) {
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

  void _hideLoadingDialog(BuildContext context) {
    if (context.mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }
  }

  // ==================== SIGN UP - APPLE (UNCHANGED) ====================

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

  // ==================== COMMON METHODS (UNCHANGED) ====================

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
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