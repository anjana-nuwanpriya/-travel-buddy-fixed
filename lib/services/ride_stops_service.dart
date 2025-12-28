import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' show sqrt, pow, asin, cos, sin;
import '../config/supabase_config.dart';
import '../models/ride_stop.dart';

class RideStopsService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Get all stops (pickups + dropoffs) for a ride in optimized order
  Future<Map<String, dynamic>> getRideStops(String rideId) async {
    try {
      print('🔵 Fetching ride stops for ride: $rideId');

      // Get all confirmed bookings with passenger data
      final bookingsResponse = await _client
          .from('bookings')
          .select('''
            *,
            passenger:user_profiles!bookings_passenger_id_fkey(
              id,
              full_name,
              phone,
              avatar_url
            )
          ''')
          .eq('ride_id', rideId)
          .eq('status', 'confirmed')
          .order('stop_order', ascending: true);

      if (bookingsResponse.isEmpty) {
        print('⚠️ No confirmed bookings found for this ride');
        return {'success': true, 'stops': <RideStop>[]};
      }

      print('✅ Found ${bookingsResponse.length} confirmed bookings');

      // Convert bookings to stops
      final stops = <RideStop>[];
      
      for (final booking in bookingsResponse) {
        // Create pickup stop
        final pickupStop = RideStop.fromBooking(
          booking: booking,
          type: 'pickup',
          order: booking['stop_order'] as int? ?? 0,
        );
        stops.add(pickupStop);

        // Create dropoff stop (order will be recalculated)
        final dropoffStop = RideStop.fromBooking(
          booking: booking,
          type: 'dropoff',
          order: booking['stop_order'] as int? ?? 0,
        );
        stops.add(dropoffStop);
      }

      // Sort by stop_order
      stops.sort((a, b) => a.order.compareTo(b.order));

      print('✅ Created ${stops.length} stops (${stops.length ~/ 2} pickups + ${stops.length ~/ 2} dropoffs)');

      return {'success': true, 'stops': stops};
    } catch (e) {
      print('❌ Error fetching ride stops: $e');
      return {'success': false, 'error': e.toString(), 'stops': <RideStop>[]};
    }
  }

  /// Get the next pending stop (pickup or dropoff)
  Future<Map<String, dynamic>> getNextStop(String rideId) async {
    try {
      final result = await getRideStops(rideId);
      if (!result['success']) return result;

      final stops = result['stops'] as List<RideStop>;
      
      // Find first pending stop
      final nextStop = stops.firstWhere(
        (stop) => stop.isPending,
        orElse: () => stops.last, // Return last stop if all completed
      );

      print('✅ Next stop: ${nextStop.typeDisplay} ${nextStop.passengerName} at ${nextStop.address}');

      return {'success': true, 'stop': nextStop};
    } catch (e) {
      print('❌ Error getting next stop: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Mark passenger as picked up
  Future<Map<String, dynamic>> markPickedUp(String bookingId) async {
    try {
      print('🔵 Marking booking $bookingId as picked up');

      await _client
          .from('bookings')
          .update({
            'pickup_status': 'picked_up',
            'pickup_time': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      print('✅ Passenger picked up successfully');

      return {'success': true, 'message': 'Passenger picked up'};
    } catch (e) {
      print('❌ Error marking picked up: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Mark passenger as dropped off
  Future<Map<String, dynamic>> markDroppedOff(String bookingId) async {
    try {
      print('🔵 Marking booking $bookingId as dropped off');

      await _client
          .from('bookings')
          .update({
            'dropoff_status': 'dropped_off',
            'dropoff_time': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      print('✅ Passenger dropped off successfully');

      return {'success': true, 'message': 'Passenger dropped off'};
    } catch (e) {
      print('❌ Error marking dropped off: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Skip a stop (passenger not at pickup point)
  Future<Map<String, dynamic>> skipStop(String bookingId, String type) async {
    try {
      print('🔵 Skipping $type for booking $bookingId');

      final updateData = type == 'pickup'
          ? {
              'pickup_status': 'skipped',
              'pickup_time': DateTime.now().toIso8601String(),
            }
          : {
              'dropoff_status': 'skipped',
              'dropoff_time': DateTime.now().toIso8601String(),
            };

      updateData['updated_at'] = DateTime.now().toIso8601String();

      await _client.from('bookings').update(updateData).eq('id', bookingId);

      print('✅ Stop skipped successfully');

      return {'success': true, 'message': 'Stop skipped'};
    } catch (e) {
      print('❌ Error skipping stop: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Calculate optimized route and update stop_order in database
  /// Simple distance-based algorithm:
  /// 1. Sort all pickups by distance from driver's start location
  /// 2. Sort all dropoffs by distance from driver's start location
  /// 3. Combine: All pickups first, then all dropoffs
  Future<Map<String, dynamic>> calculateOptimizedRoute(
    String rideId,
    double driverStartLat,
    double driverStartLng,
  ) async {
    try {
      print('🔵 Calculating optimized route for ride: $rideId');
      print('   Driver start: $driverStartLat, $driverStartLng');

      // Get all confirmed bookings
      final bookingsResponse = await _client
          .from('bookings')
          .select('''
            *,
            passenger:user_profiles!bookings_passenger_id_fkey(
              id,
              full_name
            )
          ''')
          .eq('ride_id', rideId)
          .eq('status', 'confirmed');

      if (bookingsResponse.isEmpty) {
        print('⚠️ No confirmed bookings to optimize');
        return {'success': true, 'stops': <RideStop>[]};
      }

      print('✅ Found ${bookingsResponse.length} bookings to optimize');

      // Separate pickups and dropoffs
      final pickups = <Map<String, dynamic>>[];
      final dropoffs = <Map<String, dynamic>>[];

      for (final booking in bookingsResponse) {
        final pickupLat = booking['pickup_lat'] as double?;
        final pickupLng = booking['pickup_lng'] as double?;
        final dropoffLat = booking['dropoff_lat'] as double?;
        final dropoffLng = booking['dropoff_lng'] as double?;

        if (pickupLat != null && pickupLng != null) {
          pickups.add({
            'booking': booking,
            'distance': _calculateDistance(
              driverStartLat,
              driverStartLng,
              pickupLat,
              pickupLng,
            ),
          });
        }

        if (dropoffLat != null && dropoffLng != null) {
          dropoffs.add({
            'booking': booking,
            'distance': _calculateDistance(
              driverStartLat,
              driverStartLng,
              dropoffLat,
              dropoffLng,
            ),
          });
        }
      }

      // Sort by distance
      pickups.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double)
      );
      dropoffs.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double)
      );

      print('📊 Sorted ${pickups.length} pickups and ${dropoffs.length} dropoffs by distance');

      // Assign stop orders
      final allStops = <RideStop>[];
      int stopOrder = 1;

      // First, all pickups
      for (final pickupData in pickups) {
        final booking = pickupData['booking'] as Map<String, dynamic>;
        final distance = pickupData['distance'] as double;
        
        // Update stop_order in database
        await _client
            .from('bookings')
            .update({'stop_order': stopOrder})
            .eq('id', booking['id']);

        print('   ✅ Stop $stopOrder: Pickup ${booking['passenger']['full_name']} (${distance.toStringAsFixed(2)} km)');

        allStops.add(RideStop.fromBooking(
          booking: booking,
          type: 'pickup',
          order: stopOrder,
        ));

        stopOrder++;
      }

      // Then, all dropoffs
      for (final dropoffData in dropoffs) {
        final booking = dropoffData['booking'] as Map<String, dynamic>;
        final distance = dropoffData['distance'] as double;

        print('   ✅ Stop $stopOrder: Dropoff ${booking['passenger']['full_name']} (${distance.toStringAsFixed(2)} km)');

        allStops.add(RideStop.fromBooking(
          booking: booking,
          type: 'dropoff',
          order: stopOrder,
        ));

        stopOrder++;
      }

      print('✅ Route optimized: ${allStops.length} stops ordered');

      return {'success': true, 'stops': allStops};
    } catch (e) {
      print('❌ Error calculating route: $e');
      return {'success': false, 'error': e.toString(), 'stops': <RideStop>[]};
    }
  }

  /// Calculate distance between two points using Haversine formula
  /// Returns distance in kilometers
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * 3.141592653589793 / 180.0;
  }

  /// Get statistics for a ride (how many picked up, dropped off, etc.)
  Future<Map<String, dynamic>> getRideStats(String rideId) async {
    try {
      final bookingsResponse = await _client
          .from('bookings')
          .select('pickup_status, dropoff_status')
          .eq('ride_id', rideId)
          .eq('status', 'confirmed');

      final totalPassengers = bookingsResponse.length;
      final pickedUp = bookingsResponse
          .where((b) => b['pickup_status'] == 'picked_up')
          .length;
      final droppedOff = bookingsResponse
          .where((b) => b['dropoff_status'] == 'dropped_off')
          .length;
      final pickupsPending = bookingsResponse
          .where((b) => b['pickup_status'] == 'pending')
          .length;
      final dropoffsPending = bookingsResponse
          .where((b) => b['dropoff_status'] == 'pending')
          .length;

      return {
        'success': true,
        'stats': {
          'total': totalPassengers,
          'picked_up': pickedUp,
          'dropped_off': droppedOff,
          'pickups_pending': pickupsPending,
          'dropoffs_pending': dropoffsPending,
        },
      };
    } catch (e) {
      print('❌ Error getting ride stats: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check if all passengers have been picked up
  Future<bool> areAllPassengersPickedUp(String rideId) async {
    try {
      final bookingsResponse = await _client
          .from('bookings')
          .select('pickup_status')
          .eq('ride_id', rideId)
          .eq('status', 'confirmed');

      return bookingsResponse.every((b) => 
        b['pickup_status'] == 'picked_up' || 
        b['pickup_status'] == 'skipped'
      );
    } catch (e) {
      print('❌ Error checking pickups: $e');
      return false;
    }
  }

  /// Check if all passengers have been dropped off
  Future<bool> areAllPassengersDroppedOff(String rideId) async {
    try {
      final bookingsResponse = await _client
          .from('bookings')
          .select('dropoff_status')
          .eq('ride_id', rideId)
          .eq('status', 'confirmed');

      return bookingsResponse.every((b) => 
        b['dropoff_status'] == 'dropped_off' || 
        b['dropoff_status'] == 'skipped'
      );
    } catch (e) {
      print('❌ Error checking dropoffs: $e');
      return false;
    }
  }
}