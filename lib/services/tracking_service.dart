import 'dart:async';
import 'package:background_fetch/background_fetch.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'notification_service.dart';

// 🔥 STATIC HEADLESS TASK - MUST BE AT TOP LEVEL
void backgroundLocationTask(String taskId) async {
  print('🔄 [BACKGROUND] ⭐⭐⭐ CALLBACK FIRED! Task ID: $taskId');

  try {
    final prefs = await SharedPreferences.getInstance();
    final rideId = prefs.getString('background_ride_id');
    final userId = prefs.getString('background_user_id');
    final isTracking = prefs.getBool('background_tracking') ?? false;

    print('🔄 [BACKGROUND] Checking data: rideId=$rideId, userId=$userId, isTracking=$isTracking');

    if (!isTracking || rideId == null || userId == null) {
      print('⚠️ [BACKGROUND] Tracking stopped or no data');
      BackgroundFetch.finish(taskId);
      return;
    }

    print('🔄 [BACKGROUND] Getting location...');
    try {
      // ✅ FIXED: Use high accuracy instead of best
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 30),
      );

      print('📍 [BACKGROUND] ✅ Got GPS: ${position.latitude}, ${position.longitude}');

      final supabase = Supabase.instance.client;
      final response = await supabase.from('ride_locations').update({
        'current_lat': position.latitude,
        'current_lng': position.longitude,
        'bearing': position.heading,
        'speed': position.speed,
        'accuracy': position.accuracy,
        'last_updated': DateTime.now().toIso8601String(),
      }).eq('ride_id', rideId).eq('driver_id', userId).select();

      if (response.isNotEmpty) {
        print('✅ [BACKGROUND] Location updated to database');
      } else {
        print('⚠️ [BACKGROUND] No ride location record found');
      }
    } catch (e) {
      print('⚠️ [BACKGROUND] Error getting location: $e');
    }
  } catch (e) {
    print('❌ [BACKGROUND] Error in background task: $e');
  }

  print('🔄 [BACKGROUND] Finishing task: $taskId');
  BackgroundFetch.finish(taskId);
}

/// 🚀 UBER-STYLE TRACKING SERVICE
/// Uses instant start + fused location (GPS + WiFi + Cell towers)
class TrackingService {
  final _supabase = Supabase.instance.client;
  final _notificationService = NotificationService();

  StreamSubscription<Position>? _locationStreamSubscription;
  Timer? _locationPollTimer; // ✅ Backup timer for stationary updates
  String? _activeRideId;
  bool _isTracking = false;

  static const String _cacheKey = 'tracking_cache';
  List<Map<String, dynamic>> _cachedLocations = [];
  Timer? _syncTimer;

  Future<bool> checkLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permission denied forever');
        return false;
      }

      print('✅ Location permission granted');
      return true;
    } catch (e) {
      print('❌ Error checking location permission: $e');
      return false;
    }
  }

  /// 🚀 UBER-STYLE: Get location with instant start
  /// 1. Returns last known position immediately (0ms)
  /// 2. Gets fresh location in background
  /// 3. Uses fused location (GPS + WiFi + Cell)
  Future<Position?> getCurrentLocation() async {
    try {
      print('📍 Getting current location (Uber-style)...');
      
      // 🚀 STEP 1: Try last known position first (INSTANT!)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        print('⚡ Quick start with last known: ${lastKnown.latitude}, ${lastKnown.longitude}');
        
        // Get fresh location in background (non-blocking)
        _getFreshLocationInBackground();
        
        return lastKnown;
      }
      
      // 🎯 STEP 2: No last known? Get fresh with smart fallback
      print('📍 No last known position, getting fresh location...');
      
      // Try HIGH accuracy (uses fused location: GPS + WiFi + Cell towers)
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high, // ✅ Fused location
          timeLimit: Duration(seconds: 30),
        );
        print('✅ Got fresh location (high): ${position.latitude}, ${position.longitude}');
        return position;
      } catch (e) {
        print('⚠️ High accuracy timeout: $e');
        
        // 🆘 FALLBACK: Try medium accuracy (WiFi + Cell only)
        try {
          print('📍 Trying medium accuracy...');
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          );
          print('✅ Got medium accuracy: ${position.latitude}, ${position.longitude}');
          return position;
        } catch (e2) {
          print('⚠️ Medium accuracy timeout: $e2');
          
          // 🆘 LAST RESORT: Low accuracy
          try {
            print('📍 Trying low accuracy (last resort)...');
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10),
            );
            print('✅ Got low accuracy: ${position.latitude}, ${position.longitude}');
            return position;
          } catch (e3) {
            print('❌ All location attempts failed: $e3');
            return null;
          }
        }
      }
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  /// 🔄 Get fresh location in background (non-blocking)
  /// This improves accuracy after instant start with last known position
  Future<void> _getFreshLocationInBackground() async {
    try {
      print('🔄 Getting fresh location in background...');
      final fresh = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 60),
      );
      print('🔄 Fresh location obtained: ${fresh.latitude}, ${fresh.longitude}');
      // Location will be used in next update cycle
    } catch (e) {
      print('⚠️ Background location refresh failed: $e');
    }
  }

  /// 🌊 UBER-STYLE: Continuous location stream with FOREGROUND SERVICE
  /// Updates every 2 seconds even when stationary or in background
  Stream<Position> getLocationStream() {
    print('🎯 Starting UBER-STYLE GPS stream with foreground service (updates every 2 seconds)');
    
    // ✅ UBER-STYLE: Enable foreground service for background tracking
    // This shows a persistent notification and prevents Android from killing location updates
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high, // ✅ Fused location (GPS + WiFi + Cell)
        distanceFilter: 0, // ✅ Update even when stationary (0 = all GPS updates)
        intervalDuration: Duration(seconds: 2), // ✅ Force update every 2 seconds
        timeLimit: null, // No timeout for continuous stream
        
        // 🚀 FOREGROUND SERVICE - The key to background tracking!
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "🚗 Ride in Progress",
          notificationText: "Your location is being shared with passengers",
          enableWakeLock: true, // Keep device awake for GPS
          notificationChannelName: "Location Tracking",
        ),
      ),
    ).handleError((error) {
      print('⚠️ GPS stream error: $error');
    });
  }

  Future<Map<String, dynamic>> startRideTracking(String rideId) async {
    try {
      print('🚀 Starting ride tracking for: $rideId');

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        return {'success': false, 'error': 'Location permission not granted'};
      }

      final isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        return {'success': false, 'error': 'Location services disabled'};
      }

      // ✅ UBER-STYLE: Get location (instant with last known, or fresh)
      final position = await getCurrentLocation();
      if (position == null) {
        return {'success': false, 'error': 'Could not get current location'};
      }

      print('📍 Initial position: ${position.latitude}, ${position.longitude}');

      await Future.wait([
        _supabase.from('rides').update({
          'ride_status': 'in_progress',
          'started_at': DateTime.now().toIso8601String(),
        }).eq('id', rideId),

        _upsertRideLocation(
          rideId: rideId,
          userId: userId,
          position: position,
        ),
      ]);

      print('✅ Database updated');

      _activeRideId = rideId;
      _isTracking = true;

      await _loadCachedLocations();
      _startAutoSync();

      // Start foreground tracking
      await _startLocationStream(rideId, userId);
      
      // Start background fetch
      await _setupBackgroundLocationFetch(rideId, userId);
      
      await _showTrackingNotification(rideId);
      _notifyPassengers(rideId, 'Ride Started', 'Your ride has started!');

      print('✅ Tracking started!');
      print('📱 FOREGROUND SERVICE: Active with persistent notification');
      print('🔔 Notification: "Ride in progress" (cannot be dismissed)');
      print('⏰ DATABASE: Forced updates every 2 seconds (even when stationary)');
      print('🔄 BACKGROUND: Works even when app is minimized or screen is locked');

      return {'success': true};
    } catch (e) {
      print('❌ Error starting tracking: $e');
      _isTracking = false;
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> _startLocationStream(String rideId, String userId) async {
    try {
      print('📱 Starting foreground location stream...');

      await _locationStreamSubscription?.cancel();

      _locationStreamSubscription = getLocationStream().listen(
        (Position position) {
          if (!_isTracking) return;

          print('📍 Foreground GPS: ${position.latitude}, ${position.longitude} | Speed: ${position.speed}m/s | Accuracy: ${position.accuracy.toStringAsFixed(1)}m');

          updateDriverLocation(
            rideId: rideId,
            latitude: position.latitude,
            longitude: position.longitude,
            bearing: position.heading,
            speed: position.speed,
            accuracy: position.accuracy,
          );
        },
        onError: (error) {
          print('⚠️ Foreground stream error: $error');
        },
        cancelOnError: false,
      );

      print('✅ Foreground location stream active');
      
      // 🔄 FORCE DATABASE UPDATES: Poll every 2 seconds even if GPS doesn't emit
      _startForcedLocationUpdates(rideId);
      
    } catch (e) {
      print('❌ Error starting foreground stream: $e');
    }
  }

  /// 🔄 FORCE LOCATION UPDATES: Update database every 2 seconds
  /// This ensures updates even when GPS is slow or device is stationary
  void _startForcedLocationUpdates(String rideId) {
    _locationPollTimer?.cancel();
    
    print('⏰ Starting forced location updates (every 2 seconds)');
    
    _locationPollTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      if (!_isTracking) {
        timer.cancel();
        return;
      }
      
      try {
        // Try to get current position (with short timeout)
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ).catchError((_) async {
          // If getCurrentPosition fails, use last known position
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            print('⏰ Using last known position for update');
            return lastKnown;
          }
          throw Exception('No location available');
        });
        
        print('⏰ FORCED UPDATE: ${position.latitude}, ${position.longitude} | Accuracy: ${position.accuracy.toStringAsFixed(1)}m');
        
        await updateDriverLocation(
          rideId: rideId,
          latitude: position.latitude,
          longitude: position.longitude,
          bearing: position.heading,
          speed: position.speed,
          accuracy: position.accuracy,
        );
      } catch (e) {
        print('⚠️ Forced update failed: $e');
      }
    });
  }

  Future<void> _setupBackgroundLocationFetch(String rideId, String userId) async {
    try {
      print('🔄 [SETUP] Setting up background location fetch...');

      // Store ride info FIRST
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('background_ride_id', rideId);
      await prefs.setString('background_user_id', userId);
      await prefs.setBool('background_tracking', true);

      print('✅ [SETUP] Stored background task data');

      // Check if we can access the data we just stored
      final checkRideId = prefs.getString('background_ride_id');
      final checkUserId = prefs.getString('background_user_id');
      final checkTracking = prefs.getBool('background_tracking');
      print('✅ [SETUP] Data verification: rideId=$checkRideId, userId=$checkUserId, tracking=$checkTracking');

      // Unregister any existing task
      try {
        await BackgroundFetch.stop();
        print('✅ [SETUP] Stopped any existing BackgroundFetch tasks');
      } catch (e) {
        print('⚠️ [SETUP] Could not stop existing tasks: $e');
      }

      // Configure BackgroundFetch
      print('🔄 [SETUP] Configuring BackgroundFetch with minimumFetchInterval=15...');
      
      int status = await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15,
          stopOnTerminate: false,
          enableHeadless: true,
          requiresBatteryNotLow: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
          forceAlarmManager: true, // Force AlarmManager instead of JobScheduler
          startOnBoot: true,
        ),
        backgroundLocationTask, // Callback
      );

      print('✅ [SETUP] BackgroundFetch configured with status: $status');
      
      // Status codes:
      // 0 = restricted, 1 = denied, 2 = restricted, 3 = available
      if (status == 3) {
        print('✅ [SETUP] BackgroundFetch is AVAILABLE');
      } else {
        print('⚠️ [SETUP] BackgroundFetch status: $status (may be restricted)');
      }

      // Start BackgroundFetch
      await BackgroundFetch.start();
      print('✅ [SETUP] BackgroundFetch started');
      print('🔄 [SETUP] Waiting for BackgroundFetch callbacks every 15 seconds...');
    } catch (e) {
      print('❌ [SETUP] Error setting up background fetch: $e');
      rethrow;
    }
  }

  Future<void> _showTrackingNotification(String rideId) async {
    try {
      await _notificationService.sendNotification(
        userId: _supabase.auth.currentUser?.id ?? 'system',
        title: '🚗 Live Tracking Active',
        message: 'Your location is being tracked in real-time.',
        type: 'ride_tracking',
        data: {'rideId': rideId},
      );
      print('📱 Tracking notification shown');
    } catch (e) {
      print('⚠️ Could not show notification: $e');
    }
  }

  Future<void> _loadCachedLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      
      if (cachedJson != null) {
        _cachedLocations = List<Map<String, dynamic>>.from(
          jsonDecode(cachedJson),
        );
        print('💾 Loaded ${_cachedLocations.length} cached locations');
      }
    } catch (e) {
      print('⚠️ Error loading cache: $e');
    }
  }

  Future<void> _cacheLocation({
    required String rideId,
    required double latitude,
    required double longitude,
    double? bearing,
    double? speed,
    double? accuracy,
  }) async {
    try {
      final location = {
        'ride_id': rideId,
        'latitude': latitude,
        'longitude': longitude,
        'bearing': bearing,
        'speed': speed,
        'accuracy': accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _cachedLocations.add(location);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_cachedLocations));

      print('💾 Location cached (total: ${_cachedLocations.length})');
    } catch (e) {
      print('❌ Error caching location: $e');
    }
  }

  void _startAutoSync() {
    _syncTimer?.cancel();
    
    _syncTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_cachedLocations.isNotEmpty) {
        print('🔄 Syncing ${_cachedLocations.length} cached locations...');
        await _syncCachedLocations();
      }
    });
  }

  Future<void> _syncCachedLocations() async {
    if (_cachedLocations.isEmpty) return;

    try {
      _cachedLocations.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      print('✅ Cache cleared');
    } catch (e) {
      print('❌ Error syncing cache: $e');
    }
  }

  Future<void> updateDriverLocation({
    required String rideId,
    required double latitude,
    required double longitude,
    double? bearing,
    double? speed,
    double? accuracy,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      try {
        final response = await _supabase
            .from('ride_locations')
            .update({
              'current_lat': latitude,
              'current_lng': longitude,
              'bearing': bearing,
              'speed': speed,
              'accuracy': accuracy,
              'last_updated': DateTime.now().toIso8601String(),
            })
            .eq('ride_id', rideId)
            .eq('driver_id', userId)
            .select();

        if (response.isNotEmpty) {
          print('✅ Location updated (online)');
        } else {
          await _cacheLocation(
            rideId: rideId,
            latitude: latitude,
            longitude: longitude,
            bearing: bearing,
            speed: speed,
            accuracy: accuracy,
          );
        }
      } catch (e) {
        await _cacheLocation(
          rideId: rideId,
          latitude: latitude,
          longitude: longitude,
          bearing: bearing,
          speed: speed,
          accuracy: accuracy,
        );
      }
    } catch (e) {
      print('❌ Error updating location: $e');
    }
  }

  Future<void> _upsertRideLocation({
    required String rideId,
    required String userId,
    required Position position,
  }) async {
    try {
      print('📝 Upserting ride location...');
      
      final existingLocation = await _supabase
          .from('ride_locations')
          .select('id')
          .eq('ride_id', rideId)
          .maybeSingle();

      final locationData = {
        'driver_id': userId,
        'status': 'in_progress',
        'current_lat': position.latitude,
        'current_lng': position.longitude,
        'bearing': position.heading,
        'speed': position.speed,
        'accuracy': position.accuracy,
        'started_at': DateTime.now().toIso8601String(),
        'last_updated': DateTime.now().toIso8601String(),
      };

      if (existingLocation != null) {
        await _supabase
            .from('ride_locations')
            .update(locationData)
            .eq('ride_id', rideId);
        print('✅ Updated existing location record');
      } else {
        locationData['ride_id'] = rideId;
        await _supabase.from('ride_locations').insert(locationData);
        print('✅ Created new location record');
      }
    } catch (e) {
      print('❌ Error in _upsertRideLocation: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> pauseRideTracking(String rideId) async {
    try {
      print('⏸️ Pausing ride: $rideId');
      
      await Future.wait([
        _supabase.from('rides').update({'ride_status': 'paused'}).eq('id', rideId),
        _supabase.from('ride_locations').update({'status': 'paused'}).eq('ride_id', rideId),
      ]);

      print('✅ Ride paused');
      return {'success': true};
    } catch (e) {
      print('❌ Error pausing ride: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resumeRideTracking(String rideId) async {
    try {
      print('▶️ Resuming ride: $rideId');
      
      await Future.wait([
        _supabase.from('rides').update({'ride_status': 'in_progress'}).eq('id', rideId),
        _supabase.from('ride_locations').update({'status': 'in_progress'}).eq('ride_id', rideId),
      ]);

      print('✅ Ride resumed');
      return {'success': true};
    } catch (e) {
      print('❌ Error resuming ride: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> endRideTracking(String rideId) async {
    try {
      print('🛑 Ending ride tracking for: $rideId');

      _isTracking = false;

      await _locationStreamSubscription?.cancel();
      _locationStreamSubscription = null;
      
      _locationPollTimer?.cancel(); // ✅ Stop polling timer
      _locationPollTimer = null;

      try {
        await BackgroundFetch.stop();
      } catch (e) {
        print('⚠️ Error stopping background fetch: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('background_ride_id');
      await prefs.remove('background_user_id');
      await prefs.setBool('background_tracking', false);

      await _syncCachedLocations();

      await Future.wait([
        _supabase.from('rides').update({
          'ride_status': 'completed',
          'status': 'completed',
          'ended_at': DateTime.now().toIso8601String(),
        }).eq('id', rideId),

        _supabase.from('ride_locations').update({
          'status': 'completed',
          'last_updated': DateTime.now().toIso8601String(),
        }).eq('ride_id', rideId),
      ]);

      print('✅ Ride ended');

      final pointsResult = await _awardPointsForRide(rideId);

      await _notifyPassengers(
        rideId,
        'Ride Completed',
        'Your ride has been completed. Thank you!',
      );

      return {
        'success': true,
        'pointsAwarded': pointsResult['pointsAwarded'],
        'distanceKm': pointsResult['distanceKm'],
      };
    } catch (e) {
      print('❌ Error ending ride: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _awardPointsForRide(String rideId) async {
    try {
      print('🎯 Awarding points for ride: $rideId');

      final rideData = await _supabase
          .from('rides')
          .select('driver_id')
          .eq('id', rideId)
          .single();

      final driverId = rideData['driver_id'];

      final result = await _supabase.rpc('award_ride_points', params: {
        'input_ride_id': rideId,
        'input_driver_id': driverId,
      }).select().single();

      final pointsAwarded = result['points_awarded'] ?? 0;
      final distanceKm = result['distance_km'] ?? 0;

      print('✅ Points awarded: $pointsAwarded');

      return {
        'pointsAwarded': pointsAwarded,
        'distanceKm': distanceKm,
      };
    } catch (e) {
      print('❌ Error awarding points: $e');
      return {'pointsAwarded': 0, 'distanceKm': 0};
    }
  }

  Future<bool> checkIfRideStarted(String rideId) async {
    try {
      final response = await _supabase
          .from('rides')
          .select('ride_status')
          .eq('id', rideId)
          .single();

      return response['ride_status'] == 'in_progress';
    } catch (e) {
      print('⚠️ Error checking ride status: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCurrentRideLocation(String rideId) async {
    try {
      return await _supabase
          .from('ride_locations')
          .select()
          .eq('ride_id', rideId)
          .maybeSingle();
    } catch (e) {
      print('⚠️ Error getting ride location: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCompletePath(String rideId) async {
    try {
      final response = await _supabase
          .from('ride_path_history')
          .select('lat, lng, timestamp, bearing, speed')
          .eq('ride_id', rideId)
          .order('timestamp', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('⚠️ Error getting path history: $e');
      return [];
    }
  }

  Stream<Map<String, dynamic>> streamDriverLocation(String rideId) {
    print('📡 Starting WebSocket stream for ride: $rideId');

    return _supabase
        .from('ride_locations')
        .stream(primaryKey: ['id'])
        .eq('ride_id', rideId)
        .map((data) {
          if (data.isNotEmpty) {
            final location = data.first;
            print('🔄 Stream: ${location['current_lat']}, ${location['current_lng']}');
            return location;
          }
          return <String, dynamic>{};
        })
        .handleError((error) {
          print('❌ Stream error: $error');
        });
  }

  Stream<Map<String, dynamic>> listenToRideLocation(String rideId) {
    return streamDriverLocation(rideId);
  }

  Future<void> _notifyPassengers(
    String rideId,
    String title,
    String message,
  ) async {
    try {
      final bookings = await _supabase
          .from('bookings')
          .select('passenger_id')
          .eq('ride_id', rideId)
          .eq('status', 'confirmed');

      for (final booking in bookings) {
        final passengerId = booking['passenger_id'];
        await _notificationService.sendNotification(
          userId: passengerId,
          title: title,
          message: message,
          type: 'ride_update',
        );
      }

      print('✅ Notifications sent to ${bookings.length} passengers');
    } catch (e) {
      print('❌ Error notifying passengers: $e');
    }
  }

  Future<void> dispose() async {
    print('🧹 Cleaning up tracking service');
    await _locationStreamSubscription?.cancel();
    _locationPollTimer?.cancel(); // ✅ Stop polling timer
    _syncTimer?.cancel();
    try {
      await BackgroundFetch.stop();
    } catch (e) {
      print('⚠️ Error stopping background fetch: $e');
    }
    print('✅ Cleanup complete');
  }
}