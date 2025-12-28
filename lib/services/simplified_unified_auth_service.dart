import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'dart:convert';
import '../config/supabase_config.dart';
import 'session_manager.dart';

/// Simplified Unified Auth Service - with External Browser OAuth
/// Uses system browser for Google OAuth (complies with Google's secure browser policy)
class SimplifiedUnifiedAuthService {
  static final SimplifiedUnifiedAuthService _instance =
      SimplifiedUnifiedAuthService._internal();

  factory SimplifiedUnifiedAuthService() {
    return _instance;
  }

  SimplifiedUnifiedAuthService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final SessionManager _sessionManager = SessionManager();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Deep link handling
  StreamSubscription? _linkSubscription;
  Completer<Map<String, dynamic>>? _authCompleter;
  
  // Redirect URL for OAuth
  static const String _redirectScheme = 'com.anjana.travelbuddy';
  static const String _redirectUrl = '$_redirectScheme://login-callback';
  
  // Storage keys for OAuth tokens
  static const String _accessTokenKey = 'oauth_access_token';
  static const String _refreshTokenKey = 'oauth_refresh_token';

  /// Initialize the auth service (call this in main.dart after Supabase init)
  Future<void> initialize() async {
    debugPrint('🔐 Initializing Auth Service...');
    _setupDeepLinkListener();
  }

  /// Setup deep link listener for OAuth callbacks
  void _setupDeepLinkListener() {
    final appLinks = AppLinks();
    
    // Handle initial link (if app was opened via deep link)
    appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null && uri.scheme == _redirectScheme) {
        debugPrint('🔗 Initial deep link: $uri');
        _handleOAuthCallback(uri);
      }
    });
    
    // Listen for incoming links
    _linkSubscription = appLinks.uriLinkStream.listen((Uri uri) {
      debugPrint('🔗 Received deep link: $uri');
      if (uri.scheme == _redirectScheme) {
        _handleOAuthCallback(uri);
      }
    });
  }

  /// Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
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

  // ==================== SIGN UP - GOOGLE (EXTERNAL BROWSER) ====================

  /// Google OAuth using External Browser
  Future<Map<String, dynamic>> signUpWithGoogle(BuildContext context) async {
    try {
      debugPrint('🔍 [GOOGLE OAUTH] Starting external browser OAuth');

      // Create a completer to wait for the callback
      _authCompleter = Completer<Map<String, dynamic>>();

      // Build the Supabase OAuth URL
      final authUrl = '${SupabaseConfig.supabaseUrl}/auth/v1/authorize'
          '?provider=google'
          '&redirect_to=${Uri.encodeComponent(_redirectUrl)}';

      debugPrint('📍 Auth URL: $authUrl');

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              _authCompleter?.complete({
                'success': false,
                'message': 'Sign in cancelled',
              });
              Navigator.of(ctx).pop();
            }
          },
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Opening browser for sign in...'),
                const SizedBox(height: 8),
                Text(
                  'Complete sign in in your browser',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _authCompleter?.complete({
                      'success': false,
                      'message': 'Sign in cancelled',
                    });
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      );

      // Open in external browser
      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        Navigator.pop(context); // Close dialog
        return {
          'success': false,
          'message': 'Could not open browser for authentication',
        };
      }

      // Wait for the deep link callback (with timeout)
      final result = await _authCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          return {
            'success': false,
            'message': 'Authentication timed out',
          };
        },
      );

      // Close the dialog if still showing
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }

      return result;
    } on AuthException catch (e) {
      debugPrint('❌ Auth Error: ${e.message}');
      return {
        'success': false,
        'message': 'Google sign-in failed: ${e.message}',
      };
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {
        'success': false,
        'message': 'Google sign-in failed: $e',
      };
    }
  }

  /// Handle OAuth callback from deep link
  Future<void> _handleOAuthCallback(Uri uri) async {
    debugPrint('🔍 Handling OAuth callback: $uri');

    try {
      String? accessToken;
      String? refreshToken;
      String? expiresIn;
      String? expiresAt;
      String? tokenType;
      String? error;
      String? errorDescription;
      
      // Check query parameters first (code flow)
      final code = uri.queryParameters['code'];
      error = uri.queryParameters['error'];
      errorDescription = uri.queryParameters['error_description'];
      
      // Parse URL fragment (implicit flow)
      if (uri.hasFragment && uri.fragment.isNotEmpty) {
        debugPrint('📍 Found URL fragment');
        
        final fragmentParams = Uri.splitQueryString(uri.fragment);
        
        accessToken = fragmentParams['access_token'];
        refreshToken = fragmentParams['refresh_token'];
        expiresIn = fragmentParams['expires_in'];
        expiresAt = fragmentParams['expires_at'];
        tokenType = fragmentParams['token_type'] ?? 'bearer';
        error = error ?? fragmentParams['error'];
        errorDescription = errorDescription ?? fragmentParams['error_description'];
        
        debugPrint('📍 Access token: ${accessToken != null ? "Yes (${accessToken.length} chars)" : "No"}');
        debugPrint('📍 Refresh token: ${refreshToken != null ? "Yes" : "No"}');
        debugPrint('📍 Expires in: $expiresIn');
      }
      
      // Handle implicit flow tokens
      if (accessToken != null && refreshToken != null) {
        debugPrint('✅ Both tokens received (implicit flow)');
        
        try {
          // Decode the JWT to get user info
          final parts = accessToken.split('.');
          if (parts.length != 3) {
            throw Exception('Invalid JWT format');
          }
          
          // Decode the payload (second part of JWT)
          String payload = parts[1];
          // Add padding if needed for base64
          while (payload.length % 4 != 0) {
            payload += '=';
          }
          final normalized = base64Url.normalize(payload);
          final decoded = utf8.decode(base64Url.decode(normalized));
          final jwtPayload = jsonDecode(decoded) as Map<String, dynamic>;
          
          debugPrint('📍 JWT Payload decoded successfully');
          debugPrint('📍 User ID: ${jwtPayload['sub']}');
          debugPrint('📍 Email: ${jwtPayload['email']}');
          
          // Get user metadata from JWT
          final userMetadata = jwtPayload['user_metadata'] as Map<String, dynamic>? ?? {};
          final appMetadata = jwtPayload['app_metadata'] as Map<String, dynamic>? ?? {};
          final email = jwtPayload['email'] as String?;
          final userId = jwtPayload['sub'] as String;
          
          // Create the session JSON that Supabase expects
          final expiresAtInt = int.tryParse(expiresAt ?? '') ?? 
              (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600);
          
          final sessionJson = jsonEncode({
            'access_token': accessToken,
            'refresh_token': refreshToken,
            'token_type': tokenType,
            'expires_in': int.tryParse(expiresIn ?? '3600') ?? 3600,
            'expires_at': expiresAtInt,
            'user': {
              'id': userId,
              'email': email,
              'phone': jwtPayload['phone'] ?? '',
              'user_metadata': userMetadata,
              'app_metadata': appMetadata,
              'aud': jwtPayload['aud'] ?? 'authenticated',
              'role': jwtPayload['role'] ?? 'authenticated',
              'email_confirmed_at': DateTime.now().toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            }
          });
          
          debugPrint('📍 Attempting to recover session...');
          
          // Try to recover the session
          final response = await _supabase.auth.recoverSession(sessionJson);
          
          if (response.user != null && response.session != null) {
            debugPrint('✅ Session recovered successfully!');
            debugPrint('📍 User: ${response.user!.email}');
            
            // Save session using your SessionManager
            await _sessionManager.saveSession(response.user!, response.session);
            
            await _handleSuccessfulAuth(response.user!);
            return;
          } else {
            debugPrint('❌ recoverSession returned null user/session');
          }
        } catch (e) {
          debugPrint('❌ Error recovering session: $e');
          
          // Fallback: Manually handle auth with decoded JWT data
          try {
            debugPrint('📍 Trying fallback: manual profile handling...');
            
            // Decode JWT again
            final parts = accessToken.split('.');
            String payload = parts[1];
            while (payload.length % 4 != 0) {
              payload += '=';
            }
            final decoded = utf8.decode(base64Url.decode(base64Url.normalize(payload)));
            final jwtPayload = jsonDecode(decoded) as Map<String, dynamic>;
            
            final userId = jwtPayload['sub'] as String;
            final email = jwtPayload['email'] as String?;
            final userMetadata = jwtPayload['user_metadata'] as Map<String, dynamic>? ?? {};
            
            // Store tokens in secure storage for session persistence
            await _secureStorage.write(key: _accessTokenKey, value: accessToken);
            await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
            await _secureStorage.write(key: 'travel_buddy_user_id', value: userId);
            await _secureStorage.write(key: 'travel_buddy_email', value: email ?? '');
            await _secureStorage.write(key: 'travel_buddy_session', value: accessToken);
            
            debugPrint('✅ Tokens saved to secure storage');
            
            // Check if profile exists
            final existing = await _supabase
                .from('user_profiles')
                .select()
                .eq('id', userId)
                .maybeSingle();

            if (existing == null) {
              // Create basic profile from OAuth data
              final profile = {
                'id': userId,
                'email': email,
                'full_name': userMetadata['full_name'] ?? userMetadata['name'] ?? 'User',
                'display_name': userMetadata['full_name'] ?? userMetadata['name'] ?? 'User',
                'avatar_url': userMetadata['avatar_url'] ?? userMetadata['picture'],
                'auth_method': 'google',
                'email_verified': true,
                'phone_verified': false,
                'profile_completed': false,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              };

              await _supabase.from('user_profiles').insert(profile);
              debugPrint('✅ Profile created from Google OAuth');

              _authCompleter?.complete({
                'success': true,
                'message': 'Google account created successfully!',
                'userId': userId,
                'profile': profile,
                'requiresBasicInfo': true,
                'googleName': userMetadata['full_name'] ?? userMetadata['name'],
                'googleEmail': email,
                'googlePhoto': userMetadata['avatar_url'] ?? userMetadata['picture'],
              });
            } else {
              debugPrint('✅ Existing profile found');
              
              _authCompleter?.complete({
                'success': true,
                'message': 'Signed in with Google successfully!',
                'userId': userId,
                'profile': existing,
              });
            }
            return;
          } catch (fallbackError) {
            debugPrint('❌ Fallback also failed: $fallbackError');
          }
        }
      }
      
      // Handle code flow
      if (code != null && code.isNotEmpty) {
        debugPrint('✅ Auth code received (code flow)');
        
        try {
          await _supabase.auth.exchangeCodeForSession(code);
          
          final user = _supabase.auth.currentUser;
          if (user != null) {
            debugPrint('✅ OAuth successful via code exchange');
            await _sessionManager.saveSession(user, _supabase.auth.currentSession);
            await _handleSuccessfulAuth(user);
            return;
          }
        } catch (e) {
          debugPrint('❌ Error exchanging code: $e');
        }
      }
      
      // Handle error
      if (error != null) {
        debugPrint('❌ OAuth error: $error - $errorDescription');
        _authCompleter?.complete({
          'success': false,
          'message': errorDescription ?? error,
        });
        return;
      }
      
      // No valid auth found
      debugPrint('❌ Could not authenticate with received tokens');
      _authCompleter?.complete({
        'success': false,
        'message': 'Authentication failed - could not process credentials',
      });
      
    } catch (e) {
      debugPrint('❌ Error handling OAuth callback: $e');
      _authCompleter?.complete({
        'success': false,
        'message': 'Failed to complete sign-in: $e',
      });
    }
  }

  /// Handle successful authentication
  Future<void> _handleSuccessfulAuth(User user) async {
    try {
      debugPrint('📍 Processing successful auth for: ${user.email}');
      
      // Check if profile exists
      final existing = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        // Create basic profile from OAuth data
        final profile = {
          'id': user.id,
          'email': user.email,
          'full_name': user.userMetadata?['full_name'] ?? 
                      user.userMetadata?['name'] ?? 'User',
          'display_name': user.userMetadata?['full_name'] ?? 
                         user.userMetadata?['name'] ?? 'User',
          'avatar_url': user.userMetadata?['avatar_url'] ?? 
                       user.userMetadata?['picture'],
          'auth_method': 'google',
          'email_verified': true,
          'phone_verified': false,
          'profile_completed': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        await _supabase.from('user_profiles').insert(profile);
        debugPrint('✅ Profile created from Google OAuth');

        _authCompleter?.complete({
          'success': true,
          'message': 'Google account created successfully!',
          'user': user,
          'profile': profile,
          'requiresBasicInfo': true,
          'googleName': user.userMetadata?['full_name'] ?? user.userMetadata?['name'],
          'googleEmail': user.email,
          'googlePhoto': user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'],
        });
      } else {
        debugPrint('✅ Existing profile found');
        
        _authCompleter?.complete({
          'success': true,
          'message': 'Signed in with Google successfully!',
          'user': user,
          'profile': existing,
        });
      }
    } catch (e) {
      debugPrint('❌ Error in _handleSuccessfulAuth: $e');
      _authCompleter?.complete({
        'success': false,
        'message': 'Failed to complete profile setup: $e',
      });
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
      await _supabase.auth.signOut();
      await _sessionManager.clearSession();
      // Also clear OAuth tokens
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
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