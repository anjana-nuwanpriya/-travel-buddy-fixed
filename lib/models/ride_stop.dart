/// Model representing a single stop (pickup or dropoff) in a ride
/// Used for driver navigation and passenger management
class RideStop {
  final String bookingId;
  final String passengerId;
  final String passengerName;
  final String? passengerPhone;
  final String? passengerAvatar;
  final String type; // 'pickup' or 'dropoff'
  final double lat;
  final double lng;
  final String address;
  final String status; // 'pending', 'completed', 'skipped'
  final int order; // Stop order in optimized route
  final DateTime? completedAt;
  final int seatsBooked;

  RideStop({
    required this.bookingId,
    required this.passengerId,
    required this.passengerName,
    this.passengerPhone,
    this.passengerAvatar,
    required this.type,
    required this.lat,
    required this.lng,
    required this.address,
    required this.status,
    required this.order,
    this.completedAt,
    required this.seatsBooked,
  });

  /// Create RideStop from booking data
  factory RideStop.fromBooking({
    required Map<String, dynamic> booking,
    required String type, // 'pickup' or 'dropoff'
    required int order,
  }) {
    final passenger = booking['passenger'] as Map<String, dynamic>?;
    
    // Determine which location to use based on type
    final lat = type == 'pickup' 
        ? booking['pickup_lat'] as double?
        : booking['dropoff_lat'] as double?;
    
    final lng = type == 'pickup'
        ? booking['pickup_lng'] as double?
        : booking['dropoff_lng'] as double?;
    
    final address = type == 'pickup'
        ? booking['pickup_address'] as String?
        : booking['dropoff_address'] as String?;
    
    final status = type == 'pickup'
        ? booking['pickup_status'] as String? ?? 'pending'
        : booking['dropoff_status'] as String? ?? 'pending';
    
    final completedAt = type == 'pickup'
        ? booking['pickup_time'] != null 
            ? DateTime.parse(booking['pickup_time'] as String)
            : null
        : booking['dropoff_time'] != null
            ? DateTime.parse(booking['dropoff_time'] as String)
            : null;

    return RideStop(
      bookingId: booking['id'] as String,
      passengerId: booking['passenger_id'] as String,
      passengerName: passenger?['full_name'] as String? ?? 'Passenger',
      passengerPhone: passenger?['phone'] as String?,
      passengerAvatar: passenger?['avatar_url'] as String?,
      type: type,
      lat: lat ?? 0.0,
      lng: lng ?? 0.0,
      address: address ?? 'Unknown location',
      status: status,
      order: order,
      completedAt: completedAt,
      seatsBooked: booking['seats_booked'] as int? ?? 1,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'passenger_id': passengerId,
      'passenger_name': passengerName,
      'passenger_phone': passengerPhone,
      'passenger_avatar': passengerAvatar,
      'type': type,
      'lat': lat,
      'lng': lng,
      'address': address,
      'status': status,
      'order': order,
      'completed_at': completedAt?.toIso8601String(),
      'seats_booked': seatsBooked,
    };
  }

  /// Create from JSON
  factory RideStop.fromJson(Map<String, dynamic> json) {
    return RideStop(
      bookingId: json['booking_id'] as String,
      passengerId: json['passenger_id'] as String,
      passengerName: json['passenger_name'] as String,
      passengerPhone: json['passenger_phone'] as String?,
      passengerAvatar: json['passenger_avatar'] as String?,
      type: json['type'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: json['address'] as String,
      status: json['status'] as String,
      order: json['order'] as int,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      seatsBooked: json['seats_booked'] as int,
    );
  }

  /// Computed properties
  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isSkipped => status == 'skipped';
  bool get isPickup => type == 'pickup';
  bool get isDropoff => type == 'dropoff';

  /// Get display text for stop type
  String get typeDisplay => isPickup ? 'PICKUP' : 'DROPOFF';

  /// Get icon based on type
  String get iconEmoji => isPickup ? '📍' : '🏁';

  /// Get status emoji
  String get statusEmoji {
    if (isCompleted) return '✅';
    if (isSkipped) return '⏭️';
    return '⏳';
  }

  /// Copy with method
  RideStop copyWith({
    String? bookingId,
    String? passengerId,
    String? passengerName,
    String? passengerPhone,
    String? passengerAvatar,
    String? type,
    double? lat,
    double? lng,
    String? address,
    String? status,
    int? order,
    DateTime? completedAt,
    int? seatsBooked,
  }) {
    return RideStop(
      bookingId: bookingId ?? this.bookingId,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      passengerPhone: passengerPhone ?? this.passengerPhone,
      passengerAvatar: passengerAvatar ?? this.passengerAvatar,
      type: type ?? this.type,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      status: status ?? this.status,
      order: order ?? this.order,
      completedAt: completedAt ?? this.completedAt,
      seatsBooked: seatsBooked ?? this.seatsBooked,
    );
  }

  @override
  String toString() {
    return 'RideStop(order: $order, type: $type, passenger: $passengerName, status: $status, address: $address)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RideStop &&
        other.bookingId == bookingId &&
        other.type == type;
  }

  @override
  int get hashCode => bookingId.hashCode ^ type.hashCode;
}