class DriverDocument {
  final String id;
  final String driverId;
  final String documentType;
  final String status;
  final String? frontImageUrl;
  final String? backImageUrl;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  DriverDocument({
    required this.id,
    required this.driverId,
    required this.documentType,
    required this.status,
    this.frontImageUrl,
    this.backImageUrl,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriverDocument.fromJson(Map<String, dynamic> json) {
    return DriverDocument(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      documentType: json['document_type'] as String,
      status: json['status'] as String,
      frontImageUrl: json['front_image_url'] as String?,
      backImageUrl: json['back_image_url'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'document_type': documentType,
      'status': status,
      'front_image_url': frontImageUrl,
      'back_image_url': backImageUrl,
      'rejection_reason': rejectionReason,
      'submitted_at': submittedAt?.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get displayName {
    switch (documentType) {
      case 'profile_photo':
        return 'Profile Photo';
      case 'driving_license':
        return 'Driving License';
      case 'vehicle_insurance':
        return 'Vehicle Insurance';
      case 'revenue_license':
        return 'Revenue License';
      case 'vehicle_registration':
        return 'Vehicle Registration Document';
      default:
        return documentType;
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'not_submitted':
        return 'Get Started';
      case 'pending':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  bool get isCompleted => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isNotSubmitted => status == 'not_submitted';
}