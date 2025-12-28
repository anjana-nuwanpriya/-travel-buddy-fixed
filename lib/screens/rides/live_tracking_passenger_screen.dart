import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/ride.dart';
import '../../models/booking.dart';
import '../../services/tracking_service.dart';
import '../../services/booking_service.dart';
import '../../utils/colors.dart';

/// 🚗 FIXED LIVE TRACKING PASSENGER SCREEN
/// 
/// ✅ FIXED: Proper WebSocket stream handling
/// ✅ FIXED: Optimized booking refresh (30sec, not 10sec)
/// ✅ FIXED: Smooth car animation
/// ✅ FIXED: Real-time distance/ETA updates
/// 
/// Features:
/// 1. Real-time car icon movement
/// 2. Smooth animation with ease-out curve
/// 3. Live distance and ETA calculation
/// 4. Passenger marker (pickup/dropoff)
/// 5. Route visualization (planned + actual path)
/// 6. Ride status updates

class LiveTrackingPassengerScreen extends StatefulWidget {
  final Ride ride;
  final String bookingId;

  const LiveTrackingPassengerScreen({
    super.key,
    required this.ride,
    required this.bookingId,
  });

  @override
  State<LiveTrackingPassengerScreen> createState() =>
      _LiveTrackingPassengerScreenState();
}

class _LiveTrackingPassengerScreenState
    extends State<LiveTrackingPassengerScreen> with SingleTickerProviderStateMixin {
  final TrackingService _trackingService = TrackingService();
  final BookingService _bookingService = BookingService();

  GoogleMapController? _mapController;
  StreamSubscription? _locationStream;
  Timer? _bookingRefreshTimer;
  Timer? _animationTimer;

  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  List<LatLng> _actualPath = [];

  // Current driver position
  double? _driverLat;
  double? _driverLng;
  double? _driverBearing;

  // Animation variables for smooth movement
  double? _prevDriverLat;
  double? _prevDriverLng;
  double? _prevDriverBearing;
  double _animationProgress = 0.0;
  LatLng? _targetPosition;
  double? _targetBearing;

  // Custom car icon
  BitmapDescriptor? _carIcon;

  Booking? _myBooking;
  bool _isPickedUp = false;

  bool _isRideActive = false;
  bool _isRideCompleted = false;
  bool _initialCameraSet = false;

  double? _distanceToTarget;
  int? _etaMinutes;
  String _rideStatus = 'Waiting for driver...';

  @override
  void initState() {
    super.initState();
    _loadCarIcon();
    _initializeTracking();
  }

  @override
  void dispose() {
    _locationStream?.cancel();
    _bookingRefreshTimer?.cancel();
    _animationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🚗 LOAD CUSTOM CAR ICON
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadCarIcon() async {
    try {
      print('🎨 Loading custom car icon...');
      _carIcon = await _createCarIcon();
      print('✅ Car icon loaded successfully');
      if (mounted) setState(() {});
    } catch (e) {
      print('❌ Error loading car icon: $e');
      _carIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  Future<BitmapDescriptor> _createCarIcon() async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint();

    const size = 120.0;
    const carWidth = size * 0.5;
    const carHeight = size * 0.7;

    // Car body (orange)
    paint.color = AppColors.primary;
    final carRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size / 2, size / 2),
        width: carWidth,
        height: carHeight,
      ),
      Radius.circular(12),
    );
    canvas.drawRRect(carRect, paint);

    // Car windows (light blue)
    paint.color = Color(0xFF87CEEB);
    final windowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size / 2, size / 2 - 8),
        width: carWidth * 0.7,
        height: carHeight * 0.35,
      ),
      Radius.circular(6),
    );
    canvas.drawRRect(windowRect, paint);

    // White outline
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    canvas.drawRRect(carRect, paint);

    // Direction indicator (white triangle at top)
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(size / 2, size / 2 - carHeight / 2 - 10);
    path.lineTo(size / 2 - 8, size / 2 - carHeight / 2 + 5);
    path.lineTo(size / 2 + 8, size / 2 - carHeight / 2 + 5);
    path.close();
    canvas.drawPath(path, paint);

    // Shadow
    paint.color = Colors.black.withOpacity(0.3);
    paint.style = PaintingStyle.fill;
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size / 2, size / 2 + carHeight / 2 + 5),
        width: carWidth * 0.8,
        height: 10,
      ),
      paint,
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // ═══════════════════════════════════════════════════════════
  // 🎬 SMOOTH ANIMATION SYSTEM
  // ═══════════════════════════════════════════════════════════
  void _startSmoothAnimation(double targetLat, double targetLng, double? targetBearing) {
    _prevDriverLat = _driverLat;
    _prevDriverLng = _driverLng;
    _prevDriverBearing = _driverBearing ?? 0;

    _targetPosition = LatLng(targetLat, targetLng);
    _targetBearing = targetBearing;

    _animationProgress = 0.0;
    _animationTimer?.cancel();

    const animationDuration = Duration(milliseconds: 1500);
    const frameRate = Duration(milliseconds: 16);
    final totalFrames = animationDuration.inMilliseconds / frameRate.inMilliseconds;

    _animationTimer = Timer.periodic(frameRate, (timer) {
      if (_animationProgress >= 1.0) {
        timer.cancel();
        setState(() {
          _driverLat = targetLat;
          _driverLng = targetLng;
          _driverBearing = targetBearing;
        });
        _updateDriverMarker();
        return;
      }

      final easedProgress = _easeOutCubic(_animationProgress);

      if (_prevDriverLat != null && _prevDriverLng != null) {
        final interpolatedLat = _prevDriverLat! + 
            (targetLat - _prevDriverLat!) * easedProgress;
        final interpolatedLng = _prevDriverLng! + 
            (targetLng - _prevDriverLng!) * easedProgress;

        double interpolatedBearing = _prevDriverBearing ?? 0;
        if (targetBearing != null) {
          double bearingDiff = targetBearing - (_prevDriverBearing ?? 0);
          
          if (bearingDiff > 180) bearingDiff -= 360;
          if (bearingDiff < -180) bearingDiff += 360;
          
          interpolatedBearing = (_prevDriverBearing ?? 0) + bearingDiff * easedProgress;
          
          if (interpolatedBearing < 0) interpolatedBearing += 360;
          if (interpolatedBearing >= 360) interpolatedBearing -= 360;
        }

        setState(() {
          _driverLat = interpolatedLat;
          _driverLng = interpolatedLng;
          _driverBearing = interpolatedBearing;
        });

        _updateDriverMarker();
      }

      _animationProgress += 1.0 / totalFrames;
    });
  }

  double _easeOutCubic(double t) {
    final t1 = t - 1;
    return t1 * t1 * t1 + 1;
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 INITIALIZATION
  // ═══════════════════════════════════════════════════════════
  Future<void> _initializeTracking() async {
    print('🎯 Initializing tracking - Ride: ${widget.ride.id}');

    await _loadMyBooking();
    _isRideActive = await _trackingService.checkIfRideStarted(widget.ride.id);

    if (_isRideActive) {
      _rideStatus = _isPickedUp ? 'Heading to destination' : 'Driver is on the way';
      await _loadInitialData();
      _startLocationStream();
      _startBookingRefresh();
    } else {
      _rideStatus = 'Waiting for driver to start...';
      _showStaticRoute();
    }

    _addPassengerMarkers();
  }

  Future<void> _loadMyBooking() async {
    try {
      final result = await _bookingService.getBookingDetails(widget.bookingId);

      if (result['success']) {
        _myBooking = result['booking'] as Booking;
        _isPickedUp = _myBooking?.isPickedUp ?? false;

        print('✅ Booking loaded:');
        print('   Pickup: ${_myBooking?.pickupAddress}');
        print('   Dropoff: ${_myBooking?.dropoffAddress}');
        print('   Status: ${_isPickedUp ? "Picked up" : "Waiting"}');

        if (mounted) setState(() {});
      }
    } catch (e) {
      print('❌ Error loading booking: $e');
    }
  }

  Future<void> _loadInitialData() async {
    final locationData = await _trackingService.getCurrentRideLocation(widget.ride.id);

    if (locationData != null) {
      final lat = (locationData['current_lat'] as num?)?.toDouble();
      final lng = (locationData['current_lng'] as num?)?.toDouble();
      final bearing = (locationData['bearing'] as num?)?.toDouble();

      if (lat != null && lng != null) {
        setState(() {
          _driverLat = lat;
          _driverLng = lng;
          _driverBearing = bearing;
        });

        _addDriverMarker();
        _calculateStats();
      }

      final pathPoints = await _trackingService.getCompletePath(widget.ride.id);
      if (pathPoints.isNotEmpty) {
        setState(() {
          _actualPath = pathPoints
              .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
              .toList();
        });
        _updateOrangePath();
      }
    }

    _showStaticRoute();
  }

  // ✅ FIXED: Proper WebSocket stream handling
  void _startLocationStream() {
    print('📡 Starting WebSocket stream for ride: ${widget.ride.id}');
    
    _locationStream = _trackingService.streamDriverLocation(widget.ride.id).listen(
      (locationData) {
        if (locationData.isEmpty) {
          print('⚠️ Empty location data received');
          return;
        }

        final lat = (locationData['current_lat'] as num?)?.toDouble();
        final lng = (locationData['current_lng'] as num?)?.toDouble();
        final bearing = (locationData['bearing'] as num?)?.toDouble();
        final status = locationData['status'] as String?;

        if (lat == null || lng == null) {
          print('⚠️ Missing latitude or longitude in stream data');
          return;
        }

        print('🔄 Stream update: $lat, $lng (bearing: $bearing°)');

        if (_driverLat != null && _driverLng != null) {
          final distance = Geolocator.distanceBetween(
            _driverLat!,
            _driverLng!,
            lat,
            lng,
          );

          if (distance > 1) {
            print('✨ Animating to new position (${distance.toStringAsFixed(1)}m away)');
            _startSmoothAnimation(lat, lng, bearing);
          } else {
            print('⏸️ Position change too small (${distance.toStringAsFixed(1)}m), skipping animation');
          }
        } else {
          print('📍 Setting initial driver position');
          setState(() {
            _driverLat = lat;
            _driverLng = lng;
            _driverBearing = bearing;
          });
          _updateDriverMarker();
        }

        if (status == 'completed') {
          setState(() {
            _isRideCompleted = true;
            _rideStatus = 'Ride completed';
          });
        } else {
          setState(() {
            _rideStatus = _isPickedUp ? 'Heading to destination' : 'Driver is on the way';
          });
        }

        _calculateStats();

        if (!_initialCameraSet && _driverLat != null && _driverLng != null) {
          _animateCameraToDriver();
          _initialCameraSet = true;
        }
      },
      onError: (error) {
        print('❌ Stream error: $error');
        print('💡 Make sure Realtime is ENABLED in Supabase dashboard');
      },
      onDone: () {
        print('⚠️ Stream closed');
      },
    );
  }

  // ✅ FIXED: Optimized booking refresh (30 seconds, not 10)
  void _startBookingRefresh() {
    _bookingRefreshTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_isRideCompleted) {
        print('🏁 Ride completed, stopping booking refresh');
        timer.cancel();
        return;
      }

      final oldStatus = _isPickedUp;
      
      try {
        await _loadMyBooking();

        if (!oldStatus && _isPickedUp) {
          print('🎉 Passenger picked up!');
          _addPassengerMarkers();
          _calculateStats();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ You have been picked up!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        print('⚠️ Error refreshing booking: $e');
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 MARKER MANAGEMENT
  // ═══════════════════════════════════════════════════════════
  void _addDriverMarker() {
    if (_driverLat == null || _driverLng == null || _carIcon == null) return;

    _markers.removeWhere((m) => m.markerId.value == 'driver');
    _markers.add(
      Marker(
        markerId: MarkerId('driver'),
        position: LatLng(_driverLat!, _driverLng!),
        icon: _carIcon!,
        rotation: _driverBearing ?? 0,
        anchor: Offset(0.5, 0.5),
        flat: true,
        infoWindow: InfoWindow(
          title: '🚗 Driver',
          snippet: _isRideCompleted ? 'Arrived' : 'On the way',
        ),
      ),
    );
  }

  void _updateDriverMarker() {
    _addDriverMarker();
    if (mounted) setState(() {});
  }

  void _addPassengerMarkers() {
    if (_myBooking == null) return;

    _markers.removeWhere((m) => 
        m.markerId.value == 'my_pickup' || m.markerId.value == 'my_dropoff');

    if (!_isPickedUp && _myBooking!.pickupLat != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('my_pickup'),
          position: LatLng(_myBooking!.pickupLat!, _myBooking!.pickupLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: '📍 Your Pickup',
            snippet: _myBooking!.pickupAddress ?? 'Pickup Location',
          ),
        ),
      );
    }

    if (_isPickedUp && _myBooking!.dropoffLat != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('my_dropoff'),
          position: LatLng(_myBooking!.dropoffLat!, _myBooking!.dropoffLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: '🏁 Your Destination',
            snippet: _myBooking!.dropoffAddress ?? 'Dropoff Location',
          ),
        ),
      );
    }

    if (mounted) setState(() {});
  }

  // ═══════════════════════════════════════════════════════════
  // 🗺️ MAP MANAGEMENT
  // ═══════════════════════════════════════════════════════════
  void _showStaticRoute() {
    if (widget.ride.routePolyline == null) return;

    final polylinePoints = _decodePolyline(widget.ride.routePolyline!);

    _polylines.add(
      Polyline(
        polylineId: PolylineId('planned_route'),
        points: polylinePoints,
        color: Colors.blue.withOpacity(0.5),
        width: 4,
        patterns: [PatternItem.dash(10), PatternItem.gap(10)],
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );

    if (mounted) setState(() {});
  }

  void _updateOrangePath() {
    if (_actualPath.isEmpty) return;

    _polylines.removeWhere((p) => p.polylineId.value == 'actual_path');
    _polylines.add(
      Polyline(
        polylineId: PolylineId('actual_path'),
        points: _actualPath,
        color: AppColors.primary,
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );

    if (mounted) setState(() {});
  }

  void _calculateStats() {
    if (_driverLat == null || _driverLng == null || _myBooking == null) return;

    double targetLat;
    double targetLng;

    if (_isPickedUp) {
      targetLat = _myBooking!.dropoffLat ?? widget.ride.toLatitude;
      targetLng = _myBooking!.dropoffLng ?? widget.ride.toLongitude;
    } else {
      targetLat = _myBooking!.pickupLat ?? widget.ride.fromLatitude;
      targetLng = _myBooking!.pickupLng ?? widget.ride.fromLongitude;
    }

    final distance = Geolocator.distanceBetween(
        _driverLat!, _driverLng!, targetLat, targetLng);

    _distanceToTarget = distance / 1000;
    _etaMinutes = (distance / 1000 / 60 * 60).round();
  }

  void _animateCameraToDriver() {
    if (_mapController == null || _driverLat == null || _driverLng == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(_driverLat!, _driverLng!), 15),
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

      if (_driverLat != null && _driverLng != null) {
        minLat = [minLat, _driverLat!].reduce((a, b) => a < b ? a : b);
        maxLat = [maxLat, _driverLat!].reduce((a, b) => a > b ? a : b);
        minLng = [minLng, _driverLng!].reduce((a, b) => a < b ? a : b);
        maxLng = [maxLng, _driverLng!].reduce((a, b) => a > b ? a : b);
      }

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

  List<LatLng> _decodePolyline(String encoded) {
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

  // ═══════════════════════════════════════════════════════════
  // 🎨 UI BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track Driver'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_isRideCompleted)
            IconButton(
              icon: Icon(Icons.check_circle),
              onPressed: () {},
              tooltip: 'Ride Completed',
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.ride.fromLat ?? widget.ride.fromLatitude,
                widget.ride.fromLng ?? widget.ride.fromLongitude,
              ),
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              _fitMapToRoute();
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildStatusCard(),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: _buildLegend(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isRideCompleted
                        ? Colors.grey
                        : (_isRideActive ? Colors.green : Colors.orange),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  _rideStatus,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (_distanceToTarget != null && !_isRideCompleted) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.straighten, size: 20, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    '${_distanceToTarget!.toStringAsFixed(1)} km',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 24),
                  Icon(Icons.access_time, size: 20, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    '$_etaMinutes mins',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                _isPickedUp
                    ? 'Distance to your destination'
                    : 'Distance to your pickup',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (_isRideCompleted) ...[
              SizedBox(height: 8),
              Text(
                '✅ Your ride has been completed!',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 3,
                  color: Colors.blue.withOpacity(0.5),
                ),
                SizedBox(width: 8),
                Text('Planned route', style: TextStyle(fontSize: 12)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 30, height: 3, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Actual path', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}