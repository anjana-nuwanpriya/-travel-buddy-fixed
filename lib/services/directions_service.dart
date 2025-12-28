import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsService {
  static const String _apiKey = 'AIzaSyBaN4pYcFjAQJj5c7iHQmOze_Szhs6-x6I';
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Get directions between two points with optional waypoints
  /// Returns route polyline, distance, duration, and route summary
  Future<Map<String, dynamic>?> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    List<Map<String, double>>? waypoints, // [{lat: ..., lng: ...}, ...]
  }) async {
    try {
      // Build waypoints string if provided
      String waypointsStr = '';
      if (waypoints != null && waypoints.isNotEmpty) {
        final waypointCoords = waypoints
            .map((w) => '${w['lat']},${w['lng']}')
            .join('|');
        waypointsStr = '&waypoints=$waypointCoords';
      }

      final url = Uri.parse(
        '$_baseUrl?origin=$originLat,$originLng'
        '&destination=$destLat,$destLng'
        '$waypointsStr'
        '&key=$_apiKey'
        '&region=lk'
        '&alternatives=false', // Get single best route
      );

      print('🗺️ Fetching directions from Google Maps API...');
      print('   Origin: $originLat, $originLng');
      print('   Destination: $destLat, $destLng');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Extract polyline (encoded)
          final encodedPolyline =
              route['overview_polyline']['points'] as String;

          // Extract distance and duration
          final distance = leg['distance']['text'] as String; // e.g., "245 km"
          final duration =
              leg['duration']['text'] as String; // e.g., "4 hours 56 mins"

          // Extract route summary (e.g., "via A1")
          final routeSummary = route['summary'] as String? ?? '';

          print('✅ Route fetched successfully:');
          print('   Distance: $distance');
          print('   Duration: $duration');
          print('   Polyline length: ${encodedPolyline.length} chars');
          print('   Summary: $routeSummary');

          return {
            'success': true,
            'polyline': encodedPolyline,
            'distance': distance,
            'duration': duration,
            'routeSummary': routeSummary,
            'distanceValue': leg['distance']['value'], // meters
            'durationValue': leg['duration']['value'], // seconds
          };
        } else {
          print('❌ Directions API Error: ${data['status']}');
          if (data['error_message'] != null) {
            print('   Error message: ${data['error_message']}');
          }
          return {
            'success': false,
            'error': 'Could not find route: ${data['status']}',
          };
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to fetch directions: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error getting directions: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Decode polyline string into list of LatLng coordinates
  /// This converts Google's encoded polyline into actual map coordinates
  List<LatLng> decodePolyline(String encoded) {
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

  /// Get route polyline as LatLng list (decoded)
  Future<List<LatLng>?> getRoutePoints({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    List<Map<String, double>>? waypoints,
  }) async {
    final result = await getDirections(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      waypoints: waypoints,
    );

    if (result != null && result['success'] == true) {
      final encodedPolyline = result['polyline'] as String;
      return decodePolyline(encodedPolyline);
    }

    return null;
  }
}
