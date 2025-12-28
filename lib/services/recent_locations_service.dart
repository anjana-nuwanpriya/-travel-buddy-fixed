import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentLocation {
  final String address;
  final double lat;
  final double lng;
  final DateTime selectedAt;

  RecentLocation({
    required this.address,
    required this.lat,
    required this.lng,
    required this.selectedAt,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'lat': lat,
      'lng': lng,
      'selectedAt': selectedAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory RecentLocation.fromJson(Map<String, dynamic> json) {
    return RecentLocation(
      address: json['address'] as String,
      lat: json['lat'] as double,
      lng: json['lng'] as double,
      selectedAt: DateTime.parse(json['selectedAt'] as String),
    );
  }

  @override
  String toString() => 'RecentLocation($address, $lat, $lng)';
}

class RecentLocationsService {
  static const String _storageKey = 'recent_locations';
  static const int _maxRecentLocations = 10;

  /// Save a location to recent searches
  Future<void> addRecentLocation(String address, double lat, double lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing locations
      final List<RecentLocation> locations = await getRecentLocations();

      // Remove duplicate if it exists (to move it to the top)
      locations.removeWhere((loc) =>
          loc.address.toLowerCase() == address.toLowerCase() &&
          loc.lat == lat &&
          loc.lng == lng);

      // Create new location
      final newLocation = RecentLocation(
        address: address,
        lat: lat,
        lng: lng,
        selectedAt: DateTime.now(),
      );

      // Add to beginning (most recent first)
      locations.insert(0, newLocation);

      // Keep only last N locations
      if (locations.length > _maxRecentLocations) {
        locations.removeRange(_maxRecentLocations, locations.length);
      }

      // Convert to JSON and save
      final jsonList = locations.map((loc) => loc.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));

      print('✅ Location saved to recent: $address');
      print('📊 Total recent locations: ${locations.length}');
    } catch (e) {
      print('❌ Error saving recent location: $e');
    }
  }

  /// Get all recent locations
  Future<List<RecentLocation>> getRecentLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        print('📭 No recent locations found');
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List;
      final locations = jsonList
          .map((item) => RecentLocation.fromJson(item as Map<String, dynamic>))
          .toList();

      print('📍 Loaded ${locations.length} recent locations');
      return locations;
    } catch (e) {
      print('❌ Error loading recent locations: $e');
      return [];
    }
  }

  /// Clear all recent locations
  Future<void> clearRecentLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      print('🗑️ Recent locations cleared');
    } catch (e) {
      print('❌ Error clearing recent locations: $e');
    }
  }

  /// Remove a specific location
  Future<void> removeRecentLocation(String address, double lat, double lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locations = await getRecentLocations();

      locations.removeWhere((loc) =>
          loc.address == address && loc.lat == lat && loc.lng == lng);

      if (locations.isEmpty) {
        await prefs.remove(_storageKey);
      } else {
        final jsonList = locations.map((loc) => loc.toJson()).toList();
        await prefs.setString(_storageKey, jsonEncode(jsonList));
      }

      print('✅ Location removed: $address');
    } catch (e) {
      print('❌ Error removing location: $e');
    }
  }
}