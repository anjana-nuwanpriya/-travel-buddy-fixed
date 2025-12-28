import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_points.dart';

class PointsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Add points for a completed ride
  Future<UserPoints> addPointsForRide({
    required String userId,
    required String rideId,
    required double distanceKm,
  }) async {
    try {
      // Calculate points: 1 point per km
      final pointsEarned = distanceKm.roundToDouble();

      final response = await _supabase.from('user_points').insert({
        'user_id': userId,
        'ride_id': rideId,
        'points_earned': pointsEarned,
        'distance_km': distanceKm,
      }).select().single();

      return UserPoints.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add points: $e');
    }
  }

  // Get user's total points
  Future<UserTotalPoints> getUserTotalPoints(String userId) async {
    try {
      final response = await _supabase
          .from('user_total_points')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Create initial record
        final newRecord = await _supabase.from('user_total_points').insert({
          'user_id': userId,
          'total_points': 0,
        }).select().single();
        
        return UserTotalPoints.fromJson(newRecord);
      }

      return UserTotalPoints.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get total points: $e');
    }
  }

  // Get points history for a user
  Future<List<UserPoints>> getUserPointsHistory({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('user_points')
          .select()
          .eq('user_id', userId)
          .order('earned_at', ascending: false)
          .limit(limit);

      return (response as List).map((json) => UserPoints.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get points history: $e');
    }
  }

  // Get points earned from a specific ride
  Future<UserPoints?> getPointsForRide(String rideId) async {
    try {
      final response = await _supabase
          .from('user_points')
          .select()
          .eq('ride_id', rideId)
          .maybeSingle();

      if (response == null) return null;
      return UserPoints.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get points for ride: $e');
    }
  }

  // Get points with ride details
  Future<List<Map<String, dynamic>>> getUserPointsWithRideDetails({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('user_points')
          .select('''
            *,
            rides:ride_id (
              from_location,
              to_location,
              departure_date,
              distance
            )
          ''')
          .eq('user_id', userId)
          .order('earned_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get points with ride details: $e');
    }
  }

  // Subscribe to points updates
  Stream<UserTotalPoints> subscribeToTotalPoints(String userId) {
    return _supabase
        .from('user_total_points')
        .stream(primaryKey: ['id'])
        .map((data) {
          // Filter for current user
          final filtered = data.where((item) => item['user_id'] == userId).toList();
          
          if (filtered.isEmpty) {
            return UserTotalPoints(
              id: '',
              userId: userId,
              totalPoints: 0,
              updatedAt: DateTime.now(),
            );
          }
          return UserTotalPoints.fromJson(filtered.first);
        });
  }
}