import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// 🚗 UBER-STYLE LOCATION SERVICE
/// Production-ready GPS tracking with smart fallbacks
class LocationService {
  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Request location permission
  Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.status;

      if (status.isGranted) {
        print('✅ Location permission already granted');
        return true;
      }

      final result = await Permission.location.request();

      if (result.isGranted) {
        print('✅ Location permission granted');
        return true;
      } else if (result.isPermanentlyDenied) {
        print('❌ Location permission permanently denied');
        await openAppSettings();
        return false;
      }

      print('❌ Location permission denied');
      return false;
    } catch (e) {
      print('❌ Error requesting location permission: $e');
      return false;
    }
  }

  // Get current location - UBER-STYLE WITH SMART FALLBACKS
  Future<Position?> getCurrentLocation() async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        return null;
      }

      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        print('❌ Location permission not granted');
        return null;
      }

      print('📍 Getting current location...');

      // ✅ Try high accuracy first (GPS + WiFi + Cell - Fused Location)
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        );
        print('✅ Location (high): ${position.latitude}, ${position.longitude}');
        return position;
      } catch (e) {
        print('⚠️ High accuracy timeout: $e');

        // Fallback: Try medium accuracy (faster)
        try {
          print('📍 Trying medium accuracy...');
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 20),
          );
          print('✅ Medium accuracy: ${position.latitude}, ${position.longitude}');
          return position;
        } catch (e2) {
          print('⚠️ Medium accuracy timeout: $e2');

          // Fallback: Try low accuracy (fastest)
          try {
            print('📍 Trying low accuracy...');
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10),
            );
            print('✅ Low accuracy: ${position.latitude}, ${position.longitude}');
            return position;
          } catch (e3) {
            print('⚠️ Low accuracy timeout: $e3');

            // Last resort: Use last known position
            print('📍 Trying last known position...');
            final lastPosition = await Geolocator.getLastKnownPosition();
            if (lastPosition != null) {
              print('✅ Using last known: ${lastPosition.latitude}, ${lastPosition.longitude}');
              return lastPosition;
            }

            print('❌ All location attempts failed');
            return null;
          }
        }
      }
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  // Get fresh location in background (non-blocking)
  Future<void> _getFreshLocationInBackground() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 60),
      );
      print('🔄 Fresh location obtained in background: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('⚠️ Background location failed: $e');
    }
  }

  // Get location - UBER-STYLE INSTANT START
  Future<Position?> getBestLocation() async {
    // 🚀 Try last known first for instant start (like Uber)
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      print('⚡ Quick start with last known: ${lastKnown.latitude}, ${lastKnown.longitude}');
      // Get fresh in background
      _getFreshLocationInBackground();
      return lastKnown;
    }

    // If no last known, get fresh
    return await getCurrentLocation();
  }

  // Stream location updates - UBER-STYLE REAL-TIME
  Stream<Position> getLocationStream() {
    print('🎯 Starting UBER-STYLE GPS stream (updates every 5 meters)');

    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, // ✅ Fused location (GPS + WiFi + Cell)
        distanceFilter: 5, // Update every 5 meters (like Uber)
        timeLimit: null, // No timeout for continuous stream
      ),
    );

    // Log when stream emits updates
    return stream.map((position) {
      print('🌊 Stream emitted: ${position.latitude}, ${position.longitude} | Accuracy: ${position.accuracy.toStringAsFixed(1)}m');
      return position;
    });
  }

  // Calculate distance between two points (in meters)
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  // Format distance for display
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  // Open location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
}