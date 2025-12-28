import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/ride.dart';
import '../../models/ride_stop.dart';
import '../../services/ride_stops_service.dart';
import '../../services/maps_helper_service.dart';
import '../../services/tracking_service.dart';
import '../../utils/colors.dart';
import 'package:url_launcher/url_launcher.dart';

class PassengerManagementScreen extends StatefulWidget {
  final Ride ride;

  const PassengerManagementScreen({super.key, required this.ride});

  @override
  State<PassengerManagementScreen> createState() =>
      _PassengerManagementScreenState();
}

class _PassengerManagementScreenState extends State<PassengerManagementScreen>
    with SingleTickerProviderStateMixin {
  final RideStopsService _stopsService = RideStopsService();
  final TrackingService _trackingService = TrackingService();

  List<RideStop> _stops = [];
  int _currentStopIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _loadStops();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadStops() async {
    setState(() => _isLoading = true);

    try {
      // Load all stops
      final stopsResult = await _stopsService.getRideStops(widget.ride.id);

      if (stopsResult['success']) {
        _stops = stopsResult['stops'] as List<RideStop>;

        // Add final destination as last stop
        _stops.add(
          RideStop(
            bookingId: 'final',
            passengerId: 'final',
            passengerName: 'Final Destination',
            passengerPhone: null,
            passengerAvatar: null,
            type: 'final',
            lat: widget.ride.toLatitude,
            lng: widget.ride.toLongitude,
            address: widget.ride.toLocation,
            status: 'pending',
            order: _stops.length + 1,
            seatsBooked: 0,
          ),
        );

        // Find current stop index (first pending)
        _currentStopIndex = _stops.indexWhere((s) => s.status == 'pending');
        if (_currentStopIndex == -1) {
          _currentStopIndex = _stops.length - 1; // All done, show last
        }
      }

      // Get stats
      final statsResult = await _stopsService.getRideStats(widget.ride.id);
      if (statsResult['success']) {
        _stats = statsResult['stats'];
      }

      _setupMap();
    } catch (e) {
      print('❌ Error loading stops: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupMap() {
    _markers.clear();

    // Add markers for all stops
    for (int i = 0; i < _stops.length; i++) {
      final stop = _stops[i];
      
      BitmapDescriptor markerColor;
      if (stop.type == 'final') {
        markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      } else if (stop.status == 'completed' || stop.status == 'skipped') {
        markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else if (stop.isPickup) {
        markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else {
        markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      }

      _markers.add(
        Marker(
          markerId: MarkerId('${stop.type}_${stop.bookingId}_$i'),
          position: LatLng(stop.lat, stop.lng),
          icon: markerColor,
          infoWindow: InfoWindow(
            title: stop.type == 'final' 
                ? 'Final Destination' 
                : '${stop.typeDisplay}: ${stop.passengerName}',
            snippet: stop.address,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('Managing Passengers'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Map Section (30% of screen)
          _buildMapSection(),

          // Stops List (70% of screen)
          Expanded(
            child: _buildStopsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.3,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _stops.isNotEmpty
                  ? LatLng(_stops[_currentStopIndex].lat,
                      _stops[_currentStopIndex].lng)
                  : LatLng(
                      widget.ride.fromLatitude,
                      widget.ride.fromLongitude,
                    ),
              zoom: 12,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),

          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Stats Badge
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 18, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    '$_currentStopIndex/${_stops.length} Stops',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _stops.length,
      itemBuilder: (context, index) {
        final stop = _stops[index];
        final isCurrentStop = index == _currentStopIndex;
        final isCompleted = stop.status == 'completed' || stop.status == 'skipped';

        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isCurrentStop ? _pulseAnimation.value : 1.0,
              child: child,
            );
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 16),
            child: _buildStopTile(
              stop: stop,
              stopNumber: index + 1,
              totalStops: _stops.length,
              isCurrentStop: isCurrentStop,
              isCompleted: isCompleted,
              isFinalDestination: stop.type == 'final',
            ),
          ),
        );
      },
    );
  }

  /// ✅ WHITE + ORANGE FRAME for active, GRAY for completed
  Widget _buildStopTile({
    required RideStop stop,
    required int stopNumber,
    required int totalStops,
    required bool isCurrentStop,
    required bool isCompleted,
    required bool isFinalDestination,
  }) {
    // ✅ White background + Orange frame (active) / Gray (completed)
    Color backgroundColor;
    Color textColor;
    Color borderColor;
    double borderWidth;
    String badgeText;
    Color badgeColor;

    if (isCompleted) {
      // 🔘 COMPLETED: Full Gray background
      backgroundColor = Colors.grey[300]!;
      textColor = Colors.grey[700]!;
      borderColor = Colors.grey[400]!;
      borderWidth = 1.5;
      badgeText = '✓ COMPLETED';
      badgeColor = Colors.grey[600]!;
    } else if (isCurrentStop) {
      // 🟠 ACTIVE: White + Orange frame
      backgroundColor = Colors.white;
      textColor = Colors.black87;
      borderColor = Colors.orange;
      borderWidth = 3.0; // Thick orange frame
      badgeText = isFinalDestination ? '🏁 DESTINATION' : (stop.isPickup ? '🟢 PICKUP' : '🔴 DROPOFF');
      badgeColor = Colors.orange;
    } else {
      // ⚪ PENDING: White with light border
      backgroundColor = Colors.white;
      textColor = Colors.black87;
      borderColor = Colors.grey[300]!;
      borderWidth = 1.5;
      badgeText = isFinalDestination ? '🏁 DESTINATION' : (stop.isPickup ? '🟢 PICKUP' : '🔴 DROPOFF');
      badgeColor = Colors.grey[400]!;
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: isCurrentStop && !isCompleted
            ? [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Row
          Row(
            children: [
              Text(
                stopNumber == totalStops ? 'Last Stop' : '${_getOrdinal(stopNumber)} Stop',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Spacer(),
              if (isCompleted)
                Icon(Icons.check_circle, color: Colors.green, size: 24),
            ],
          ),

          SizedBox(height: 12),

          // Location
          Row(
            children: [
              Icon(Icons.location_on, size: 18, color: textColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  stop.address,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrentStop && !isCompleted ? Colors.orange.withOpacity(0.2) : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrentStop && !isCompleted ? Colors.orange : Colors.grey[300]!,
              ),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isCurrentStop && !isCompleted ? Colors.orange[700] : Colors.grey[700],
              ),
            ),
          ),

          // Passenger Info (not for final destination)
          if (!isFinalDestination) ...[
            SizedBox(height: 16),
            Row(
              children: [
                // Profile Picture
                CircleAvatar(
                  radius: 28,
                  backgroundColor: isCurrentStop && !isCompleted ? Colors.orange.withOpacity(0.2) : Colors.grey[300]!,
                  backgroundImage: stop.passengerAvatar != null
                      ? NetworkImage(stop.passengerAvatar!)
                      : null,
                  child: stop.passengerAvatar == null
                      ? Text(
                          stop.passengerName.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: isCurrentStop && !isCompleted ? Colors.orange : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.passengerName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (stop.isPickup && stop.passengerPhone != null)
                        Text(
                          stop.passengerPhone!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),

                // Contact Icons (only for active pickup)
                if (stop.isPickup && !isCompleted && isCurrentStop) ...[
                  IconButton(
                    onPressed: () => _makePhoneCall(stop.passengerPhone!),
                    icon: Icon(Icons.phone, color: Colors.orange),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.orange.withOpacity(0.1),
                      shape: CircleBorder(),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _openChat(stop.passengerId),
                    icon: Icon(Icons.chat_bubble, color: Colors.orange),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.orange.withOpacity(0.1),
                      shape: CircleBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Action Buttons (only for active stop and not completed)
          if (!isCompleted && isCurrentStop) ...[
            SizedBox(height: 16),
            if (isFinalDestination)
              // Navigate + End Ride buttons for final destination
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToStop(stop),
                      icon: Icon(Icons.navigation, size: 20),
                      label: Text(
                        'Navigate to Destination',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _endRide(widget.ride),
                      icon: Icon(Icons.stop, size: 20),
                      label: Text(
                        'End Ride',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              // Navigate, Skip, Complete buttons for pickup/dropoff
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _navigateToStop(stop),
                          icon: Icon(Icons.navigation, size: 18),
                          label: Text('Navigate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: BorderSide(color: Colors.orange, width: 2),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _skipStop(stop),
                          icon: Icon(Icons.skip_next, size: 18),
                          label: Text('Skip'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _markStopComplete(stop),
                      icon: Icon(Icons.check, size: 20),
                      label: Text(
                        stop.isPickup ? 'Picked Up' : 'Dropped Off',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  String _getOrdinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  // ==================== ACTIONS ====================

  Future<void> _navigateToStop(RideStop stop) async {
    final success = await MapsHelperService.openGoogleMapsNavigation(
      destinationLat: stop.lat,
      destinationLng: stop.lng,
      destinationName: stop.address,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Google Maps'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not make phone call'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openChat(String passengerId) async {
    // TODO: Navigate to chat screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening chat with passenger...')),
    );
  }

  Future<void> _markStopComplete(RideStop stop) async {
    if (stop.type == 'final') {
      // Final destination reached - end ride
      _showRideCompleteDialog();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(stop.isPickup ? 'Confirm Pickup' : 'Confirm Dropoff'),
        content: Text(
          stop.isPickup
              ? 'Confirm that you have picked up ${stop.passengerName}?'
              : 'Confirm that you have dropped off ${stop.passengerName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final result = stop.isPickup
          ? await _stopsService.markPickedUp(stop.bookingId)
          : await _stopsService.markDroppedOff(stop.bookingId);

      Navigator.pop(context);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              stop.isPickup
                  ? '✅ ${stop.passengerName} picked up!'
                  : '✅ ${stop.passengerName} dropped off!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        await _loadStops();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _skipStop(RideStop stop) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Skip Stop?'),
        content: Text(
          'Are you sure you want to skip ${stop.isPickup ? 'picking up' : 'dropping off'} ${stop.passengerName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Skip'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await _stopsService.skipStop(stop.bookingId, stop.type);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏭️ Stop skipped'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadStops();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRideCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Ride Complete!'),
          ],
        ),
        content: Text(
          'You have reached the final destination. End the ride now?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final result =
                  await _trackingService.endRideTracking(widget.ride.id);

              if (result['success'] && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Ride completed successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'End Ride',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }


  // ==================== END RIDE ACTION ====================

  Future<void> _endRide(Ride ride) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End Ride?'),
        content: Text('Are you sure you want to end this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('End'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await _trackingService.endRideTracking(ride.id);

      if (result['success']) {
        print('✅ Ride ended successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Ride completed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}