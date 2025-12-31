import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/simplified_unified_auth_service.dart';
import '../../utils/colors.dart';

class SignInPhoneScreen extends StatefulWidget {
  const SignInPhoneScreen({super.key});

  @override
  State<SignInPhoneScreen> createState() => _SignInPhoneScreenState();
}

class _SignInPhoneScreenState extends State<SignInPhoneScreen> {
  final _authService = SimplifiedUnifiedAuthService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isPhoneStep = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  
  // Resend OTP timer
  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () {
            if (!_isPhoneStep) {
              setState(() {
                _isPhoneStep = true;
                _errorMessage = null;
                _successMessage = null;
                _otpController.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(_isPhoneStep ? 'Enter Phone' : 'Verify OTP'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                
                Text(
                  _isPhoneStep
                      ? 'What\'s your phone number?'
                      : 'Enter the OTP',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (!_isPhoneStep) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Code sent to ${_authService.smsService.getDisplayNumber(_phoneController.text)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                if (_isPhoneStep) ...[
                  // Phone input with Sri Lanka prefix
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '7X XXX XXXX',
                      labelText: 'Phone Number',
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🇱🇰', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(
                              '+94',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
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
                    onChanged: (value) {
                      if (value.length == 6) {
                        _verifyOTP();
                      }
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Resend OTP
                  Center(
                    child: _resendCountdown > 0
                        ? Text(
                            'Resend OTP in ${_resendCountdown}s',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          )
                        : TextButton(
                            onPressed: _isLoading ? null : _resendOTP,
                            child: Text(
                              'Resend OTP',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                ],

                // Success message
                if (_successMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: TextStyle(color: Colors.green.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_isPhoneStep ? _sendOTP : _verifyOTP),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                            _isPhoneStep ? 'Send OTP' : 'Verify OTP',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                // Sign up link
                if (_isPhoneStep) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number');
      return;
    }

    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isLoading = true;
    });

    final result = await _authService.sendSignInOTP(phone);

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _isPhoneStep = false;
        _isLoading = false;
        _successMessage = 'OTP sent successfully!';
      });
      _startResendTimer();
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Failed to send OTP';
        _isLoading = false;
      });

      // Handle rate limiting
      if (result['rateLimited'] == true) {
        final remaining = result['remainingSeconds'] ?? 60;
        _resendCountdown = remaining;
        _resendTimer?.cancel();
        _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_resendCountdown > 0) {
            setState(() => _resendCountdown--);
          } else {
            timer.cancel();
          }
        });
      }

      // Handle account not found
      if (result['accountNotFound'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Phone not registered. Please sign up first.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Sign Up',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/signup');
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit OTP');
      return;
    }

    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isLoading = true;
    });

    final result = await _authService.verifySignInOTP(
      _phoneController.text.trim(),
      otp,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Failed to verify OTP';
        _isLoading = false;
      });

      // Go back to phone step on critical errors
      if (result['expired'] == true || result['maxAttemptsExceeded'] == true || result['notFound'] == true) {
        setState(() {
          _isPhoneStep = true;
          _otpController.clear();
        });
      }
    }
  }

  Future<void> _resendOTP() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isLoading = true;
    });

    final result = await _authService.resendSignInOTP(_phoneController.text.trim());

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      setState(() => _successMessage = 'New OTP sent successfully!');
      _startResendTimer();
      _otpController.clear();
    } else {
      setState(() => _errorMessage = result['message'] ?? 'Failed to resend OTP');
    }
  }
}