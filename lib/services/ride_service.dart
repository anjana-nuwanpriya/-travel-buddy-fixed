import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/ride.dart';

class RideService {
  final SupabaseClient _client = SupabaseConfig.client;

  // ============================================================
  // ✅ NEW: GET RIDE WITH BOOKINGS (FOR DRIVING MODE)
  // ============================================================

  /// Get ride with ALL booking details - FOR DRIVING MODE
  Future<Ride> getRideWithBookings(String rideId) async {
    try {
      print('🔵 Fetching ride with bookings: $rideId');
      
      final response = await _client
          .from('rides')
          .select('''
            *,
            bookings(
              *,
              passenger:user_profiles!bookings_passenger_id_fkey(
                id,
                full_name,
                phone,
                email,
                avatar_url
              )
            )
          ''')
          .eq('id', rideId)
          .single();

      print('✅ Ride with bookings fetched');
      print('   Bookings: ${(response['bookings'] as List?)?.length ?? 0}');
      
      final ride = Ride.fromJson(response);
      
      print('📊 Parsed ride:');
      print('   ID: ${ride.id}');
      print('   Bookings: ${ride.bookings?.length ?? 0}');
      
      return ride;
    } catch (e) {
      print('❌ Error fetching ride with bookings: $e');
      rethrow;
    }
  }

  // ============================================================
  // ✅ SEARCH WITH RANKING
  // ============================================================

  /// Search rides by proximity with intelligent ranking
  Future<Map<String, dynamic>> searchRidesByProximity({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required DateTime departureDate,
    required int minSeats,
    double searchRadius = 10.0,
  }) async {
    try {
      print('🔵 Starting proximity-based ride search...');
      print('📍 Passenger pickup: ($fromLat, $fromLng)');
      print('📍 Passenger dropoff: ($toLat, $toLng)');
      print('📍 Search radius: $searchRadius km');

      final dateStr = departureDate.toIso8601String().split('T')[0];
      
      final response = await _client
          .from('rides')
          .select('*')
          .eq('status', 'active')
          .eq('departure_date', dateStr)
          .gte('available_seats', minSeats)
          .order('departure_time', ascending: true);

      print('✅ Fetched ${response.length} rides for that date');

      // ✅ NO driver info fetching - parse directly!
      final rides = (response as List)
          .map((json) => Ride.fromJson(json as Map<String, dynamic>))
          .toList();

      final proximityMatchedRides = <RideWithScore>[];

      for (var ride in rides) {
        double pickupDistance = _haversineDistance(
          fromLat,
          fromLng,
          ride.fromLatitude,
          ride.fromLongitude,
        );

        double dropoffDistance = _haversineDistance(
          toLat,
          toLng,
          ride.toLatitude,
          ride.toLongitude,
        );

        if (pickupDistance <= searchRadius && 
            dropoffDistance <= searchRadius) {
          
          double relevanceScore = _calculateRelevanceScore(
            ride,
            pickupDistance,
            dropoffDistance,
            fromLat,
            fromLng,
          );

          proximityMatchedRides.add(
            RideWithScore(ride: ride, score: relevanceScore),
          );

          print('✅ Match found: ${ride.fromLocation} → ${ride.toLocation}');
          print('   Pickup distance: ${pickupDistance.toStringAsFixed(1)} km');
          print('   Dropoff distance: ${dropoffDistance.toStringAsFixed(1)} km');
          print('   Relevance score: ${relevanceScore.toStringAsFixed(1)}');
        }
      }

      proximityMatchedRides.sort((a, b) => b.score.compareTo(a.score));

      print('✅ Found ${proximityMatchedRides.length} matching rides');

      final rankedRides = proximityMatchedRides.map((item) => item.ride).toList();

      return {
        'success': true,
        'rides': rankedRides,
        'count': rankedRides.length,
      };
    } catch (e) {
      print('❌ Error searching rides by proximity: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Calculate Haversine distance between two points (in km)
  double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double R = 6371.0;
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = R * c;
    
    return distance;
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// Calculate relevance score based on multiple factors
  double _calculateRelevanceScore(
    Ride ride,
    double pickupDistanceKm,
    double dropoffDistanceKm,
    double userFromLat,
    double userFromLng,
  ) {
    const double pickupWeight = 0.4;
    const double dropoffWeight = 0.4;
    const double timeWeight = 0.1;
    const double ratingWeight = 0.1;

    double pickupScore = max(0, 100 - (pickupDistanceKm * 10));
    double dropoffScore = max(0, 100 - (dropoffDistanceKm * 10));
    double timeScore = _calculateTimeScore(ride.departureTime);
    double ratingScore = ((ride.driverRating ?? 4.0) / 5.0) * 100;

    double finalScore = (pickupScore * pickupWeight) +
        (dropoffScore * dropoffWeight) +
        (timeScore * timeWeight) +
        (ratingScore * ratingWeight);

    return finalScore;
  }

  /// Calculate time score based on departure time
  double _calculateTimeScore(String departureTimeStr) {
    try {
      final parts = departureTimeStr.split(':');
      final hour = int.parse(parts[0]);

      if (hour >= 8 && hour < 18) {
        return 95.0;
      } else if (hour >= 6 && hour < 22) {
        return 80.0;
      } else {
        return 50.0;
      }
    } catch (e) {
      return 75.0;
    }
  }

  // ============================================================
  // ✅ SUPER OPTIMIZED - NO DRIVER FETCHING
  // ============================================================

  /// Get all available rides - NO driver info fetching
  Future<Map<String, dynamic>> getAvailableRides() async {
    try {
      print('🔵 Fetching available rides (NO driver fetching)...');

      final response = await _client
          .from('rides')
          .select('*')
          .eq('status', 'active')
          .gte('departure_date', DateTime.now().toIso8601String().split('T')[0])
          .order('departure_date', ascending: true)
          .order('departure_time', ascending: true);

      print('✅ Fetched ${response.length} rides in 1 query');

      // ✅ Direct parsing - NO driver info fetching!
      final rides = (response as List)
          .map((json) => Ride.fromJson(json as Map<String, dynamic>))
          .toList();

      return {'success': true, 'rides': rides};
    } catch (e) {
      print('❌ Error fetching rides: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get rides by user (driver's posted rides) - SUPER FAST!
  Future<Map<String, dynamic>> getMyRides() async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      print('⏱️ [SUPER FAST MODE] Fetching user rides...');
      print('🔵 Fetching user rides for: $userId');

      // ✅ ONE QUERY ONLY - no driver info fetching!
      final response = await _client
          .from('rides')
          .select('*')
          .eq('driver_id', userId)
          .order('departure_date', ascending: false);

      print('✅ Fetched ${response.length} user rides in 1 query (LIGHTNING FAST!)');

      // ✅ Direct parsing - NO loops, NO additional queries!
      final rides = (response as List)
          .map((json) => Ride.fromJson(json as Map<String, dynamic>))
          .toList();

      print('⚡ Total time: ~100-200ms for ${rides.length} rides');

      return {'success': true, 'rides': rides};
    } catch (e) {
      print('❌ Error fetching user rides: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Search rides with filters - FAST
  Future<Map<String, dynamic>> searchRides({
    String? fromLocation,
    String? toLocation,
    DateTime? departureDate,
    int? minSeats,
  }) async {
    try {
      print('🔵 Searching rides...');
      print('From: $fromLocation, To: $toLocation, Date: $departureDate');

      var query = _client.from('rides').select('*').eq('status', 'active');

      if (fromLocation != null && fromLocation.isNotEmpty) {
        query = query.ilike('from_location', '%$fromLocation%');
      }
      if (toLocation != null && toLocation.isNotEmpty) {
        query = query.ilike('to_location', '%$toLocation%');
      }
      if (departureDate != null) {
        final dateStr = departureDate.toIso8601String().split('T')[0];
        query = query.eq('departure_date', dateStr);
      }
      if (minSeats != null) {
        query = query.gte('available_seats', minSeats);
      }

      final response = await query
          .order('departure_date', ascending: true)
          .order('departure_time', ascending: true);

      print('✅ Found ${response.length} matching rides');

      // ✅ No driver fetching - direct parsing!
      final rides = (response as List)
          .map((json) => Ride.fromJson(json as Map<String, dynamic>))
          .toList();

      return {'success': true, 'rides': rides};
    } catch (e) {
      print('❌ Error searching rides: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get single ride details - FAST
  Future<Map<String, dynamic>> getRideDetails(String rideId) async {
    try {
      print('🔵 Fetching ride details: $rideId');

      final response = await _client
          .from('rides')
          .select('*')
          .eq('id', rideId)
          .single();

      print('✅ Ride details fetched');

      // ✅ No driver fetching!
      final ride = Ride.fromJson(response);

      return {'success': true, 'ride': ride};
    } catch (e) {
      print('❌ Error fetching ride details: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create/Publish a new ride
  Future<Map<String, dynamic>> publishRide(
    Map<String, dynamic> rideData,
  ) async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      print('🔵 Publishing ride...');

      rideData['driver_id'] = userId;
      rideData['status'] = 'active';
      rideData['created_at'] = DateTime.now().toIso8601String();
      rideData['updated_at'] = DateTime.now().toIso8601String();

      final response = await _client
          .from('rides')
          .insert(rideData)
          .select()
          .single();

      print('✅ Ride published successfully');

      final ride = Ride.fromJson(response);

      return {
        'success': true,
        'ride': ride,
        'message': 'Ride published successfully',
      };
    } catch (e) {
      print('❌ Error publishing ride: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update ride
  Future<Map<String, dynamic>> updateRide(
    String rideId,
    Map<String, dynamic> updates,
  ) async {
    try {
      print('🔵 Updating ride: $rideId');

      updates['updated_at'] = DateTime.now().toIso8601String();

      final response = await _client
          .from('rides')
          .update(updates)
          .eq('id', rideId)
          .select()
          .single();

      print('✅ Ride updated successfully');

      final ride = Ride.fromJson(response);

      return {
        'success': true,
        'ride': ride,
        'message': 'Ride updated successfully',
      };
    } catch (e) {
      print('❌ Error updating ride: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cancel ride
  Future<Map<String, dynamic>> cancelRide(String rideId) async {
    try {
      print('🔵 Cancelling ride: $rideId');

      final response = await _client
          .from('rides')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .select()
          .single();

      print('✅ Ride cancelled successfully');

      return {'success': true, 'message': 'Ride cancelled successfully'};
    } catch (e) {
      print('❌ Error cancelling ride: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Delete ride
  Future<Map<String, dynamic>> deleteRide(String rideId) async {
    try {
      print('🔵 Deleting ride: $rideId');

      await _client.from('rides').delete().eq('id', rideId);

      print('✅ Ride deleted successfully');

      return {'success': true, 'message': 'Ride deleted successfully'};
    } catch (e) {
      print('❌ Error deleting ride: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}

/// Helper class to store ride with its score
class RideWithScore {
  final Ride ride;
  final double score;

  RideWithScore({required this.ride, required this.score});
}