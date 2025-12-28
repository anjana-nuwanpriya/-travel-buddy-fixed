import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/ride_service.dart';
import '../../services/driver_verification_service.dart';
import '../../services/simplified_unified_auth_service.dart';
import '../../utils/colors.dart';
import '../../widgets/verification_blocked_screen.dart';
import 'widgets/location_selection_step.dart';
import 'widgets/date_time_step.dart';
import 'widgets/all_steps.dart';
import 'route_selection_screen.dart';

class PublishRideWizardScreen extends StatefulWidget {
  const PublishRideWizardScreen({super.key});

  @override
  State<PublishRideWizardScreen> createState() =>
      _PublishRideWizardScreenState();
}

class _PublishRideWizardScreenState extends State<PublishRideWizardScreen> {
  final PageController _pageController = PageController();
  final RideService _rideService = RideService();
  final DriverVerificationService _verificationService =
      DriverVerificationService();
  final SimplifiedUnifiedAuthService _authService = SimplifiedUnifiedAuthService();

  int _currentStep = 0;
  bool _isLoading = true;
  bool _isVerified = false;
  String _verificationStatus = 'incomplete';
  bool _isPublishing = false;

  // Ride Data
  String? _fromLocation;
  String? _toLocation;
  double? _fromLat;
  double? _fromLng;
  double? _toLat;
  double? _toLng;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _passengers = 1;
  final double _price = 0.0;
  bool _instantApproval = true;
  bool _middleSeatEmpty = false;
  bool _allowsSmoking = false;
  bool _allowsPets = false;
  bool _luggageAllowed = true;
  bool _wantsReturnTrip = false;
  String _notes = '';

  // Route Data
  String? _routePolyline;
  List<Map<String, dynamic>>? _waypoints;
  String? _distance;
  String? _duration;
  String? _routeSummary;

  final List<String> _stepTitles = [
    'Where are you leaving from?',
    'Where are you heading?',
    'When are you going?',
    'What time will you pick up your passengers?',
    'So how many passengers can you take?',
    'Can passengers book instantly?',
    'Think comfort, keep the middle seat empty!',
    'Add contact Lajit',
    'Coming back as well? Publish your return trip now!',
    'Anything to add about your ride?',
  ];

  @override
  void initState() {
    super.initState();
    _checkVerification();
  }

  Future<void> _checkVerification() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/signin');
        }
        return;
      }

      final result = await _verificationService
          .checkDriverVerification(user.id)
          .timeout(
            Duration(seconds: 10),
            onTimeout: () => {
              'canPostRides': true,
              'status': 'verified',
            },
          );

      if (mounted) {
        setState(() {
          _isVerified = result['canPostRides'] ?? true;
          _verificationStatus = result['status'] ?? 'verified';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error checking verification: $e');
      if (mounted) {
        setState(() {
          _isVerified = true;
          _verificationStatus = 'unknown';
          _isLoading = false;
        });
      }
    }
  }

  void _nextStep() {
    if (_currentStep < _stepTitles.length - 1) {
      if (_currentStep == 1 && _fromLat != null && _toLat != null) {
        _showRouteSelection();
        return;
      }

      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _publishRide();
    }
  }

  Future<void> _showRouteSelection() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteSelectionScreen(
          fromLocation: _fromLocation!,
          toLocation: _toLocation!,
          fromLat: _fromLat,
          fromLng: _fromLng,
          toLat: _toLat,
          toLng: _toLng,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _routePolyline = result['polyline'] as String?;
        _waypoints = result['waypoints'] as List<Map<String, dynamic>>?;
        _distance = result['distance'] as String?;
        _duration = result['duration'] as String?;
        _routeSummary = result['summary'] as String?;
      });

      print('✅ Route data saved');

      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _publishRide() async {
    if (_fromLocation == null || _toLocation == null) {
      _showError('Please select both pickup and destination');
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      _showError('Please select date and time');
      return;
    }

    setState(() {
      _isPublishing = true;
      _isLoading = true;
    });

    try {
      final rideData = {
        'from_location': _fromLocation!,
        'to_location': _toLocation!,
        'from_lat': _fromLat,
        'from_lng': _fromLng,
        'to_lat': _toLat,
        'to_lng': _toLng,
        'route_polyline': _routePolyline,
        'waypoints': _waypoints,
        'distance': _distance,
        'duration': _duration,
        'route_summary': _routeSummary,
        'departure_date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'departure_time':
            '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00',
        'available_seats': _passengers,
        'price_per_seat': 0.0,
        'instant_approval': _instantApproval,
        'middle_seat_empty': _middleSeatEmpty,
        'allows_smoking': _allowsSmoking,
        'allows_pets': _allowsPets,
        'luggage_allowed': _luggageAllowed,
        'notes': _notes.isNotEmpty ? _notes : null,
      };

      print('📤 Publishing ride from $_fromLocation to $_toLocation');

      final result = await _rideService.publishRide(rideData);

      if (!mounted) return;

      print('✅ Result: $result');

      if (result['success'] == true) {
        print('✅ Ride published successfully!');
        
        setState(() {
          _isPublishing = false;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ride published successfully!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
              print('✅ Navigated to home');
            }
          });
        }
      } else {
        _showError(result['error'] ?? 'Failed to publish ride');
        setState(() {
          _isPublishing = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ Exception: $e');
      _showError('Error: $e');
      setState(() {
        _isPublishing = false;
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _currentStep == 0) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: SizedBox.shrink(),
          title: Text(
            'Post a Ride',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.normal,
              fontSize: 18,
            ),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (!_isVerified) {
      return VerificationBlockedScreen(
        verificationStatus: _verificationStatus,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _currentStep == 0
            ? SizedBox.shrink()
            : IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.black),
                onPressed: _previousStep,
              ),
        title: Text(
          'Post a Ride',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.normal,
            fontSize: 18,
          ),
        ),
        bottom: _currentStep < _stepTitles.length
            ? PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _stepTitles.length,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4500)),
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(),
        children: [
          LocationSelectionStep(
            title: _stepTitles[0],
            maxRecentItems: 4,
            onLocationSelected: (location, lat, lng) {
              setState(() {
                _fromLocation = location;
                _fromLat = lat;
                _fromLng = lng;
              });
              _nextStep();
            },
          ),

          LocationSelectionStep(
            title: _stepTitles[1],
            maxRecentItems: 4,
            onLocationSelected: (location, lat, lng) {
              setState(() {
                _toLocation = location;
                _toLat = lat;
                _toLng = lng;
              });
              _nextStep();
            },
          ),

          DateTimeStep(
            title: _stepTitles[2],
            isDatePicker: true,
            onDateSelected: (date) {
              setState(() => _selectedDate = date);
              _nextStep();
            },
          ),

          TimeInputStep(
            title: _stepTitles[3],
            onTimeSelected: (time) {
              setState(() => _selectedTime = time);
              _nextStep();
            },
          ),

          PassengersStep(
            title: _stepTitles[4],
            initialCount: _passengers,
            onCountChanged: (count) {
              setState(() => _passengers = count);
            },
            onNext: _nextStep,
          ),

          InstantApprovalStep(
            title: _stepTitles[5],
            onSelected: (value) {
              setState(() => _instantApproval = value);
              _nextStep();
            },
          ),

          MiddleSeatStep(
            title: _stepTitles[6],
            onSelected: (value) {
              setState(() => _middleSeatEmpty = value);
              _nextStep();
            },
          ),

          PreferencesStep(
            title: _stepTitles[7],
            instantApproval: _instantApproval,
            allowsSmoking: _allowsSmoking,
            allowsPets: _allowsPets,
            luggageAllowed: _luggageAllowed,
            onChanged: (smoking, pets, luggage) {
              setState(() {
                _allowsSmoking = smoking;
                _allowsPets = pets;
                _luggageAllowed = luggage;
              });
            },
            onNext: _nextStep,
          ),

          ReturnTripStep(
            title: _stepTitles[8],
            onSelected: (value) {
              setState(() => _wantsReturnTrip = value);
              _nextStep();
            },
          ),

          NotesStep(
            title: _stepTitles[9],
            onNotesChanged: (notes) {
              setState(() => _notes = notes);
            },
            onPublish: _publishRide,
            isLoading: _isPublishing,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

// ✅ SIMPLE TIME INPUT - Just type HH:MM
class TimeInputStep extends StatefulWidget {
  final String title;
  final Function(TimeOfDay) onTimeSelected;

  const TimeInputStep({
    super.key,
    required this.title,
    required this.onTimeSelected,
  });

  @override
  State<TimeInputStep> createState() => _TimeInputStepState();
}

class _TimeInputStepState extends State<TimeInputStep> {
  late TextEditingController _timeController;
  String _errorText = '';

  @override
  void initState() {
    super.initState();
    _timeController = TextEditingController(text: '09:00');
  }

  bool _validateTime(String time) {
    final regex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
    return regex.hasMatch(time);
  }

  void _confirmTime() {
    final time = _timeController.text.trim();
    
    if (time.isEmpty) {
      setState(() => _errorText = 'Please enter a time');
      return;
    }

    if (!_validateTime(time)) {
      setState(() => _errorText = 'Format: HH:MM (e.g., 09:30)');
      return;
    }

    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        setState(() => _errorText = 'Invalid time');
        return;
      }

      widget.onTimeSelected(TimeOfDay(hour: hour, minute: minute));
    } catch (e) {
      setState(() => _errorText = 'Invalid time format');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 48),

            // Time Input Field
            TextField(
              controller: _timeController,
              keyboardType: TextInputType.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF4500),
              ),
              decoration: InputDecoration(
                hintText: 'HH:MM',
                hintStyle: TextStyle(
                  fontSize: 48,
                  color: Colors.grey[300],
                  fontWeight: FontWeight.bold,
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 2),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Color(0xFFFF4500),
                    width: 3,
                  ),
                ),
                errorText: _errorText.isEmpty ? null : _errorText,
                errorStyle: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() => _errorText = '');
                }
              },
            ),

            SizedBox(height: 16),

            // Helper text
            Center(
              child: Column(
                children: [
                  Text(
                    'Format: HH:MM',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Use 24-hour format (00:00 - 23:59)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Examples: 09:30, 14:45, 22:00',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 48),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmTime,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF4500),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Icon(Icons.arrow_forward, color: Colors.white, size: 24),
              ),
            ),

            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }
}