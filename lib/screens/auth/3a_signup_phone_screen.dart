import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../services/simplified_unified_auth_service.dart';

/// Phone Signup Screen (2 steps)
/// Step 1: Enter phone number
/// Step 2: Verify OTP
class SignUpPhoneScreen extends StatefulWidget {
  const SignUpPhoneScreen({super.key});

  @override
  State<SignUpPhoneScreen> createState() => _SignUpPhoneScreenState();
}

class _SignUpPhoneScreenState extends State<SignUpPhoneScreen> {
  final _authService = SimplifiedUnifiedAuthService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isPhoneStep = true; // true = enter phone, false = verify OTP
  bool _isLoading = false;
  String? _errorMessage;
  String? _phoneNumber;

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
        title: Text(_isPhoneStep ? 'Enter Phone' : 'Verify OTP'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                Text(
                  _isPhoneStep
                      ? 'What\'s your phone number?'
                      : 'Enter the OTP sent to your phone',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),
                
                Text(
                  _isPhoneStep
                      ? 'We\'ll send you an OTP to verify'
                      : 'Check your SMS messages',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                if (_isPhoneStep) ...[
                  // Phone input
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '+1 (555) 123-4567',
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ] else ...[
                  // OTP input
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, letterSpacing: 8),
                    decoration: InputDecoration(
                      hintText: '000000',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      counterText: '',
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    'Resend OTP in 30s',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_isPhoneStep ? _sendOTP : _verifyOTP),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isPhoneStep ? 'Send OTP' : 'Verify & Continue',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                if (_isPhoneStep) ...[
                  const SizedBox(height: 32),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendOTP() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final result = await _authService.sendSignUpOTP(_phoneController.text);

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _isPhoneStep = false;
        _isLoading = false;
        _phoneNumber = _phoneController.text;
      });
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Failed to send OTP';
        _isLoading = false;
      });

      if (result['accountExists'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Phone already registered. Please sign in.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Sign In',
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/signin');
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _verifyOTP() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    // For now, just navigate to basic info screen
    // In a real app, you'd verify the OTP first
    if (_otpController.text.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit OTP';
        _isLoading = false;
      });
      return;
    }

    // Navigate to basic info screen
    if (!mounted) return;
    
    Navigator.pushNamed(
      context,
      '/signup-basic-info',
      arguments: {
        'authMethod': 'phone',
        'phoneNumber': _phoneNumber,
        'otp': _otpController.text,
      },
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}