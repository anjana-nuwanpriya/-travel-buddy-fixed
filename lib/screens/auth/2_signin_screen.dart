import 'package:flutter/material.dart';
import '../../services/simplified_unified_auth_service.dart';
import '../../utils/colors.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Log In'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                Text(
                  'Log In your way!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Phone option
                _buildAuthButton(
                  context,
                  label: 'Continue with Phone',
                  icon: Icons.phone_outlined,
                  onTap: () => Navigator.pushNamed(context, '/signin-phone'),
                  isPrimary: true,
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or continue with',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),

                const SizedBox(height: 16),

                _buildAuthButton(
                  context,
                  label: 'Email & Password',
                  icon: Icons.email_outlined,
                  onTap: () => Navigator.pushNamed(context, '/signin-email'),
                ),

                const SizedBox(height: 12),

                // ✅ UPDATED: Google Sign In
                _buildAuthButton(
                  context,
                  label: 'Google',
                  icon: Icons.g_mobiledata,
                  onTap: () => _handleGoogleSignIn(context),
                ),

                const SizedBox(height: 12),

                // ✅ UPDATED: Apple Sign In
                _buildAuthButton(
                  context,
                  label: 'Apple',
                  icon: Icons.apple,
                  onTap: () => _handleAppleSignIn(context),
                ),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacementNamed(context, '/signup');
                      },
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: isPrimary ? Colors.white : AppColors.primary),
        label: Text(
          label,
          style: TextStyle(
            color: isPrimary ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppColors.primary : Colors.white,
          side: isPrimary
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ✅ NEW: Handle Google Sign In
  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final authService = SimplifiedUnifiedAuthService();
  final result = await authService.signUpWithGoogle(context);// This handles both signin & signup!
    
    if (!context.mounted) return;
    
    if (result['success']) {
      // Check if needs basic info (new account)
      if (result['requiresBasicInfo'] == true) {
        Navigator.pushNamed(
          context,
          '/signup-basic-info',
          arguments: {
            'authMethod': 'google',
            'email': result['user']?.email ?? '',
            'googleName': result['profile']?['full_name'] ?? '',
            'googleEmail': result['profile']?['email'] ?? '',
            'googlePhoto': result['profile']?['avatar_url'],
          },
        );
      } else {
        // Existing account - go to home
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Google sign-in failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ NEW: Handle Apple Sign In
  Future<void> _handleAppleSignIn(BuildContext context) async {
    final authService = SimplifiedUnifiedAuthService();
    final result = await authService.signUpWithApple(); // This handles both signin & signup!
    
    if (!context.mounted) return;
    
    if (result['success']) {
      // Check if needs basic info (new account)
      if (result['requiresBasicInfo'] == true) {
        Navigator.pushNamed(
          context,
          '/signup-basic-info',
          arguments: {
            'authMethod': 'apple',
            'email': result['user']?.email ?? '',
            'appleName': result['profile']?['full_name'] ?? '',
            'appleEmail': result['profile']?['email'] ?? '',
          },
        );
      } else {
        // Existing account - go to home
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Apple sign-in failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}