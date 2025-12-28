import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../services/ride_tracking_service.dart';
import '../../services/location_service.dart';
import '../../config/supabase_config.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String rideId;
  final String from;
  final String to;

  const LiveTrackingScreen({
    super.key,
    required this.rideId,
    required this.from,
    required this.to,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final _rideTrackingService = RideTrackingService();
  final _locationService = LocationService();
  final _supabase = SupabaseConfig.client;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  StreamSubscription? _rideSubscription;

  // Location tracking
  LatLng? _currentDriverPosition;
  LatLng? _previousDriverPosition;
  final List<LatLng> _driverPath = [];

  // UI state
  double? _driverLat;
  double? _driverLng;
  String? _lastUpdated;
  String? _status;
  String? _distance;
  double _bearing = 0.0;
  bool _autoFollow = true;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    print('📡 Starting real-time tracking for ride: ${widget.rideId}');

    // Debug: Check auth
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    print('🔐 Current user ID: $userId');

    // Debug: Check if user can access this ride
    try {
      final testAccess = await _supabase
          .from('active_rides')
          .select('*')
          .eq('ride_id', widget.rideId)
          .maybeSingle();

      if (testAccess != null) {
        print('✅ User CAN access ride data');
        print(
          '📍 Current location: ${testAccess['current_lat']}, ${testAccess['current_lng']}',
        );
      } else {
        print('❌ User CANNOT access ride data (RLS blocking)');

        // Show error dialog
        if (mounted) {
          _showAccessError();
        }
        return;
      }
    } catch (e) {
      print('❌ Access test error: $e');
      if (mounted) {
        _showAccessError();
      }
      return;
    }

    // Continue with stream subscription
    print('🎯 Starting stream subscription...');
    _rideSubscription = _rideTrackingService
        .subscribeToActiveRide(widget.rideId)
        .listen(
          (activeRide) {
            print('🎯 STREAM CALLBACK TRIGGERED');

            if (activeRide != null && mounted) {
              final lat = activeRide['current_lat'];
              final lng = activeRide['current_lng'];

              print('📍 Raw data: lat=$lat, lng=$lng');

              if (lat != null && lng != null) {
                // Handle both double and string types
                double latitude;
                double longitude;

                try {
                  latitude = lat is String ? double.parse(lat) : lat.toDouble();
                  longitude = lng is String
                      ? double.parse(lng)
                      : lng.toDouble();
                } catch (e) {
                  print('❌ Error parsing coordinates: $e');
                  return;
                }

                print('📍 Location update: $latitude, $longitude');

                setState(() {
                  _driverLat = latitude;
                  _driverLng = longitude;
                  _lastUpdated = activeRide['last_updated'];
                  _status = activeRide['status'];

                  _previousDriverPosition = _currentDriverPosition;
                  _currentDriverPosition = LatLng(latitude, longitude);

                  // Add to path trail
                  if (!_driverPath.contains(_currentDriverPosition)) {
                    _driverPath.add(_currentDriverPosition!);
                  }

                  // Calculate bearing for rotation
                  if (_previousDriverPosition != null) {
                    _bearing = _calculateBearing(
                      _previousDriverPosition!,
                      _currentDriverPosition!,
                    );
                  }
                });

                _updateMap(latitude, longitude);
                _calculateDistance();
              } else {
                print('⚠️ Lat or Lng is null!');
              }
            } else {
              print('⚠️ Active ride is null or widget unmounted');
            }
          },
          onError: (error) {
            print('❌ Stream error: $error');
          },
          onDone: () {
            print('⚠️ Stream closed unexpectedly');
          },
        );

    print('✅ Stream subscription created');
  }

  void _showAccessError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Access Denied'),
        content: Text(
          'You don\'t have permission to track this ride. '
          'This could be because:\n\n'
          '• You don\'t have a confirmed booking for this ride\n'
          '• The ride hasn\'t started yet\n'
          '• You\'re not logged in',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _updateMap(double lat, double lng) {
    final position = LatLng(lat, lng);

    // Update marker with smooth animation
    _updateDriverMarker(position, _bearing);

    // Update path trail
    _updatePathPolyline();

    // Move camera if auto-follow is enabled
    if (_autoFollow) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: 16,
            bearing: _bearing,
            tilt: 45, // 3D view
          ),
        ),
      );
    }
  }

  void _updateDriverMarker(LatLng position, double bearing) {
    print('🎯 Updating marker to: ${position.latitude}, ${position.longitude}');

    setState(() {
      // Clear old marker first
      _markers.clear();

      // Add new marker
      _markers.add(
        Marker(
          markerId: MarkerId(
            'driver_${DateTime.now().millisecondsSinceEpoch}',
          ), // Unique ID forces update
          position: position,
          rotation: bearing,
          anchor: Offset(0.5, 0.5),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: '🚗 Driver',
            snippet:
                'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}',
          ),
        ),
      );
    });

    print('✅ Marker updated! Total markers: ${_markers.length}');
  }

  void _updatePathPolyline() {
    if (_driverPath.length < 2) return;

    setState(() {
      _polylines = {
        Polyline(
          polylineId: PolylineId('driver_path'),
          points: _driverPath,
          color: Colors.blue,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          geodesic: true,
        ),
      };
    });
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;

    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  Future<void> _calculateDistance() async {
    if (_driverLat == null || _driverLng == null) return;

    try {
      final myPosition = await _locationService.getCurrentLocation();
      if (myPosition != null) {
        final distance = _locationService.calculateDistance(
          myPosition.latitude,
          myPosition.longitude,
          _driverLat!,
          _driverLng!,
        );

        if (mounted) {
          setState(() {
            _distance = _locationService.formatDistance(distance);
          });
        }
      }
    } catch (e) {
      print('Error calculating distance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          _buildMap(),

          // Top Info Card
          _buildTopCard(),

          // Bottom Info Card
          _buildBottomCard(),

          // Auto-follow toggle button
          _buildAutoFollowButton(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_currentDriverPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Waiting for driver to start...',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Connecting to live location',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentDriverPosition!,
        zoom: 16,
        tilt: 45,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false, // Custom button instead
      zoomControlsEnabled: false,
      mapType: MapType.normal,
      compassEnabled: true,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: true,
      zoomGesturesEnabled: true,
      trafficEnabled: true, // Show traffic
      onMapCreated: (controller) {
        _mapController = controller;
        print('✅ Map created');
      },
      onCameraMove: (position) {
        // Disable auto-follow when user moves map manually
        if (_autoFollow) {
          setState(() {
            _autoFollow = false;
          });
        }
      },
    );
  }

  Widget _buildTopCard() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Tracking',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.from.split(',').first} → ${widget.to.split(',').first}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Status banner
            if (_status != null)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _status == 'started'
                        ? [Colors.orange, Colors.orange[700]!]
                        : [Colors.green, Colors.green[700]!],
                  ),
                ),
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulsing dot
                    _PulsingDot(),
                    SizedBox(width: 8),
                    Icon(Icons.navigation, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      _status == 'started'
                          ? 'TRACKING STARTED'
                          : 'LIVE TRACKING',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoFollowButton() {
    return Positioned(
      right: 16,
      bottom: 200,
      child: FloatingActionButton(
        mini: true,
        backgroundColor: _autoFollow ? Colors.green : Colors.white,
        onPressed: () {
          setState(() {
            _autoFollow = !_autoFollow;
          });

          if (_autoFollow && _currentDriverPosition != null) {
            _mapController?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: _currentDriverPosition!,
                  zoom: 16,
                  bearing: _bearing,
                  tilt: 45,
                ),
              ),
            );
          }
        },
        child: Icon(
          _autoFollow ? Icons.gps_fixed : Icons.gps_not_fixed,
          color: _autoFollow ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildBottomCard() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),

            // Driver info with animation
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[400]!, Colors.green[600]!],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver Moving',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_driverLat != null && _driverLng != null)
                          Text(
                            'Location updating in real-time',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),
            Divider(height: 1),
            SizedBox(height: 16),

            // Stats row with icons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (_distance != null)
                  _buildAnimatedStatItem(
                    Icons.near_me,
                    'Distance',
                    _distance!,
                    Colors.blue,
                  ),
                _buildAnimatedStatItem(
                  Icons.update,
                  'Updated',
                  _formatTime(_lastUpdated),
                  Colors.orange,
                ),
                _buildAnimatedStatItem(
                  Icons.explore,
                  'Bearing',
                  '${_bearing.toInt()}°',
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedStatItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      final time = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(time);

      if (diff.inSeconds < 10) return 'Just now';
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}

// Pulsing dot widget (outside main class)
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
