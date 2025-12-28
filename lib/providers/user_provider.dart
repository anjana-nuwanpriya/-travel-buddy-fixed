import 'package:flutter/material.dart';
import '../models/user.dart';

class UserProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _verificationId;
  String? _pendingPhoneNumber;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  Future<void> signIn(String phone) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simulate API call
      await Future.delayed(Duration(seconds: 2));

      _currentUser = User(
        id: 'user1',
        name: 'John Doe',
        email: 'john.doe@example.com',
        phone: phone,
        rating: 4.5,
        totalTrips: 24,
        memberSince: DateTime(2022, 6, 15),
        isVerified: true,
      );

      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> sendOTP(String phoneNumber) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Store the phone number for later verification
      _pendingPhoneNumber = phoneNumber;

      // Simulate sending OTP via Firebase or your backend
      await Future.delayed(Duration(seconds: 2));

      // In a real app, you would integrate with Firebase Auth:
      /*
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
      */

      // For demo purposes, simulate successful OTP sending
      _verificationId = 'demo_verification_id';

      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      print('Error sending OTP: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOTP(String otp) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Simulate OTP verification delay
      await Future.delayed(Duration(seconds: 2));

      // In a real app, you would verify with Firebase Auth:
      /*
      if (_verificationId == null) return false;
      
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // Create user object from Firebase user
        _currentUser = User(
          id: userCredential.user!.uid,
          name: userCredential.user!.displayName ?? 'User',
          email: userCredential.user!.email ?? '',
          phone: _pendingPhoneNumber ?? '',
          rating: 5.0,
          totalTrips: 0,
          memberSince: DateTime.now(),
          isVerified: true,
        );
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      */

      // For demo purposes, accept any 6-digit OTP
      if (otp.length == 6 && otp.contains(RegExp(r'^[0-9]+$'))) {
        // Create user after successful verification
        _currentUser = User(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          name: 'New User', // You can update this later
          email: '', // Can be updated in profile
          phone: _pendingPhoneNumber ?? '',
          rating: 5.0,
          totalTrips: 0,
          memberSince: DateTime.now(),
          isVerified: true,
        );

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('Error verifying OTP: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile(User updatedUser) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simulate API call
      await Future.delayed(Duration(seconds: 1));
      _currentUser = updatedUser;
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    _currentUser = null;
    _verificationId = null;
    _pendingPhoneNumber = null;
    notifyListeners();
  }

  // Helper method to clear verification data
  void clearVerificationData() {
    _verificationId = null;
    _pendingPhoneNumber = null;
    notifyListeners();
  }
}
