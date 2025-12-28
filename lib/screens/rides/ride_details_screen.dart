import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/ride.dart';
import '../../services/booking_service.dart';
import '../../config/supabase_config.dart';
import 'dart:async';

class RideDetailsScreen extends StatefulWidget {
  final Ride ride;

  const RideDetailsScreen({super.key, required this.ride});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  final BookingService _bookingService = BookingService();
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = false;
  int _selectedSeats = 1;

  // 🔥 NEW: Passenger pickup/dropoff locations
  double? _passengerPickupLat;
  double? _passengerPickupLng;
  String? _passengerPickupAddress;
  double? _passengerDropoffLat;
  double? _passengerDropoffLng;
  String? _passengerDropoffAddress;

  @override
  void initState() {
    super.initState();
    _setupMap();

    print('📍 Ride Details Screen Loaded');
    print('Ride ID: ${widget.ride.id}');
    print('Driver ID: ${widget.ride.driverId}');
    print('Current User: ${SupabaseConfig.currentUserId}');
    print('Available Seats: ${widget.ride.availableSeats}');

    // 🔥 NEW: Load passenger locations from navigation arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _passengerPickupLat = args['pickupLat'] as double?;
          _passengerPickupLng = args['pickupLng'] as double?;
          _passengerPickupAddress = args['pickupAddress'] as String?;
          _passengerDropoffLat = args['dropoffLat'] as double?;
          _passengerDropoffLng = args['dropoffLng'] as double?;
          _passengerDropoffAddress = args['dropoffAddress'] as String?;
        });

        print('🎯 Passenger locations loaded from navigation:');
        print('   Pickup: $_passengerPickupAddress ($_passengerPickupLat, $_passengerPickupLng)');
        print('   Dropoff: $_passengerDropoffAddress ($_passengerDropoffLat, $_passengerDropoffLng)');
      } else {
        print('⚠️ No passenger locations provided via navigation arguments');
      }
    });
  }

  void _setupMap() {
    _markers.add(
      Marker(
        markerId: MarkerId('start'),
        position: LatLng(
          widget.ride.fromLat ?? widget.ride.fromLatitude,
          widget.ride.fromLng ?? widget.ride.fromLongitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Pickup',
          snippet: widget.ride.fromLocation,
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
          snippet: widget.ride.toLocation,
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
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: 'Stop ${i + 1}',
              snippet: waypoint['name'] as String?,
            ),
          ),
        );
      }
    }

   if (widget.ride.routePolyline != null &&
        widget.ride.routePolyline!.isNotEmpty) {
      final routePoints = _decodePolyline(widget.ride.routePolyline!);
      _polylines.add(
        Polyline(
          polylineId: PolylineId('route'),
          points: routePoints,
          color: Color(0xFFFF4500),
          width: 5,
          // ✅ Just removed the "patterns" line - now it's solid!
        ),
      );
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

  TimeOfDay _parseTime(String? timeStr) {
    if (timeStr == null) return TimeOfDay.now();

    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return TimeOfDay.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnRide = widget.ride.driverId == SupabaseConfig.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [_buildMap(), _buildAppBar(), _buildBottomSheet(isOwnRide)],
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          widget.ride.fromLat ?? widget.ride.fromLatitude,
          widget.ride.fromLng ?? widget.ride.fromLongitude,
        ),
        zoom: 10,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        _mapController = controller;
        _fitMapBounds();
      },
    );
  }

  void _fitMapBounds() {
    if (_mapController == null) return;

    double fromLat = widget.ride.fromLat ?? widget.ride.fromLatitude;
    double fromLng = widget.ride.fromLng ?? widget.ride.fromLongitude;
    double toLat = widget.ride.toLat ?? widget.ride.toLatitude;
    double toLng = widget.ride.toLng ?? widget.ride.toLongitude;

    double minLat = fromLat < toLat ? fromLat : toLat;
    double maxLat = fromLat > toLat ? fromLat : toLat;
    double minLng = fromLng < toLng ? fromLng : toLng;
    double maxLng = fromLng > toLng ? fromLng : toLng;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  Widget _buildAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(Icons.my_location, color: Color(0xFFFF4500)),
                  onPressed: _fitMapBounds,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(bool isOwnRide) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              if (widget.ride.routeSummary != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Color(0xFFFF4500).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.route, size: 18, color: Color(0xFFFF4500)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.ride.routeSummary!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFFF4500),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Row(
                children: [
                  if (widget.ride.distance != null) ...[
                    Icon(Icons.straighten, size: 18, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      widget.ride.distance!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 20),
                  ],
                  if (widget.ride.duration != null) ...[
                    Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      widget.ride.duration!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),

              SizedBox(height: 20),

              _buildLocationCard(),

              SizedBox(height: 20),

              if (widget.ride.waypoints != null &&
                  widget.ride.waypoints!.isNotEmpty)
                _buildWaypointsSection(),

              _buildDriverCard(),

              SizedBox(height: 20),

              _buildRideDetails(),

              SizedBox(height: 20),

              _buildPreferences(),

              SizedBox(height: 20),

              if (!isOwnRide) _buildBookButton(),

              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.radio_button_checked,
                  size: 16,
                  color: Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      widget.ride.fromLocation,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 2,
                  height: 30,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      5,
                      (index) => Container(
                        width: 2,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on, size: 16, color: Colors.red),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destination',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      widget.ride.toLocation,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stops Along the Way',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        ...widget.ride.waypoints!.asMap().entries.map((entry) {
          final waypoint = entry.value;
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Colors.orange,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    waypoint['name'] as String,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        }),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDriverCard() {
    final driverName =
        widget.ride.driver?['full_name'] as String? ??
        widget.ride.driverName ??
        'Driver';
    final avatarUrl = widget.ride.driver?['avatar_url'] as String?;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFFF4500),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    driverName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      '4.8',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '• 24 trips',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Color(0xFFFF4500).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.phone, color: Color(0xFFFF4500)),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideDetails() {
    final parsedTime = _parseTime(widget.ride.departureTime);
    final departureDateTime = DateTime(
      widget.ride.departureDate.year,
      widget.ride.departureDate.month,
      widget.ride.departureDate.day,
      parsedTime.hour,
      parsedTime.minute,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ride Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        _buildDetailRow(
          Icons.calendar_today,
          'Date & Time',
          DateFormat('EEEE, d MMM • HH:mm').format(departureDateTime),
        ),
        _buildDetailRow(
          Icons.event_seat,
          'Available Seats',
          '${widget.ride.availableSeats} seat${widget.ride.availableSeats > 1 ? 's' : ''}',
        ),
        _buildDetailRow(
          Icons.attach_money,
          'Price per Seat',
          'LKR ${widget.ride.pricePerSeat.toStringAsFixed(0)}',
        ),
        if (widget.ride.vehicleModel != null)
          _buildDetailRow(
            Icons.directions_car,
            'Vehicle',
            '${widget.ride.vehicleMake ?? ''} ${widget.ride.vehicleModel}'
                .trim(),
          ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferences() {
    final preferences = <Map<String, dynamic>>[];

    if (widget.ride.allowsSmoking) {
      preferences.add({
        'icon': Icons.smoking_rooms,
        'label': 'Smoking',
        'color': Colors.orange,
      });
    }
    if (widget.ride.allowsPets) {
      preferences.add({
        'icon': Icons.pets,
        'label': 'Pets',
        'color': Colors.blue,
      });
    }
    if (widget.ride.luggageAllowed) {
      preferences.add({
        'icon': Icons.luggage,
        'label': 'Luggage',
        'color': Colors.green,
      });
    }
    if (widget.ride.instantApproval ?? false) {
      preferences.add({
        'icon': Icons.check_circle,
        'label': 'Instant',
        'color': Colors.purple,
      });
    }

    if (preferences.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferences',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: preferences.map((pref) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (pref['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (pref['color'] as Color).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    pref['icon'] as IconData,
                    size: 16,
                    color: pref['color'] as Color,
                  ),
                  SizedBox(width: 6),
                  Text(
                    pref['label'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: pref['color'] as Color,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBookButton() {
    // ✅ FIXED: Allow booking if availableSeats >= 1
    final canBook = widget.ride.availableSeats >= 1;
    final maxSeats = widget.ride.availableSeats;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Number of seats',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  // ✅ FIXED: Disable minus button if only 1 seat
                  IconButton(
                    onPressed: () {
                      if (_selectedSeats > 1) {
                        setState(() => _selectedSeats--);
                      }
                    },
                    icon: Icon(Icons.remove_circle_outline),
                    color: _selectedSeats > 1 
                        ? Color(0xFFFF4500) 
                        : Colors.grey[400],
                  ),
                  Text(
                    '$_selectedSeats',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  // ✅ FIXED: Disable plus button if max seats reached
                  IconButton(
                    onPressed: () {
                      if (_selectedSeats < maxSeats) {
                        setState(() => _selectedSeats++);
                      }
                    },
                    icon: Icon(Icons.add_circle_outline),
                    color: _selectedSeats < maxSeats 
                        ? Color(0xFFFF4500) 
                        : Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            // ✅ FIXED: Disable button if no seats available
            onPressed: (canBook && !_isLoading) ? _bookRide : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canBook ? Color(0xFFFF4500) : Colors.grey[300],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : canBook
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Book for LKR ${(widget.ride.pricePerSeat * _selectedSeats).toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward),
                        ],
                      )
                    : Text(
                        'No seats available',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
          ),
        ),
      ],
    );
  }

  Future<void> _bookRide() async {
    print('🔵 BOOK RIDE BUTTON PRESSED');

    if (SupabaseConfig.currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Please login to book a ride'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (widget.ride.driverId == SupabaseConfig.currentUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ You cannot book your own ride'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // ✅ FIXED: Proper validation with popup message
    if (widget.ride.availableSeats < _selectedSeats) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('❌ Not Enough Seats'),
            content: Text(
              'Only ${widget.ride.availableSeats} seat${widget.ride.availableSeats > 1 ? 's' : ''} available, but you requested $_selectedSeats seat${_selectedSeats > 1 ? 's' : ''}.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Auto-adjust to max available seats
                  setState(() => _selectedSeats = widget.ride.availableSeats);
                },
                child: Text('Adjust'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 🔥 VALIDATION: Check if passenger locations exist
    if (_passengerPickupLat == null || _passengerDropoffLat == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Pickup/dropoff locations missing. Please search again from home screen.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final totalPrice = widget.ride.pricePerSeat * _selectedSeats;

      print('📤 Creating booking with passenger locations...');
      print('   Pickup: $_passengerPickupAddress');
      print('   Dropoff: $_passengerDropoffAddress');

      // 🔥 CALL NEW BOOKING SERVICE WITH 9 PARAMETERS
      final result = await _bookingService.createBooking(
        rideId: widget.ride.id,
        seatsBooked: _selectedSeats,
        totalPrice: totalPrice,
        pickupLat: _passengerPickupLat!,
        pickupLng: _passengerPickupLng!,
        pickupAddress: _passengerPickupAddress ?? 'Unknown',
        dropoffLat: _passengerDropoffLat!,
        dropoffLng: _passengerDropoffLng!,
        dropoffAddress: _passengerDropoffAddress ?? 'Unknown',
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Booking successful! Your pickup/dropoff locations have been saved.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        await Future.delayed(Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        final errorMessage = result['error'] ?? 'Unknown error occurred';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMessage'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}