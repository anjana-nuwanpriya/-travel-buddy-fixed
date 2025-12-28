import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/weekly_target.dart';

class TargetsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get or create current week's target
  Future<WeeklyTarget> getCurrentWeekTarget(String userId) async {
    try {
      // Call RPC with input_userid parameter
      final response = await _supabase.rpc(
        'get_or_create_week_target',
        params: {'input_userid': userId},
      );

      if (response == null || (response is List && response.isEmpty)) {
        throw Exception('Failed to get or create week target');
      }

      // Handle both single object and list response
      final data = response is List ? response.first : response;
      
      // Map the returned columns (ret_* prefix) to expected format
      final mappedData = {
        'id': data['ret_id'],
        'user_id': data['ret_user_id'],
        'week_start': data['ret_week_start'],
        'week_end': data['ret_week_end'],
        'rides_completed': data['ret_rides_completed'],
        'target_3_claimed': data['ret_target_3_claimed'],
        'target_6_claimed': data['ret_target_6_claimed'],
        'target_9_claimed': data['ret_target_9_claimed'],
        'target_15_claimed': data['ret_target_15_claimed'],
        'total_earnings': data['ret_total_earnings'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      return WeeklyTarget.fromJson(mappedData);
    } catch (e) {
      print('Error in getCurrentWeekTarget: $e');
      throw Exception('Failed to get current week target: $e');
    }
  }

  // Update rides completed for the week
  Future<WeeklyTarget> updateRidesCompleted({
    required String userId,
    required int increment,
  }) async {
    try {
      // Get current week target
      final currentTarget = await getCurrentWeekTarget(userId);

      // Update rides completed
      final response = await _supabase
          .from('weekly_targets')
          .update({
            'rides_completed': currentTarget.ridesCompleted + increment,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', currentTarget.id)
          .select()
          .single();

      return WeeklyTarget.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update rides completed: $e');
    }
  }

  // Claim target reward
  Future<WeeklyTarget> claimTargetReward({
    required String userId,
    required int targetRides,
  }) async {
    try {
      final currentTarget = await getCurrentWeekTarget(userId);

      // Check if target is met
      if (currentTarget.ridesCompleted < targetRides) {
        throw Exception('Target not met yet');
      }

      // Determine which target to claim
      String targetField;
      double rewardAmount;

      switch (targetRides) {
        case 3:
          if (currentTarget.target3Claimed) {
            throw Exception('Target already claimed');
          }
          targetField = 'target_3_claimed';
          rewardAmount = 100;
          break;
        case 6:
          if (currentTarget.target6Claimed) {
            throw Exception('Target already claimed');
          }
          targetField = 'target_6_claimed';
          rewardAmount = 200;
          break;
        case 9:
          if (currentTarget.target9Claimed) {
            throw Exception('Target already claimed');
          }
          targetField = 'target_9_claimed';
          rewardAmount = 400;
          break;
        case 15:
          if (currentTarget.target15Claimed) {
            throw Exception('Target already claimed');
          }
          targetField = 'target_15_claimed';
          rewardAmount = 1000;
          break;
        default:
          throw Exception('Invalid target rides: $targetRides');
      }

      // Update target as claimed
      final response = await _supabase
          .from('weekly_targets')
          .update({
            targetField: true,
            'total_earnings': currentTarget.totalEarnings + rewardAmount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', currentTarget.id)
          .select()
          .single();

      return WeeklyTarget.fromJson(response);
    } catch (e) {
      throw Exception('Failed to claim target reward: $e');
    }
  }

  // Get all weekly targets history
  Future<List<WeeklyTarget>> getWeeklyTargetsHistory({
    required String userId,
    int limit = 12,
  }) async {
    try {
      final response = await _supabase
          .from('weekly_targets')
          .select()
          .eq('user_id', userId)
          .order('week_start', ascending: false)
          .limit(limit);

      return (response as List).map((json) => WeeklyTarget.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get weekly targets history: $e');
    }
  }

  // Subscribe to current week target updates
  Stream<WeeklyTarget> subscribeToCurrentWeekTarget(String userId) async* {
    // First get the current week target to know which week we're in
    final currentTarget = await getCurrentWeekTarget(userId);
    final weekStartStr = currentTarget.weekStart.toIso8601String().split('T')[0]; // Just the date part

    yield* _supabase
        .from('weekly_targets')
        .stream(primaryKey: ['id'])
        .map((data) {
          // Filter for current user and week
          final filtered = data.where((item) => 
            item['user_id'] == userId && 
            item['week_start'] == weekStartStr
          ).toList();
          
          if (filtered.isEmpty) {
            throw Exception('No current week target found');
          }
          return WeeklyTarget.fromJson(filtered.first);
        });
  }

  // Helper: Get week date range (Monday to Sunday)
  Map<String, DateTime> getCurrentWeekRange() {
    final now = DateTime.now();
    final weekday = now.weekday;
    
    // Calculate Monday of current week
    final weekStart = now.subtract(Duration(days: weekday - 1));
    final mondayStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
    
    // Calculate Sunday of current week
    final weekEnd = mondayStart.add(const Duration(days: 6));
    final sundayEnd = DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59);
    
    return {
      'start': mondayStart,
      'end': sundayEnd,
    };
  }

  // Helper: Format week range for display
  String formatWeekRange(DateTime weekStart, DateTime weekEnd) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    if (weekStart.month == weekEnd.month) {
      return '${months[weekStart.month - 1]} ${weekStart.day}-${weekEnd.day}';
    } else {
      return '${months[weekStart.month - 1]} ${weekStart.day} - ${months[weekEnd.month - 1]} ${weekEnd.day}';
    }
  }
}