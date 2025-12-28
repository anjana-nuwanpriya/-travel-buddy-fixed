class DriverVerification {
  final String id;
  final String driverId;
  final bool isVerified;
  final String verificationStatus;
  final List<String> completedSteps;
  final int totalSteps;
  final DateTime createdAt;
  final DateTime updatedAt;

  DriverVerification({
    required this.id,
    required this.driverId,
    required this.isVerified,
    required this.verificationStatus,
    required this.completedSteps,
    required this.totalSteps,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriverVerification.fromJson(Map<String, dynamic> json) {
    return DriverVerification(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      isVerified: json['is_verified'] as bool,
      verificationStatus: json['verification_status'] as String,
      completedSteps: List<String>.from(json['completed_steps'] as List? ?? []),
      totalSteps: json['total_steps'] as int? ?? 5,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'is_verified': isVerified,
      'verification_status': verificationStatus,
      'completed_steps': completedSteps,
      'total_steps': totalSteps,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  double get progressPercentage {
    if (totalSteps == 0) return 0.0;
    return completedSteps.length / totalSteps;
  }

  int get completedCount => completedSteps.length;
}