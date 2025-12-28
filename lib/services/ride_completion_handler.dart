import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/points_service.dart';
import '../services/targets_service.dart';

class RideCompletionHandler {
  final PointsService _pointsService = PointsService();
  final TargetsService _targetsService = TargetsService();
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Call this method when a ride is completed
  /// This will:
  /// 1. Add points based on distance
  /// 2. Update weekly target rides count
  Future<Map<String, dynamic>> handleRideCompletion({
    required String rideId,
    required String driverId,
  }) async {
    try {
      // Get ride details
      final ride = await _supabase
          .from('rides')
          .select('distance')
          .eq('id', rideId)
          .single();

      // Extract distance (format: "45.2 km" or "45.2")
      final distanceStr = ride['distance'] as String;
      final distanceKm = _parseDistance(distanceStr);

      if (distanceKm <= 0) {
        throw Exception('Invalid ride distance');
      }

      // Add points for the driver
      final points = await _pointsService.addPointsForRide(
        userId: driverId,
        rideId: rideId,
        distanceKm: distanceKm,
      );

      // Update weekly target
      final weeklyTarget = await _targetsService.updateRidesCompleted(
        userId: driverId,
        increment: 1,
      );

      return {
        'success': true,
        'points_earned': points.pointsEarned,
        'distance_km': distanceKm,
        'weekly_rides': weeklyTarget.ridesCompleted,
        'message': 'Earned ${points.pointsEarned.toInt()} points!',
      };
    } catch (e) {
      print('Error handling ride completion: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Parse distance string to double
  /// Handles formats like "45.2 km", "45.2", "45km"
  double _parseDistance(String distanceStr) {
    try {
      // Remove "km" and trim
      final cleanStr = distanceStr
          .toLowerCase()
          .replaceAll('km', '')
          .replaceAll(',', '')
          .trim();

      return double.parse(cleanStr);
    } catch (e) {
      print('Error parsing distance: $distanceStr, error: $e');
      return 0.0;
    }
  }

  /// Show points earned dialog after ride completion
  Future<void> showPointsEarnedDialog({
    required BuildContext context,
    required double pointsEarned,
    required double distanceKm,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.stars_rounded, color: Colors.amber, size: 32),
            SizedBox(width: 12),
            Text('Points Earned!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You completed a ride of',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '${distanceKm.toStringAsFixed(1)} km',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '${pointsEarned.toInt()} Points',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Keep completing rides to earn more points and unlock weekly targets!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }
}

// Extension for easy access
extension RideCompletionExtension on BuildContext {
  Future<void> handleRideCompleted({
    required String rideId,
    required String driverId,
  }) async {
    final handler = RideCompletionHandler();
    final result = await handler.handleRideCompletion(
      rideId: rideId,
      driverId: driverId,
    );

    if (result['success'] == true && mounted) {
      await handler.showPointsEarnedDialog(
        context: this,
        pointsEarned: result['points_earned'],
        distanceKm: result['distance_km'],
      );
    }
  }
}


