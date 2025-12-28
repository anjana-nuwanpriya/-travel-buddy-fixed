import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../services/places_service.dart';
import '../../../services/location_service.dart';
import '../../../services/recent_locations_service.dart';
import '../../../utils/colors.dart';
import '../../maps/location_picker_screen.dart';

class LocationSelectionStep extends StatefulWidget {
  final String title;
  final Function(String location, double? lat, double? lng) onLocationSelected;
  final int maxRecentItems; // ✅ Now used as upper limit, not fixed

  const LocationSelectionStep({
    super.key,
    required this.title,
    required this.onLocationSelected,
    this.maxRecentItems = 10, // Default upper limit
  });

  @override
  State<LocationSelectionStep> createState() => _LocationSelectionStepState();
}

class _LocationSelectionStepState extends State<LocationSelectionStep> {
  final TextEditingController _searchController = TextEditingController();
  final PlacesService _placesService = PlacesService();
  final LocationService _locationService = LocationService();
  final RecentLocationsService _recentLocationsService = RecentLocationsService();

  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _recentLocations = [];
  bool _showSuggestions = false;
  bool _isLoadingLocation = false;
  bool _isSearching = false;
  Position? _currentPosition;
  
  int _dynamicRecentCount = 4; // ✅ Will be calculated based on screen space

  @override
  void initState() {
    super.initState();
    _loadRecentLocations();
    _getCurrentLocationSilently();
    _searchController.addListener(_onSearchChanged);
    
    // ✅ Calculate available space after widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateDynamicRecentCount();
    });
  }

  /// ✅ NEW: Calculate how many recent items can fit based on screen size
  void _calculateDynamicRecentCount() {
    if (!mounted) return;
    
    // Get screen height and account for AppBar + search box + quick options
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = 60.0; // AppBar height
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final searchAndTitleHeight = 200.0; // Title + search box + spacing
    final quickOptionsHeight = 160.0; // Use current location + Pick on map + dividers
    final recentHeaderHeight = 40.0; // "Recent" text + spacing
    
    // Available height for recent locations
    final availableHeight = screenHeight - appBarHeight - statusBarHeight - searchAndTitleHeight - quickOptionsHeight - recentHeaderHeight;
    
    // Each recent location tile is ~70 pixels (icon + text + padding)
    final itemHeight = 70.0;
    final calculatedCount = (availableHeight / itemHeight).floor();
    
    // Clamp between 1 and maxRecentItems
    final finalCount = calculatedCount.clamp(1, widget.maxRecentItems);
    
    setState(() {
      _dynamicRecentCount = finalCount;
    });
    
    print('📏 Screen Height: ${screenHeight.toStringAsFixed(0)}');
    print('📏 Available Height: ${availableHeight.toStringAsFixed(0)}');
    print('📏 Calculated Recent Count: $calculatedCount -> Final: $finalCount');
  }

  /// ✅ UPDATED: Load recent locations dynamically
  Future<void> _loadRecentLocations() async {
    try {
      final locations = await _recentLocationsService.getRecentLocations();
      
      // ✅ Load ALL from service, but will display only what fits
      final allLocations = locations.take(widget.maxRecentItems).toList();
      
      setState(() {
        _recentLocations = allLocations
            .map((loc) => {
              'name': _cleanAddressName(loc.address),
              'address': _cleanAddress(loc.address),
              'lat': loc.lat,
              'lng': loc.lng,
            })
            .toList();
      });

      print('📍 Loaded ${_recentLocations.length} recent locations (will show dynamically)');
    } catch (e) {
      print('❌ Error loading recent locations: $e');
    }
  }

  /// Remove Plus Code from address
  String _cleanAddress(String address) {
    List<String> parts = address.split(',');
    
    if (parts.isNotEmpty && parts[0].contains('+')) {
      return parts.sublist(1).join(',').trim();
    }
    
    return address.trim();
  }

  /// Extract just the location name
  String _cleanAddressName(String address) {
    final cleaned = _cleanAddress(address);
    final parts = cleaned.split(',');
    return parts.first.trim();
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    _searchPlaces(_searchController.text);
  }

  Future<void> _getCurrentLocationSilently() async {
    try {
      final position = await _locationService.getBestLocation();
      if (position != null) {
        setState(() {
          _currentPosition = position;
        });
        print('✅ Current position cached: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      print('⚠️ Could not get current position: $e');
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final suggestions = await _placesService.searchPlaces(query);

    setState(() {
      _suggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty;
      _isSearching = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission denied');
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      Position? position = _currentPosition;
      
      position ??= await _locationService.getCurrentLocation();

      if (position == null) {
        _showError('Could not get current location');
        setState(() => _isLoadingLocation = false);
        return;
      }

      String address = 'Current Location';
      
      try {
        final placemarks = await _placesService.textSearch(
          '${position.latitude},${position.longitude}',
        );
        if (placemarks.isNotEmpty) {
          address = placemarks.first['description'] ?? address;
        }
      } catch (e) {
        address = 'Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
      }

      print('✅ Current location selected:');
      print('   Address: $address');
      print('   Coordinates: ${position.latitude}, ${position.longitude}');

      await _recentLocationsService.addRecentLocation(
        address,
        position.latitude,
        position.longitude,
      );

      widget.onLocationSelected(address, position.latitude, position.longitude);
    } catch (e) {
      _showError('Could not get current location: $e');
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _selectSearchResult(Map<String, dynamic> place) async {
    final placeId = place['place_id'] as String?;
    final description = place['description'] as String?;

    if (placeId == null || description == null) return;

    print('📍 Selected place from search: $description');

    setState(() => _isSearching = true);

    final placeDetails = await _placesService.getPlaceDetails(placeId);

    setState(() => _isSearching = false);

    if (placeDetails != null) {
      final lat = placeDetails['lat'] as double?;
      final lng = placeDetails['lng'] as double?;
      final address = placeDetails['address'] as String?;

      if (lat != null && lng != null) {
        print('✅ Coordinates obtained: $lat, $lng');

        await _recentLocationsService.addRecentLocation(
          address ?? description,
          lat,
          lng,
        );

        widget.onLocationSelected(address ?? description, lat, lng);
      } else {
        print('❌ No coordinates found');
        _showError('Could not get location coordinates');
      }
    } else {
      print('❌ Failed to get place details');
      _showError('Could not get location details');
    }
  }

  void _selectRecentLocation(Map<String, dynamic> location) {
    final name = location['name'] as String;
    final address = location['address'] as String;
    final lat = location['lat'] as double;
    final lng = location['lng'] as double;

    print('✅ Recent location selected: $address');

    widget.onLocationSelected(address, lat, lng);
  }

  Future<void> _openMapPicker() async {
    Position? position = _currentPosition;
    
    if (position == null) {
      setState(() => _isLoadingLocation = true);
      position = await _locationService.getCurrentLocation();
      setState(() => _isLoadingLocation = false);
    }

    LatLng? initialLocation;
    if (position != null) {
      initialLocation = LatLng(position.latitude, position.longitude);
      print('📍 Opening map at current location');
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          title: widget.title,
          initialLocation: initialLocation,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final address = result['address'] as String?;
      final lat = result['lat'] as double?;
      final lng = result['lng'] as double?;

      if (address != null && lat != null && lng != null) {
        print('✅ Location selected from map: $address');

        await _recentLocationsService.addRecentLocation(address, lat, lng);

        widget.onLocationSelected(address, lat, lng);
      }
    }
  }

  Future<void> _clearRecentLocations() async {
    await _recentLocationsService.clearRecentLocations();
    await _loadRecentLocations();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Recent locations cleared')),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 32),

            // Search Field
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[400]),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchPlaces,
                      decoration: InputDecoration(
                        hintText: 'Search location',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  if (_isSearching)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  if (_searchController.text.isNotEmpty && !_isSearching)
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[400]),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _suggestions = [];
                          _showSuggestions = false;
                        });
                      },
                    ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Suggestions or Recent Locations
            _showSuggestions && _suggestions.isNotEmpty
                ? _buildSuggestionsList()
                : _buildQuickOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return ListTile(
          leading: Icon(Icons.location_on, color: AppColors.primary),
          title: Text(
            suggestion['main_text'] ?? suggestion['description']!,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            suggestion['secondary_text'] ?? '',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: () => _selectSearchResult(suggestion),
        );
      },
    );
  }

  Widget _buildQuickOptions() {
    // ✅ Get only the recent items that fit on screen
    final visibleRecents = _recentLocations.take(_dynamicRecentCount).toList();
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Use Current Location
        ListTile(
          leading: Icon(Icons.my_location, color: AppColors.primary),
          title: Text(
            'Use current location',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: _isLoadingLocation
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: _isLoadingLocation ? null : _useCurrentLocation,
        ),

        Divider(),

        // Pick on Map
        ListTile(
          leading: Icon(Icons.map, color: AppColors.primary),
          title: Text(
            'Pick location on map',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: _openMapPicker,
        ),

        Divider(),

        // Recent header with clear button
        if (visibleRecents.isNotEmpty) ...[
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: _clearRecentLocations,
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
        ],

        // ✅ Show only visibleRecents
        ...List.generate(visibleRecents.length, (index) {
          final location = visibleRecents[index];
          return ListTile(
            leading: Icon(Icons.access_time, color: Colors.grey),
            title: Text(
              location['name'],
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              location['address'],
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
            onTap: () => _selectRecentLocation(location),
          );
        }),
      ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}