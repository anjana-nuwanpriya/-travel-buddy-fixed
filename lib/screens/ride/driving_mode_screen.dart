import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/ride.dart';
import '../../services/tracking_service.dart';
import '../../services/booking_service.dart';
import '../../services/notification_service.dart';
import '../../utils/colors.dart';

/// 🚀 FIXED DRIVING MODE SCREEN - WITH PROPER TRACKING
/// 
/// ✅ FIXED: Now calls startRideTracking() properly
/// ✅ FIXED: Sets _rideStatus to 'in_progress'
/// ✅ FIXED: Driver location updates on passenger's screen
/// 
/// Stop Card Features:
/// 1. Active Stop: Orange background with action buttons
/// 2. Pending Stops: White background, no buttons
/// 3. Completed Stops: Gray background
/// 4. No zoom animations, smooth transitions
class DrivingModeScreen extends StatefulWidget {
  final Ride ride;

  const DrivingModeScreen({super.key, required this.ride});

  @override
  State<DrivingModeScreen> createState() =>
      _DrivingModeScreenState();
}

class _DrivingModeScreenState
    extends State<DrivingModeScreen> {
  GoogleMapController? _mapController;
  final TrackingService _trackingService = TrackingService();
  final BookingService _bookingService = BookingService();
  final NotificationService _notificationService = NotificationService();

  // ⚡ OPTIMIZED: StreamSubscription instead of Timer
  StreamSubscription<Position>? _locationStream;
  Position? _currentPosition;
  Position? _previousPosition;

  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  bool _isNavigating = false;
  bool _isPaused = false;
  String _rideStatus = 'waiting';  // ← INITIALIZE PROPERLY

  double? _distanceRemaining;
  int? _timeRemaining;

  // Debounce camera updates (only update every 3 seconds)
  Timer? _cameraDebounce;
  bool _shouldUpdateCamera = true;

  // 🆕 Track stop completion status
  final Map<int, bool> _stopsCompleted = {};
  int _activeStopIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeStops();
    _initializeMap();
  }

  void _initializeStops() {
    // Initialize all stops as pending (not completed)
    if (widget.ride.bookings != null) {
      for (int i = 0; i < widget.ride.bookings!.length; i++) {
        _stopsCompleted[i] = false;
      }
    }
    _activeStopIndex = 0;
  }

  // ========================================
  // 🚀 FIXED: Proper initialization with tracking
  // ========================================
  Future<void> _initializeMap() async {
    try {
      print('🚀 Initializing Driving Mode...');
      
      // ✅ STEP 1: Start ride tracking FIRST
      print('📍 Starting ride tracking...');
      final trackingResult = await _trackingService.startRideTracking(widget.ride.id);

      if (!trackingResult['success']) {
        print('❌ Failed to start tracking: ${trackingResult['error']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: Could not start tracking - ${trackingResult['error']}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      print('✅ Ride tracking started successfully');

      // ✅ STEP 2: Set ride status to active (CRITICAL!)
      setState(() {
        _rideStatus = 'in_progress';  // ← This allows GPS updates to be processed!
        _isNavigating = true;
      });

      // ✅ STEP 3: Get current location and initialize map
      print('🗺️ Initializing map...');
      _currentPosition = await _trackingService.getCurrentLocation();

      if (_currentPosition != null) {
        print('✅ Current location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');

        // Decode and display route polyline
        if (widget.ride.routePolyline != null && widget.ride.routePolyline!.isNotEmpty) {
          _decodePolyline(widget.ride.routePolyline!);
        }

        // Add markers for start, end, waypoints
        _addMarkers();
        
        // ⚡ Start GPS stream for UI updates (location is already being tracked by service)
        _startGPSStream();

        // Fit map to show entire route
        _fitMapToRoute();

        if (mounted) {
          setState(() {
            _isNavigating = true;
          });
        }

        print('✅ Map initialized successfully');
        
        // Show notification to passengers
        _notifyPassengersRideStarted();
      } else {
        print('❌ Could not get current location');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not get your location. Please enable GPS.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error initializing map: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _notifyPassengersRideStarted() async {
    try {
      final bookingsResult = await _bookingService.getRideBookings(widget.ride.id);
      if (bookingsResult['success']) {
        final bookings = bookingsResult['bookings'] as List;
        for (var booking in bookings) {
          if (booking['status'] == 'confirmed') {
            await _notificationService.sendNotification(
              userId: booking['passenger_id'],
              title: '🚗 Ride Started!',
              message: 'Your driver is on the way. Track them in real-time.',
              type: 'ride_started',
              data: {'ride_id': widget.ride.id},
            );
          }
        }
      }
    } catch (e) {
      print('⚠️ Could not notify passengers: $e');
    }
  }

  void _decodePolyline(String encodedPolyline) {
    try {
      List<LatLng> polylineCoordinates = _manualDecodePolyline(encodedPolyline);

      setState(() {
        _polylines.add(
          Polyline(
            polylineId: PolylineId('route'),
            points: polylineCoordinates,
            color: Colors.blue.withOpacity(0.6),
            width: 5,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      });

      print('✅ Route polyline displayed');
    } catch (e) {
      print('❌ Error decoding polyline: $e');
    }
  }

  List<LatLng> _manualDecodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  void _addMarkers() {
    _markers.add(
      Marker(
        markerId: MarkerId('start'),
        position: LatLng(
          widget.ride.fromLat ?? widget.ride.fromLatitude,
          widget.ride.fromLng ?? widget.ride.fromLongitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Start',
          snippet: widget.ride.fromLocation.split(',').first,
        ),
      ),
    );

    _markers.add(
      Marker(
        markerId: MarkerId('end'),
        position: LatLng(
          widget.ride.toLat ?? widget.ride.toLatitude,
          widget.ride.toLng ?? widget.ride.toLongitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Destination',
          snippet: widget.ride.toLocation.split(',').first,
        ),
      ),
    );

    if (widget.ride.waypoints != null && widget.ride.waypoints!.isNotEmpty) {
      for (int i = 0; i < widget.ride.waypoints!.length; i++) {
        final waypoint = widget.ride.waypoints![i];
        _markers.add(
          Marker(
            markerId: MarkerId('waypoint_$i'),
            position: LatLng(
              waypoint['lat'] as double,
              waypoint['lng'] as double,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: 'Stop ${i + 1}',
              snippet: waypoint['name'] as String?,
            ),
          ),
        );
      }
    }

    if (_currentPosition != null) {
      _addDriverMarker(_currentPosition!);
    }
  }

  void _addDriverMarker(Position position) {
    _markers.removeWhere((m) => m.markerId.value == 'driver');

    _markers.add(
      Marker(
        markerId: MarkerId('driver'),
        position: LatLng(position.latitude, position.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        rotation: position.heading,
        anchor: Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: 'You (${position.speed.toStringAsFixed(1)} m/s)',
        ),
      ),
    );
  }

  // ========================================
  // ⚡ GPS Stream (for UI updates only)
  // Database updates are handled by TrackingService
  // ========================================

  void _startGPSStream() {
    print('📱 Starting GPS stream for UI updates...');

    // ⚡ Get continuous GPS stream
    _locationStream = _trackingService.getLocationStream().listen(
      (Position position) async {
        // Only process if ride is active and not paused
        if (_rideStatus != 'in_progress' || _isPaused || !mounted) {
          return;
        }

        print('⚡ GPS Stream: ${position.latitude}, ${position.longitude}, ${position.heading}°, Speed: ${position.speed}m/s');

        // Calculate bearing between points
        double? bearing;
        if (_previousPosition != null) {
          bearing = Geolocator.bearingBetween(
            _previousPosition!.latitude,
            _previousPosition!.longitude,
            position.latitude,
            position.longitude,
          );
        } else {
          bearing = position.heading;
        }

        // ⚡ OPTIMIZED: Single setState with all updates
        setState(() {
          _currentPosition = position;
          _addDriverMarker(position);
          _calculateRemainingDistance();
        });

        // ⚡ OPTIMIZED: Debounced camera update (smooth, not janky)
        _updateCameraDebounced(position);

        // NOTE: updateDriverLocation() is ALREADY being called by TrackingService
        // in startRideTracking() → _startContinuousGPSTracking()
        // So we DON'T call it again here to avoid duplicates!

        _previousPosition = position;
      },
      onError: (error) {
        print('❌ GPS stream error: $error');
      },
    );

    print('✅ GPS stream started!');
  }

  /// ⚡ OPTIMIZED: Debounced camera update
  /// Only moves camera every 3 seconds (not every update)
  void _updateCameraDebounced(Position position) {
    if (!_shouldUpdateCamera) return;

    _shouldUpdateCamera = false;

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
    );

    // Reset debounce after 3 seconds
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(Duration(seconds: 3), () {
      _shouldUpdateCamera = true;
    });
  }

  void _calculateRemainingDistance() {
    if (_currentPosition != null) {
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        widget.ride.toLat ?? widget.ride.toLatitude,
        widget.ride.toLng ?? widget.ride.toLongitude,
      );

      _distanceRemaining = distance / 1000;
      _timeRemaining = (distance / 1000 / 60 * 60).round();
    }
  }

  // ========================================
  // 🎯 STOP ACTIONS
  // ========================================

  void _navigateToStop(int stopIndex) {
    print('🗺️ Navigating to stop $stopIndex');
    // Launch navigation (Google Maps, etc.)
  }

  void _skipStop(int stopIndex) {
    print('⏭️ Skipping stop $stopIndex');
    setState(() {
      _stopsCompleted[stopIndex] = false;
      _activeStopIndex = stopIndex + 1;
    });
  }

  void _markStopComplete(int stopIndex) {
    print('✅ Marking stop $stopIndex as complete');
    setState(() {
      _stopsCompleted[stopIndex] = true;
      if (stopIndex + 1 < (_stopsCompleted.length)) {
        _activeStopIndex = stopIndex + 1;
      }
    });
  }

  // ========================================
  // ⏸️ PAUSE / RESUME
  // ========================================

  Future<void> _pauseRide() async {
    setState(() => _isPaused = true);
    _rideStatus = 'paused';

    // Pause GPS stream (it will ignore updates)
    final result = await _trackingService.pauseRideTracking(widget.ride.id);

    if (result['success'] && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ride paused'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _resumeRide() async {
    setState(() => _isPaused = false);
    _rideStatus = 'in_progress';

    // Resume GPS stream (it will process updates again)
    final result = await _trackingService.resumeRideTracking(widget.ride.id);

    if (result['success'] && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ride resumed'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ========================================
  // 🏁 END RIDE
  // ========================================

  Future<void> _endRide() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.stop, color: Colors.red),
            SizedBox(width: 8),
            Text('End Ride?'),
          ],
        ),
        content: Text('Are you sure you want to end this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('End Ride'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // ⚡ Stop GPS stream
    _locationStream?.cancel();
    _locationStream = null;
    _cameraDebounce?.cancel();

    print('🏁 Ending ride...');
    final result = await _trackingService.endRideTracking(widget.ride.id);

    if (result['success']) {
      print('✅ Ride ended successfully');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Ride completed! Points awarded: ${result['pointsAwarded']}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Pop screen
        Future.delayed(Duration(seconds: 1), () {
          Navigator.pop(context, true);
        });
      }
    } else {
      print('❌ Error ending ride: ${result['error']}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _currentPosition == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text('Getting your location...'),
                    ],
                  ),
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: 15,
                  ),
                  polylines: _polylines,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _fitMapToRoute();
                  },
                ),

          // Top status card
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isPaused
                                ? Colors.orange
                                : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isPaused ? Icons.pause_circle : Icons.navigation,
                                size: 16,
                                color: _isPaused ? Colors.white : Colors.green,
                              ),
                              SizedBox(width: 4),
                              Text(
                                _isPaused ? 'Paused' : 'Navigating',
                                style: TextStyle(
                                  color: _isPaused ? Colors.white : Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Destination',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      widget.ride.toLocation.split(',').first,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.straighten, size: 20, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          _distanceRemaining != null
                              ? '${_distanceRemaining!.toStringAsFixed(1)} km'
                              : widget.ride.distance ?? 'N/A',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 24),
                        Icon(Icons.access_time, size: 20, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          _timeRemaining != null
                              ? '$_timeRemaining mins'
                              : widget.ride.duration ?? 'N/A',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ✅ STOP CARDS - Scrollable list
          Positioned(
            top: MediaQuery.of(context).padding.top + 220,
            left: 0,
            right: 0,
            bottom: 140,
            child: widget.ride.bookings == null || widget.ride.bookings!.isEmpty
                ? SizedBox.shrink()
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.ride.bookings!.length,
                    itemBuilder: (context, index) {
                      return _buildStopCard(index, widget.ride.bookings![index]);
                    },
                  ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isPaused ? _resumeRide : _pauseRide,
                          icon: Icon(
                            _isPaused ? Icons.play_arrow : Icons.pause,
                            size: 24,
                          ),
                          label: Text(
                            _isPaused ? 'Resume Ride' : 'Pause Ride',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isPaused ? Colors.green : Colors.orange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _endRide,
                          icon: Icon(Icons.stop, size: 24),
                          label: Text(
                            'End Ride',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red, width: 2),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ BUILD STOP CARD - Orange/White/Gray theme
  Widget _buildStopCard(int stopIndex, Map<String, dynamic> booking) {
    final bool isActive = stopIndex == _activeStopIndex;
    final bool isCompleted = _stopsCompleted[stopIndex] ?? false;
    final String passengerName = booking['passenger']?['full_name'] ?? 'Passenger';
    final String stopType = booking['pickup_status'] == 'pending' ? 'PICKUP' : 'DROPOFF';
    final String address = stopType == 'PICKUP'
        ? booking['pickup_address'] ?? 'Unknown Location'
        : booking['dropoff_address'] ?? 'Unknown Location';

    Color backgroundColor;
    Color textColor;
    Color buttonColor;

    if (isCompleted) {
      // ✅ COMPLETED: Gray
      backgroundColor = Colors.grey[300]!;
      textColor = Colors.grey[700]!;
      buttonColor = Colors.grey;
    } else if (isActive) {
      // 🟠 ACTIVE: Orange
      backgroundColor = Colors.orange;
      textColor = Colors.white;
      buttonColor = Colors.orange;
    } else {
      // ⚪ PENDING: White
      backgroundColor = Colors.white;
      textColor = Colors.black87;
      buttonColor = Colors.grey;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: isActive ? Border.all(color: Colors.orange, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Stop number, type, passenger name
          Row(
            children: [
              Text(
                '${stopIndex + 1}${isActive ? '${stopIndex == 0 ? 'st' : stopIndex == 1 ? 'nd' : stopIndex == 2 ? 'rd' : 'th'} Stop' : '${stopIndex == 0 ? 'st' : stopIndex == 1 ? 'nd' : stopIndex == 2 ? 'rd' : 'th'} Stop'}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.grey[500]
                      : isActive
                          ? Colors.orange[700]
                          : Colors.grey[400],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCompleted ? '✓ COMPLETED' : stopType,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Location
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 20,
                color: textColor,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Passenger info with avatar
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isCompleted
                    ? Colors.grey[400]
                    : isActive
                        ? Colors.orange[700]
                        : Colors.grey[400],
                child: Text(
                  passengerName[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passengerName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Phone and message icons (only for active)
              if (isActive && !isCompleted) ...[
                IconButton(
                  icon: Icon(Icons.call, color: Colors.white),
                  onPressed: () {
                    print('📞 Call passenger');
                  },
                ),
                IconButton(
                  icon: Icon(Icons.message, color: Colors.white),
                  onPressed: () {
                    print('💬 Message passenger');
                  },
                ),
              ],
            ],
          ),

          SizedBox(height: 12),

          // Action buttons (only for active and not completed)
          if (isActive && !isCompleted)
            Column(
              children: [
                Row(
                  children: [
                    // Navigate button
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _navigateToStop(stopIndex),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.navigation, color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Navigate',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Skip button
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _skipStop(stopIndex),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.skip_next, color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Skip',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // Picked Up / Completed button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _markStopComplete(stopIndex),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 20),
                        SizedBox(width: 6),
                        Text(
                          stopType == 'PICKUP' ? 'Picked Up' : 'Dropped Off',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _fitMapToRoute() {
    if (_mapController == null) return;

    try {
      double fromLat = widget.ride.fromLat ?? widget.ride.fromLatitude;
      double fromLng = widget.ride.fromLng ?? widget.ride.fromLongitude;
      double toLat = widget.ride.toLat ?? widget.ride.toLatitude;
      double toLng = widget.ride.toLng ?? widget.ride.toLongitude;

      double minLat = fromLat < toLat ? fromLat : toLat;
      double maxLat = fromLat > toLat ? fromLat : toLat;
      double minLng = fromLng < toLng ? fromLng : toLng;
      double maxLng = fromLng > toLng ? fromLng : toLng;

      double padding = 0.01;
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat - padding, minLng - padding),
        northeast: LatLng(maxLat + padding, maxLng + padding),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    } catch (e) {
      print('❌ Error fitting map: $e');
    }
  }

  @override
  void dispose() {
    _locationStream?.cancel();
    _cameraDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}