import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

/// 🗺️ MAPS HELPER SERVICE - UBER STYLE
/// Opens Google Maps for navigation and tracking
/// 
/// Features:
/// 1. Driver: Opens turn-by-turn navigation to destination
/// 2. Passenger: Opens map showing driver's live location
/// 3. Platform-aware (Android/iOS)
/// 4. Fallback to browser if app not installed
class MapsHelperService {
  
  // ========================================
  // 🚗 DRIVER: Open Google Maps Navigation
  // ========================================
  
  /// Opens Google Maps with turn-by-turn navigation to destination
  /// Just like Uber driver app!
  static Future<bool> openGoogleMapsNavigation({
    required double destinationLat,
    required double destinationLng,
    required String destinationName,
  }) async {
    try {
      print('🗺️ Opening Google Maps navigation to: $destinationName');
      
      final String googleMapsUrl;
      
      if (Platform.isAndroid) {
        // Android - Opens Google Maps app with navigation
        googleMapsUrl = 'google.navigation:q=$destinationLat,$destinationLng&mode=d';
      } else if (Platform.isIOS) {
        // iOS - Opens Google Maps if installed, else Apple Maps
        googleMapsUrl = 'comgooglemaps://?daddr=$destinationLat,$destinationLng&directionsmode=driving';
      } else {
        // Web fallback
        googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$destinationLat,$destinationLng';
      }

      final Uri uri = Uri.parse(googleMapsUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ Google Maps opened successfully');
        return true;
      } else {
        // Fallback to browser
        print('⚠️ Google Maps not installed, opening in browser');
        final browserUrl = 'https://www.google.com/maps/dir/?api=1&destination=$destinationLat,$destinationLng';
        final browserUri = Uri.parse(browserUrl);
        await launchUrl(browserUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      print('❌ Error opening Google Maps: $e');
      return false;
    }
  }

  // ========================================
  // 👤 PASSENGER: Open Map Showing Driver Location
  // ========================================
  
  /// Opens Google Maps showing driver's current location
  /// Updates as driver moves (passenger can see live location in Google Maps)
  static Future<bool> openGoogleMapsTracking({
    required double driverLat,
    required double driverLng,
    String? driverName,
  }) async {
    try {
      print('🗺️ Opening Google Maps to track driver at: $driverLat, $driverLng');
      
      final String googleMapsUrl;
      final String label = driverName ?? 'Driver';
      
      if (Platform.isAndroid) {
        // Android - Shows driver's location with marker
        googleMapsUrl = 'geo:$driverLat,$driverLng?q=$driverLat,$driverLng($label)';
      } else if (Platform.isIOS) {
        // iOS - Opens Google Maps or Apple Maps
        googleMapsUrl = 'comgooglemaps://?q=$driverLat,$driverLng';
      } else {
        // Web fallback
        googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$driverLat,$driverLng';
      }

      final Uri uri = Uri.parse(googleMapsUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ Google Maps opened for tracking');
        return true;
      } else {
        // Fallback to browser
        print('⚠️ Google Maps not installed, opening in browser');
        final browserUrl = 'https://www.google.com/maps/search/?api=1&query=$driverLat,$driverLng';
        final browserUri = Uri.parse(browserUrl);
        await launchUrl(browserUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      print('❌ Error opening Google Maps: $e');
      return false;
    }
  }

  // ========================================
  // 📍 Open Maps with Route (Start to End)
  // ========================================
  
  /// Opens Google Maps showing full route from start to end
  /// Useful for passengers to see the planned route
  static Future<bool> openGoogleMapsRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    String? startName,
    String? endName,
  }) async {
    try {
      print('🗺️ Opening Google Maps with route');
      
      final String googleMapsUrl;
      
      if (Platform.isAndroid) {
        // Android - Shows directions
        googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=$startLat,$startLng&destination=$endLat,$endLng&travelmode=driving';
      } else if (Platform.isIOS) {
        // iOS
        googleMapsUrl = 'comgooglemaps://?saddr=$startLat,$startLng&daddr=$endLat,$endLng&directionsmode=driving';
      } else {
        // Web
        googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=$startLat,$startLng&destination=$endLat,$endLng&travelmode=driving';
      }

      final Uri uri = Uri.parse(googleMapsUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ Google Maps opened with route');
        return true;
      } else {
        // Fallback
        final browserUrl = 'https://www.google.com/maps/dir/?api=1&origin=$startLat,$startLng&destination=$endLat,$endLng&travelmode=driving';
        final browserUri = Uri.parse(browserUrl);
        await launchUrl(browserUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      print('❌ Error opening Google Maps: $e');
      return false;
    }
  }

  // ========================================
  // 🔍 Check if Google Maps is installed
  // ========================================
  
  /// Check if Google Maps app is installed on device
  static Future<bool> isGoogleMapsInstalled() async {
    try {
      if (Platform.isAndroid) {
        final uri = Uri.parse('google.navigation:q=0,0');
        return await canLaunchUrl(uri);
      } else if (Platform.isIOS) {
        final uri = Uri.parse('comgooglemaps://');
        return await canLaunchUrl(uri);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}