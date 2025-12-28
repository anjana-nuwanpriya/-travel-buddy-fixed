import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RouteSelectionScreen extends StatefulWidget {
  final String fromLocation;
  final String toLocation;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;

  const RouteSelectionScreen({
    super.key,
    required this.fromLocation,
    required this.toLocation,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
  });

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  List<LatLng> _routePoints = [];
  final List<LatLng> _waypoints = [];

  // Store encoded polyline and route summary
  String? _encodedPolyline;
  String? _routeSummary;

  String? _distance;
  String? _duration;
  bool _isLoading = true;

  // New: store all routes returned by API
  List<dynamic> _allRoutes = [];
  int _selectedRouteIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeRoute();
  }

  Future<void> _initializeRoute() async {
    // Add markers for start and end
    _addMarkers();

    // Get route from Google Directions API
    await _getRoute();

    setState(() => _isLoading = false);
  }

  void _addMarkers() {
    // Clear existing markers
    _markers.clear();

    if (widget.fromLat != null && widget.fromLng != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('start'),
          position: LatLng(widget.fromLat!, widget.fromLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: 'Start', snippet: widget.fromLocation),
        ),
      );
    }

    if (widget.toLat != null && widget.toLng != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('end'),
          position: LatLng(widget.toLat!, widget.toLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: widget.toLocation,
          ),
        ),
      );
    }

    // Add waypoint markers
    for (int i = 0; i < _waypoints.length; i++) {
      _markers.add(
        Marker(
          markerId: MarkerId('waypoint_$i'),
          position: _waypoints[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: 'Stop ${i + 1}'),
          draggable: true,
          onDragEnd: (newPosition) {
            setState(() {
              _waypoints[i] = newPosition;
            });
            _getRoute();
          },
        ),
      );
    }
  }

  Future<void> _getRoute() async {
    if (widget.fromLat == null || widget.toLat == null) return;

    setState(() => _isLoading = true);

    try {
      // Google Directions API endpoint
      final origin = '${widget.fromLat},${widget.fromLng}';
      final destination = '${widget.toLat},${widget.toLng}';

      // Build waypoints string
      String waypointsStr = '';
      if (_waypoints.isNotEmpty) {
        waypointsStr =
            '&waypoints=${_waypoints.map((wp) => '${wp.latitude},${wp.longitude}').join('|')}';
      }

      final apiKey = 'AIzaSyBaN4pYcFjAQJj5c7iHQmOze_Szhs6-x6I';
      final url =
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$origin'
          '&destination=$destination'
          '$waypointsStr'
          '&alternatives=true'
          '&key=$apiKey';

      print('🗺️ Fetching route from Google Maps...');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
          // Store all routes (up to 3 alternative routes from Google)
          _allRoutes = data['routes'];
          _selectedRouteIndex = 0; // default to first (best) route

          // Apply selected route (sets distance/duration/encoded polyline & decoded points)
          _applySelectedRoute();

          // Build polylines for display
          _buildPolylinesFromAllRoutes();

          // Fit bounds to show selected route
          _fitBounds();

          setState(() => _isLoading = false);

          print('✅ Routes parsed: ${_allRoutes.length}');
          for (int i = 0; i < _allRoutes.length; i++) {
            final r = _allRoutes[i];
            final overview = (r['overview_polyline']?['points'] as String?) ?? '';
            final legs = r['legs'] as List<dynamic>?;
            final dist = (legs != null && legs.isNotEmpty) ? (legs[0]['distance']?['text'] as String?) : null;
            final dur = (legs != null && legs.isNotEmpty) ? (legs[0]['duration']?['text'] as String?) : null;
            print('  Route $i: dist=$dist, dur=$dur, summary=${r['summary']}, polylineLen=${overview.length}');
          }
        } else {
          print('❌ Directions API error: ${data['status']}');
          if (data['error_message'] != null) {
            print('   Error message: ${data['error_message']}');
          }
          setState(() => _isLoading = false);
        }
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error getting route: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Apply the currently selected route's data into fields
  void _applySelectedRoute() {
    if (_allRoutes.isEmpty) return;
    if (_selectedRouteIndex < 0 || _selectedRouteIndex >= _allRoutes.length) _selectedRouteIndex = 0;

    final selected = _allRoutes[_selectedRouteIndex];
    final overview = (selected['overview_polyline']?['points'] as String?) ?? '';
    final legs = (selected['legs'] as List<dynamic>?);
    String? distText;
    String? durText;
    if (legs != null && legs.isNotEmpty) {
      try {
        distText = legs[0]['distance']?['text'] as String?;
        durText = legs[0]['duration']?['text'] as String?;
      } catch (_) {
        distText = null;
        durText = null;
      }
    }

    _encodedPolyline = overview;
    _routeSummary = selected['summary'] ?? '';
    _distance = distText;
    _duration = durText;

    if (_encodedPolyline != null && _encodedPolyline!.isNotEmpty) {
      _routePoints = _decodePolyline(_encodedPolyline!);
    } else {
      _routePoints = [];
    }
  }

  /// Build polylines for every parsed route.
  /// Selected route appears as thick solid orange; others are thinner light-orange solid lines.
  void _buildPolylinesFromAllRoutes() {
    final Set<Polyline> newPolylines = {};

    // Build alternatives first so selected can be drawn on top
    for (int i = 0; i < _allRoutes.length; i++) {
      final route = _allRoutes[i];
      final encoded = (route['overview_polyline']?['points'] as String?) ?? '';
      if (encoded.isEmpty) continue;
      final points = _decodePolyline(encoded);

      if (i == _selectedRouteIndex) continue; // skip selected here (draw later on top)

      // Alternative route style: thin, light-orange SOLID line
      newPolylines.add(
        Polyline(
          polylineId: PolylineId('route_alt_$i'),
          points: points,
          color: const Color(0xFFFFB366), // light orange
          width: 4,
          patterns: const [], // ✅ SOLID line (empty patterns array = solid)
          consumeTapEvents: true,
          onTap: () {
            _onRouteTapped(i);
          },
        ),
      );
    }

    // Now add the selected route, drawn last so it appears on top
    if (_selectedRouteIndex >= 0 && _selectedRouteIndex < _allRoutes.length) {
      final selRoute = _allRoutes[_selectedRouteIndex];
      final selEncoded = (selRoute['overview_polyline']?['points'] as String?) ?? '';
      if (selEncoded.isNotEmpty) {
        final selPoints = _decodePolyline(selEncoded);
        newPolylines.add(
          Polyline(
            polylineId: PolylineId('route_sel_$_selectedRouteIndex'),
            points: selPoints,
            color: const Color(0xFFFF4500), // main bright orange
            width: 7,
            patterns: const [], // ✅ SOLID line (no dashes)
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            consumeTapEvents: true,
            onTap: () {
              _onRouteTapped(_selectedRouteIndex);
            },
          ),
        );
      }
    }

    setState(() {
      _polylines = newPolylines;
    });
  }

  /// Called when user taps on a polyline route to select it
  void _onRouteTapped(int index) {
    if (index < 0 || index >= _allRoutes.length) return;

    // Update selected index
    _selectedRouteIndex = index;

    // Apply selected route data
    _applySelectedRoute();

    // Rebuild polylines so selected becomes highlighted and drawn on top
    _buildPolylinesFromAllRoutes();

    // Fit map to the newly selected route
    _fitBounds();

    // Update UI
    setState(() {});
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

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  void _fitBounds() {
    // Prefer fitting to selected route points
    final pointsToFit = _routePoints;
    if (pointsToFit.isEmpty || _mapController == null) return;

    double minLat = pointsToFit[0].latitude;
    double maxLat = pointsToFit[0].latitude;
    double minLng = pointsToFit[0].longitude;
    double maxLng = pointsToFit[0].longitude;

    for (var point in pointsToFit) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  void _addWaypoint() {
    if (_routePoints.isEmpty) return;

    // Add waypoint in the middle of the route
    final middleIndex = _routePoints.length ~/ 2;
    final waypointPosition = _routePoints[middleIndex];

    setState(() {
      _waypoints.add(waypointPosition);
    });

    _addMarkers();
    _getRoute();
  }

  void _confirmRoute() {
    // ✅ CRITICAL FIX: Check if polyline exists
    if (_encodedPolyline == null || _encodedPolyline!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Route not loaded yet. Please wait...'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Format waypoints for database
    final formattedWaypoints = _waypoints
        .map(
          (wp) => {
            'lat': wp.latitude,
            'lng': wp.longitude,
            'name': 'Waypoint ${_waypoints.indexOf(wp) + 1}',
          },
        )
        .toList();

    print('');
    print('========================================');
    print('✅ CONFIRMING ROUTE - FINAL DATA:');
    print('========================================');
    print('📍 Polyline length: ${_encodedPolyline!.length} characters');
    print(
      '📍 Polyline preview: ${_encodedPolyline!.substring(0, min(100, _encodedPolyline!.length))}...',
    );
    print('📏 Distance: $_distance');
    print('⏱️  Duration: $_duration');
    print('🛣️  Summary: $_routeSummary');
    print('🚏 Waypoints: ${formattedWaypoints.length}');
    print('========================================');
    print('');

    // ✅ CRITICAL: Return with 'summary' key (not 'routeSummary')
    Navigator.pop(context, {
      'polyline': _encodedPolyline, // ✅ Encoded polyline string
      'waypoints': formattedWaypoints, // ✅ Properly formatted waypoints
      'distance': _distance, // ✅ Distance text
      'duration': _duration, // ✅ Duration text
      'summary': _routeSummary, // ✅ MUST be 'summary' not 'routeSummary'!
    });
  }

  int min(int a, int b) => a < b ? a : b;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          widget.fromLat != null && widget.toLat != null
              ? GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(widget.fromLat!, widget.fromLng!),
                    zoom: 10,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_routePoints.isNotEmpty) {
                      Future.delayed(Duration(milliseconds: 500), () {
                        _fitBounds();
                      });
                    }
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                )
              : Center(child: Text('Location data not available')),

          // Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 16,
                left: 8,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white.withOpacity(0.0)],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: _isLoading
                        ? Text('Loading route...')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${widget.fromLocation.split(',').first} → ${widget.toLocation.split(',').first}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_distance != null && _duration != null)
                                Text(
                                  '$_distance • $_duration',
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
          ),

          // Bottom Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(24),
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What is your route?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Route Info
                      if (_distance != null && _duration != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.straighten, size: 18, color: Colors.grey),
                                SizedBox(width: 6),
                                Text(
                                  'Distance: $_distance',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 18, color: Colors.grey),
                                SizedBox(width: 6),
                                Text(
                                  'Duration: $_duration',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 14),
                      ],

                      // Show available routes
                      if (!_isLoading && _allRoutes.isNotEmpty) ...[
                        Text(
                          'Available Routes (${_allRoutes.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _allRoutes.length,
                            itemBuilder: (context, index) {
                              final isSelected = index == _selectedRouteIndex;

                              return GestureDetector(
                                onTap: () => _onRouteTapped(index),
                                child: Container(
                                  margin: EdgeInsets.only(right: 8),
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Color(0xFFFF4500) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(color: Color(0xFFFF4500), width: 2)
                                        : Border.all(color: Colors.grey[300]!, width: 1),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Route ${index + 1}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 14),
                      ],

                      // Add Waypoint Button
                      if (!_isLoading && _encodedPolyline != null)
                        OutlinedButton.icon(
                          onPressed: _addWaypoint,
                          icon: Icon(Icons.add_location_outlined),
                          label: Text('Add a stop along the way'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Color(0xFFFF4500),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),

                      SizedBox(height: 16),

                      // Confirm Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _confirmRoute,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFFF4500),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Confirm Route',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward, size: 20),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF4500),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Calculating route...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}