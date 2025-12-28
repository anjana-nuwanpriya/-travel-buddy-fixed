import 'package:flutter/material.dart';
import '../../services/simplified_unified_auth_service.dart';
import '../../utils/colors.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

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
        title: const Text('Sign Up'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                Text(
                  'Create an account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Phone
                _buildSignUpButton(
                  context,
                  label: 'Continue with Phone',
                  icon: Icons.phone_outlined,
                  onTap: () => Navigator.pushNamed(context, '/signup-phone'),
                  isPrimary: true,
                ),

                const SizedBox(height: 16),

                // OR divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or sign up with',
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

                // Email
                _buildSignUpButton(
                  context,
                  label: 'Email & Password',
                  icon: Icons.email_outlined,
                  onTap: () => Navigator.pushNamed(context, '/signup-email'),
                ),

                const SizedBox(height: 12),

                // Google ✅ UPDATED
                _buildSignUpButton(
                  context,
                  label: 'Google',
                  icon: Icons.g_mobiledata,
                  onTap: () => _handleGoogleSignUp(context),
                ),

                const SizedBox(height: 12),

                // Apple
                _buildSignUpButton(
                  context,
                  label: 'Apple',
                  icon: Icons.apple,
                  onTap: () => _handleAppleSignUp(context),
                ),

                const SizedBox(height: 32),

                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacementNamed(context, '/signin');
                      },
                      child: Text(
                        'Sign In',
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

  Widget _buildSignUpButton(
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

  // ✅ NEW: Handle Google Sign Up
  Future<void> _handleGoogleSignUp(BuildContext context) async {
    final authService = SimplifiedUnifiedAuthService();
final result = await authService.signUpWithGoogle(context);    
    
    if (!context.mounted) return;
    
    if (result['success']) {
      // If requires basic info, go to basic info screen
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
        // Already has profile - sign in
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Google sign-up failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ NEW: Handle Apple Sign Up
  Future<void> _handleAppleSignUp(BuildContext context) async {
    final authService = SimplifiedUnifiedAuthService();
    final result = await authService.signUpWithApple();
    
    if (!context.mounted) return;
    
    if (result['success']) {
      // If requires basic info, go to basic info screen
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
        // Already has profile - sign in
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Apple sign-up failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}