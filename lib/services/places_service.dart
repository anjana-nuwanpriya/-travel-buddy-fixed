import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacesService {
  static const String _apiKey = 'AIzaSyBaN4pYcFjAQJj5c7iHQmOze_Szhs6-x6I';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  /// Search for places using Google Places Autocomplete API
  /// Returns a list of place predictions with place_id
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    try {
      final url = Uri.parse(
        '$_baseUrl/autocomplete/json?input=$query&key=$_apiKey&components=country:lk',
      );

      print('🔍 Searching places: $query');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;

          return predictions.map((prediction) {
            // Split description into main and secondary text
            final description = prediction['description'] as String;
            final parts = description.split(', ');
            final mainText = parts.first;
            final secondaryText = parts.length > 1 ? parts.sublist(1).join(', ') : '';

            return {
              'place_id': prediction['place_id'] as String,
              'description': description,
              'main_text': mainText,
              'secondary_text': secondaryText,
            };
          }).toList();
        } else if (data['status'] == 'ZERO_RESULTS') {
          print('⚠️ No results found for: $query');
          return [];
        } else {
          print('❌ API Error: ${data['status']}');
          return [];
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error searching places: $e');
      return [];
    }
  }

  /// Get place details including coordinates from place_id
  /// ✅ THIS IS THE KEY METHOD - Gets lat/lng from place_id
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/details/json?place_id=$placeId&fields=geometry,formatted_address,name&key=$_apiKey',
      );

      print('📍 Getting place details for: $placeId');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final result = data['result'];
          final geometry = result['geometry'];
          final location = geometry['location'];

          final lat = location['lat'] as double;
          final lng = location['lng'] as double;
          final address = result['formatted_address'] as String;
          final name = result['name'] as String?;

          print('✅ Place details found:');
          print('   Name: $name');
          print('   Address: $address');
          print('   Coordinates: $lat, $lng');

          return {
            'lat': lat,
            'lng': lng,
            'address': address,
            'name': name,
          };
        } else {
          print('❌ Place Details API Error: ${data['status']}');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
      }

      return null;
    } catch (e) {
      print('❌ Error getting place details: $e');
      return null;
    }
  }

  /// Alternative: Use Text Search API for more flexible queries
  Future<List<Map<String, dynamic>>> textSearch(String query) async {
    if (query.isEmpty) return [];

    try {
      final url = Uri.parse(
        '$_baseUrl/textsearch/json?query=$query&key=$_apiKey&region=lk',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List;

          return results.map((result) {
            final geometry = result['geometry']['location'];
            return {
              'place_id': result['place_id'] as String,
              'description': result['formatted_address'] as String,
              'name': result['name'] as String,
              'lat': geometry['lat'] as double,
              'lng': geometry['lng'] as double,
            };
          }).toList();
        }
      }

      return [];
    } catch (e) {
      print('❌ Error in text search: $e');
      return [];
    }
  }
}