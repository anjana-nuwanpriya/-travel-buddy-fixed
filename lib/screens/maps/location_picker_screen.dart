import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../utils/colors.dart';
import '../../services/places_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String title;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.title = 'Select Location',
  });

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? mapController;
  LatLng? selectedLocation;
  String selectedAddress = 'Searching...';
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();
  
  // ✅ NEW: For place suggestions
  final PlacesService _placesService = PlacesService();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    searchController.addListener(_onSearchChanged);
  }

  /// ✅ NEW: Listen to search input changes
  void _onSearchChanged() {
    if (searchController.text.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    _searchPlaces(searchController.text);
  }

  /// ✅ NEW: Search places using PlacesService
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    final suggestions = await _placesService.searchPlaces(query);

    setState(() {
      _suggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty;
      _isSearching = false;
    });
  }

  /// ✅ NEW: Select a suggestion and get its coordinates
  Future<void> _selectSuggestion(Map<String, dynamic> place) async {
    final placeId = place['place_id'] as String?;
    final description = place['description'] as String?;

    if (placeId == null || description == null) return;

    print('📍 Selected place: $description');

    setState(() => _isSearching = true);

    // Get place details with coordinates
    final placeDetails = await _placesService.getPlaceDetails(placeId);

    setState(() => _isSearching = false);

    if (placeDetails != null) {
      final lat = placeDetails['lat'] as double?;
      final lng = placeDetails['lng'] as double?;
      final address = placeDetails['address'] as String?;

      if (lat != null && lng != null) {
        final location = LatLng(lat, lng);

        setState(() {
          selectedLocation = location;
          selectedAddress = address ?? description;
          _suggestions = [];
          _showSuggestions = false;
        });

        // Animate map to location
        mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 15));

        print('✅ Location selected from suggestions:');
        print('   Address: $selectedAddress');
        print('   Coordinates: $lat, $lng');

        // Hide keyboard
        FocusScope.of(context).unfocus();
      }
    }
  }

  Future<void> _initializeLocation() async {
    try {
      if (widget.initialLocation != null) {
        selectedLocation = widget.initialLocation;
        await _getAddressFromLatLng(selectedLocation!);
      } else {
        await _getCurrentLocation();
      }
    } catch (e) {
      // Fallback to default location (Colombo)
      selectedLocation = LatLng(6.9271, 79.8612);
      selectedAddress = 'Colombo, Sri Lanka';
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      selectedLocation = LatLng(6.9271, 79.8612); // Default to Colombo
      selectedAddress = 'Colombo, Sri Lanka';
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        selectedLocation = LatLng(6.9271, 79.8612);
        selectedAddress = 'Colombo, Sri Lanka';
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      selectedLocation = LatLng(position.latitude, position.longitude);
      await _getAddressFromLatLng(selectedLocation!);
    } catch (e) {
      selectedLocation = LatLng(6.9271, 79.8612);
      selectedAddress = 'Colombo, Sri Lanka';
    }
  }

  Future<void> _getAddressFromLatLng(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          selectedAddress = _formatAddress(place);
        });
      }
    } catch (e) {
      setState(() {
        selectedAddress = 'Unknown location';
      });
    }
  }

  String _formatAddress(Placemark place) {
    String address = '';
    if (place.street?.isNotEmpty == true) address += '${place.street}, ';
    if (place.locality?.isNotEmpty == true) address += '${place.locality}, ';
    if (place.administrativeArea?.isNotEmpty == true) {
      address += '${place.administrativeArea}, ';
    }
    if (place.country?.isNotEmpty == true) address += place.country!;
    return address.isEmpty ? 'Unknown location' : address;
  }

  void _onMapTap(LatLng location) {
    setState(() {
      selectedLocation = location;
      selectedAddress = 'Getting address...';
      _suggestions = [];
      _showSuggestions = false;
    });
    _getAddressFromLatLng(location);
  }

  Future<void> _searchLocation() async {
    final query = searchController.text.trim();
    if (query.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = LatLng(
          locations.first.latitude,
          locations.first.longitude,
        );

        setState(() {
          selectedLocation = location;
          _suggestions = [];
          _showSuggestions = false;
        });

        mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 15));

        await _getAddressFromLatLng(location);

        // Hide keyboard
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location not found'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: selectedLocation != null ? _confirmLocation : null,
            child: Text(
              'DONE',
              style: TextStyle(
                color: selectedLocation != null
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Map (full screen)
                Column(
                  children: [
                    // Map
                    Expanded(
                      child: GoogleMap(
                        onMapCreated: (controller) => mapController = controller,
                        initialCameraPosition: CameraPosition(
                          target: selectedLocation ?? LatLng(6.9271, 79.8612),
                          zoom: 15,
                        ),
                        onTap: _onMapTap,
                        markers: selectedLocation != null
                            ? {
                                Marker(
                                  markerId: MarkerId('selected'),
                                  position: selectedLocation!,
                                  draggable: true,
                                  onDragEnd: _onMapTap,
                                ),
                              }
                            : {},
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                      ),
                    ),

                    // Selected location info at bottom
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selected Location',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      selectedAddress,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ✅ Search bar and suggestions overlay (on top)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Search TextField
                        TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Search for a place',
                            prefixIcon: Icon(Icons.search),
                            suffixIcon: _isSearching
                                ? Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                : searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear),
                                        onPressed: () {
                                          searchController.clear();
                                          setState(() {
                                            _suggestions = [];
                                            _showSuggestions = false;
                                          });
                                        },
                                      )
                                    : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: AppColors.divider),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: AppColors.divider),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _searchLocation(),
                        ),

                        // ✅ Suggestions dropdown list (overlay on map)
                        if (_showSuggestions && _suggestions.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: BoxConstraints(
                              maxHeight: 300,
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _suggestions.length,
                              itemBuilder: (context, index) {
                                final suggestion = _suggestions[index];
                                return ListTile(
                                  leading: Icon(
                                    Icons.location_on,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  title: Text(
                                    suggestion['main_text'] ??
                                        suggestion['description']!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    suggestion['secondary_text'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () =>
                                      _selectSuggestion(suggestion),
                                );
                              },
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

  void _confirmLocation() {
    if (selectedLocation != null) {
      Navigator.pop(context, {
        'address': selectedAddress,
        'lat': selectedLocation!.latitude,
        'lng': selectedLocation!.longitude,
      });
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}