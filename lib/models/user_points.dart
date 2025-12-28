class UserPoints {
  final String id;
  final String userId;
  final String rideId;
  final double pointsEarned;
  final double distanceKm;
  final DateTime earnedAt;
  final DateTime createdAt;

  UserPoints({
    required this.id,
    required this.userId,
    required this.rideId,
    required this.pointsEarned,
    required this.distanceKm,
    required this.earnedAt,
    required this.createdAt,
  });

  factory UserPoints.fromJson(Map<String, dynamic> json) {
    return UserPoints(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      rideId: json['ride_id'] as String,
      pointsEarned: (json['points_earned'] as num).toDouble(),
      distanceKm: (json['distance_km'] as num).toDouble(),
      earnedAt: DateTime.parse(json['earned_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'ride_id': rideId,
      'points_earned': pointsEarned,
      'distance_km': distanceKm,
      'earned_at': earnedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class UserTotalPoints {
  final String id;
  final String userId;
  final double totalPoints;
  final DateTime updatedAt;

  UserTotalPoints({
    required this.id,
    required this.userId,
    required this.totalPoints,
    required this.updatedAt,
  });

  factory UserTotalPoints.fromJson(Map<String, dynamic> json) {
    return UserTotalPoints(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      totalPoints: (json['total_points'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'total_points': totalPoints,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}