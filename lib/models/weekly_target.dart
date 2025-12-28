class WeeklyTarget {
  final String id;
  final String userId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int ridesCompleted;
  final bool target3Claimed;
  final bool target6Claimed;
  final bool target9Claimed;
  final bool target15Claimed;
  final double totalEarnings;
  final DateTime createdAt;
  final DateTime updatedAt;

  WeeklyTarget({
    required this.id,
    required this.userId,
    required this.weekStart,
    required this.weekEnd,
    required this.ridesCompleted,
    required this.target3Claimed,
    required this.target6Claimed,
    required this.target9Claimed,
    required this.target15Claimed,
    required this.totalEarnings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WeeklyTarget.fromJson(Map<String, dynamic> json) {
    return WeeklyTarget(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      weekStart: DateTime.parse(json['week_start'] as String),
      weekEnd: DateTime.parse(json['week_end'] as String),
      ridesCompleted: json['rides_completed'] as int,
      target3Claimed: json['target_3_claimed'] as bool,
      target6Claimed: json['target_6_claimed'] as bool,
      target9Claimed: json['target_9_claimed'] as bool,
      target15Claimed: json['target_15_claimed'] as bool,
      totalEarnings: (json['total_earnings'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'week_start': weekStart.toIso8601String(),
      'week_end': weekEnd.toIso8601String(),
      'rides_completed': ridesCompleted,
      'target_3_claimed': target3Claimed,
      'target_6_claimed': target6Claimed,
      'target_9_claimed': target9Claimed,
      'target_15_claimed': target15Claimed,
      'total_earnings': totalEarnings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper method to get target status
  TargetStatus getTargetStatus(int targetRides) {
    switch (targetRides) {
      case 3:
        return TargetStatus(
          ridesRequired: 3,
          reward: 100,
          isCompleted: ridesCompleted >= 3,
          isClaimed: target3Claimed,
        );
      case 6:
        return TargetStatus(
          ridesRequired: 6,
          reward: 200,
          isCompleted: ridesCompleted >= 6,
          isClaimed: target6Claimed,
        );
      case 9:
        return TargetStatus(
          ridesRequired: 9,
          reward: 400,
          isCompleted: ridesCompleted >= 9,
          isClaimed: target9Claimed,
        );
      case 15:
        return TargetStatus(
          ridesRequired: 15,
          reward: 1000,
          isCompleted: ridesCompleted >= 15,
          isClaimed: target15Claimed,
        );
      default:
        throw ArgumentError('Invalid target rides: $targetRides');
    }
  }

  // Get all targets
  List<TargetStatus> getAllTargets() {
    return [
      getTargetStatus(3),
      getTargetStatus(6),
      getTargetStatus(9),
      getTargetStatus(15),
    ];
  }
}

class TargetStatus {
  final int ridesRequired;
  final double reward;
  final bool isCompleted;
  final bool isClaimed;

  TargetStatus({
    required this.ridesRequired,
    required this.reward,
    required this.isCompleted,
    required this.isClaimed,
  });

  bool get canClaim => isCompleted && !isClaimed;
  
  double get progress {
    // This will be calculated based on current rides in the UI
    return 0.0;
  }
}