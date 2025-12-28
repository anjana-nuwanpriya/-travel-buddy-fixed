import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/colors.dart';
import '../../config/supabase_config.dart';
import '../../services/simplified_unified_auth_service.dart';

/// CRITICAL SCREEN
/// This is the ONLY signup screen after phone/email/google/apple auth
/// Collects: Full Name, Email, Phone, Date of Birth, Gender (optional), Photo (optional)
/// NO emergency contact, NO ID verification, NO vehicle setup
class SignUpBasicInfoScreen extends StatefulWidget {
  final Map<String, dynamic> authData;

  const SignUpBasicInfoScreen({
    super.key,
    required this.authData,
  });

  @override
  State<SignUpBasicInfoScreen> createState() => _SignUpBasicInfoScreenState();
}

class _SignUpBasicInfoScreenState extends State<SignUpBasicInfoScreen> {
  final _authService = SimplifiedUnifiedAuthService();
  
  // Form controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Form state
  DateTime? _dateOfBirth;
  String? _gender;
  String? _photoUrl;
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prefillFromAuthData();
  }

  /// Pre-fill fields based on auth method
  void _prefillFromAuthData() {
    final authMethod = widget.authData['authMethod'] as String? ?? 'phone';
    
    // All methods can have email pre-filled
    if (widget.authData['email'] != null) {
      _emailController.text = widget.authData['email'] as String;
    }
    
    // Phone auth: pre-fill phone
    if (authMethod == 'phone' && widget.authData['phoneNumber'] != null) {
      _phoneController.text = widget.authData['phoneNumber'] as String;
    }
    
    // Email auth: pre-fill email
    if (authMethod == 'email' && widget.authData['email'] != null) {
      _emailController.text = widget.authData['email'] as String;
    }
    
    // Google/Apple: pre-fill name, email, photo
    if (authMethod == 'google') {
      if (widget.authData['googleName'] != null) {
        _fullNameController.text = widget.authData['googleName'] as String;
      }
      if (widget.authData['googleEmail'] != null) {
        _emailController.text = widget.authData['googleEmail'] as String;
      }
      if (widget.authData['googlePhoto'] != null) {
        _photoUrl = widget.authData['googlePhoto'] as String;
      }
    }
    
    if (authMethod == 'apple') {
      if (widget.authData['appleName'] != null) {
        _fullNameController.text = widget.authData['appleName'] as String;
      }
      if (widget.authData['appleEmail'] != null) {
        _emailController.text = widget.authData['appleEmail'] as String;
      }
    }
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Basic Information'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                Text(
                  'Complete your profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Just a few quick details to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                // Full Name *
                _buildTextField(
                  label: 'Full Name *',
                  controller: _fullNameController,
                  hint: 'John Doe',
                  keyboardType: TextInputType.name,
                ),

                const SizedBox(height: 16),

                // Email *
                _buildTextField(
                  label: 'Email *',
                  controller: _emailController,
                  hint: 'your@email.com',
                  keyboardType: TextInputType.emailAddress,
                  readOnly: widget.authData['authMethod'] == 'email' ||
                      widget.authData['authMethod'] == 'google' ||
                      widget.authData['authMethod'] == 'apple',
                ),

                const SizedBox(height: 16),

                // Phone *
                _buildTextField(
                  label: 'Phone *',
                  controller: _phoneController,
                  hint: '+1 (555) 123-4567',
                  keyboardType: TextInputType.phone,
                  readOnly: widget.authData['authMethod'] == 'phone',
                ),

                const SizedBox(height: 16),

                // Date of Birth *
                _buildDatePicker(),

                const SizedBox(height: 16),

                // Gender (Optional)
                _buildGenderSelector(),

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

                // Complete button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _completeSignUp,
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
                        : const Text(
                            'Complete Sign Up',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),
                
                Text(
                  '* Required fields',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.all(16),
            filled: readOnly,
            fillColor: readOnly ? Colors.grey.shade100 : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date of Birth *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dateOfBirth == null
                      ? 'Select date'
                      : DateFormat('MMM dd, yyyy').format(_dateOfBirth!),
                  style: TextStyle(
                    fontSize: 16,
                    color: _dateOfBirth == null
                        ? Colors.grey.shade600
                        : Colors.black87,
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: ['Male', 'Female', 'Other', 'Prefer not to say']
              .map((gender) => ChoiceChip(
                    label: Text(gender),
                    selected: _gender == gender,
                    onSelected: (selected) {
                      setState(() => _gender = selected ? gender : null);
                    },
                    backgroundColor: Colors.white,
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    side: BorderSide(
                      color: _gender == gender
                          ? AppColors.primary
                          : Colors.grey.shade300,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );

    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _completeSignUp() async {
    // Validate required fields
    if (_fullNameController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name');
      return;
    }
    if (_emailController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email');
      return;
    }
    if (_phoneController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number');
      return;
    }
    if (_dateOfBirth == null) {
      setState(() => _errorMessage = 'Please select your date of birth');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final authMethod = widget.authData['authMethod'] as String? ?? 'phone';
      Map<String, dynamic> result = {};

      if (authMethod == 'phone') {
        // Verify OTP and create profile (OTP already verified in previous screen)
        result = await _authService.verifySignUpOTPAndCreateProfile(
          phoneNumber: _phoneController.text,
          otp: widget.authData['otp'] ?? '',
          fullName: _fullNameController.text,
          email: _emailController.text,
          dateOfBirth: _dateOfBirth!,
          gender: _gender,
          photoUrl: _photoUrl,
        );
      } else if (authMethod == 'email') {
        // Complete email signup
        result = await _authService.completeEmailSignUp(
          email: _emailController.text,
          fullName: _fullNameController.text,
          phoneNumber: _phoneController.text,
          dateOfBirth: _dateOfBirth!,
          gender: _gender,
          photoUrl: _photoUrl,
        );
      } else if (authMethod == 'google' || authMethod == 'apple') {
        // For OAuth, get current user and update profile
        final user = SupabaseConfig.currentUser;
        if (user != null) {
          final profile = {
            'id': user.id,
            'email': _emailController.text,
            'phone': _phoneController.text,
            'full_name': _fullNameController.text,
            'display_name': _fullNameController.text,
            'avatar_url': _photoUrl,
            'date_of_birth': _dateOfBirth!.toIso8601String(),
            'gender': _gender,
            'auth_method': authMethod,
            'phone_verified': false,
            'email_verified': true,
            'profile_completed': true,
            'signup_completed_at': DateTime.now().toIso8601String(),
          };

          // Update profile in database
          await SupabaseConfig.updateUserProfile(user.id, profile);

          result = {'success': true};
        }
      }

      if (!mounted) return;

      if (result['success']) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Sign up failed';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}