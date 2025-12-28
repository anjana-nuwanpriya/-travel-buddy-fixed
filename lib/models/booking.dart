import 'ride.dart';

class Booking {
  final String id;
  final String rideId;
  final String passengerId;
  final int seatsBooked;
  final double totalPrice;
  final String status;
  final DateTime createdAt;

  // 🔥 NEW: Pickup location
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupAddress;

  // 🔥 NEW: Dropoff location
  final double? dropoffLat;
  final double? dropoffLng;
  final String? dropoffAddress;

  // 🔥 NEW: Status tracking
  final String? pickupStatus; // 'pending', 'picked_up', 'skipped'
  final String? dropoffStatus; // 'pending', 'dropped_off', 'skipped'
  final DateTime? pickupTime;
  final DateTime? dropoffTime;

  // 🔥 NEW: Stop order
  final int? stopOrder;

  // Populated ride data
  final Ride? ride;
  final Map<String, dynamic>? passenger;

  // Additional fields from your app
  final String? driverName;
  final String? driverPhone;
  final String? routeDescription;
  final DateTime? departureDate;
  final String? departureTime;

  Booking({
    required this.id,
    required this.rideId,
    required this.passengerId,
    required this.seatsBooked,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.pickupLat,
    this.pickupLng,
    this.pickupAddress,
    this.dropoffLat,
    this.dropoffLng,
    this.dropoffAddress,
    this.pickupStatus,
    this.dropoffStatus,
    this.pickupTime,
    this.dropoffTime,
    this.stopOrder,
    this.ride,
    this.passenger,
    this.driverName,
    this.driverPhone,
    this.routeDescription,
    this.departureDate,
    this.departureTime,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    // Get ride data if present
    final rideData = json['ride'] as Map<String, dynamic>?;
    final passengerData = json['passenger'] as Map<String, dynamic>?;

    // Safely build route description
    String? buildRouteDescription() {
      if (json['route_description'] != null) {
        return json['route_description'] as String?;
      }
      
      if (rideData != null) {
        final fromLoc = rideData['from_location'];
        final toLoc = rideData['to_location'];
        
        if (fromLoc != null && toLoc != null) {
          return '$fromLoc → $toLoc';
        }
      }
      
      return null;
    }

    // Safely parse departure date
    DateTime? parseDepartureDate() {
      try {
        if (json['departure_date'] != null) {
          return DateTime.parse(json['departure_date'] as String);
        }
        
        if (rideData != null && rideData['departure_date'] != null) {
          return DateTime.parse(rideData['departure_date'] as String);
        }
        
        if (rideData != null && rideData['date_time'] != null) {
          return DateTime.parse(rideData['date_time'] as String);
        }
      } catch (e) {
        print('⚠️ Error parsing departure date: $e');
      }
      
      return null;
    }

    return Booking(
      id: json['id'] as String,
      rideId: json['ride_id'] as String,
      passengerId: json['passenger_id'] as String,
      seatsBooked: json['seats_booked'] as int,
      totalPrice: (json['total_price'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      
      // 🔥 NEW: Pickup location
      pickupLat: json['pickup_lat'] != null 
          ? (json['pickup_lat'] as num).toDouble() 
          : null,
      pickupLng: json['pickup_lng'] != null 
          ? (json['pickup_lng'] as num).toDouble() 
          : null,
      pickupAddress: json['pickup_address'] as String?,
      
      // 🔥 NEW: Dropoff location
      dropoffLat: json['dropoff_lat'] != null 
          ? (json['dropoff_lat'] as num).toDouble() 
          : null,
      dropoffLng: json['dropoff_lng'] != null 
          ? (json['dropoff_lng'] as num).toDouble() 
          : null,
      dropoffAddress: json['dropoff_address'] as String?,
      
      // 🔥 NEW: Status tracking
      pickupStatus: json['pickup_status'] as String?,
      dropoffStatus: json['dropoff_status'] as String?,
      pickupTime: json['pickup_time'] != null 
          ? DateTime.parse(json['pickup_time'] as String)
          : null,
      dropoffTime: json['dropoff_time'] != null 
          ? DateTime.parse(json['dropoff_time'] as String)
          : null,
      
      // 🔥 NEW: Stop order
      stopOrder: json['stop_order'] as int?,
      
      // Parse nested ride data if present
      ride: rideData != null ? Ride.fromJson(rideData) : null,
      // Parse passenger data if present
      passenger: passengerData,
      // Additional fields with safe null handling
      driverName:
          rideData?['driver']?['full_name'] as String? ??
          json['driver_name'] as String?,
      driverPhone:
          rideData?['driver']?['phone'] as String? ??
          json['driver_phone'] as String?,
      routeDescription: buildRouteDescription(),
      departureDate: parseDepartureDate(),
      departureTime:
          json['departure_time'] as String? ??
          rideData?['departure_time']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ride_id': rideId,
      'passenger_id': passengerId,
      'seats_booked': seatsBooked,
      'total_price': totalPrice,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      
      // 🔥 NEW: Pickup location
      if (pickupLat != null) 'pickup_lat': pickupLat,
      if (pickupLng != null) 'pickup_lng': pickupLng,
      if (pickupAddress != null) 'pickup_address': pickupAddress,
      
      // 🔥 NEW: Dropoff location
      if (dropoffLat != null) 'dropoff_lat': dropoffLat,
      if (dropoffLng != null) 'dropoff_lng': dropoffLng,
      if (dropoffAddress != null) 'dropoff_address': dropoffAddress,
      
      // 🔥 NEW: Status tracking
      if (pickupStatus != null) 'pickup_status': pickupStatus,
      if (dropoffStatus != null) 'dropoff_status': dropoffStatus,
      if (pickupTime != null) 'pickup_time': pickupTime!.toIso8601String(),
      if (dropoffTime != null) 'dropoff_time': dropoffTime!.toIso8601String(),
      
      // 🔥 NEW: Stop order
      if (stopOrder != null) 'stop_order': stopOrder,
      
      if (ride != null) 'ride': ride!.toJson(),
      if (passenger != null) 'passenger': passenger,
      if (driverName != null) 'driver_name': driverName,
      if (driverPhone != null) 'driver_phone': driverPhone,
      if (routeDescription != null) 'route_description': routeDescription,
      if (departureDate != null)
        'departure_date': departureDate!.toIso8601String(),
      if (departureTime != null) 'departure_time': departureTime,
    };
  }

  // Computed properties
  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
  
  // 🔥 NEW: Pickup/Dropoff status helpers
  bool get isPickedUp => pickupStatus == 'picked_up';
  bool get isDroppedOff => dropoffStatus == 'dropped_off';
  bool get isPickupPending => pickupStatus == null || pickupStatus == 'pending';
  bool get isDropoffPending => dropoffStatus == null || dropoffStatus == 'pending';

  // Copy with method
  Booking copyWith({
    String? id,
    String? rideId,
    String? passengerId,
    int? seatsBooked,
    double? totalPrice,
    String? status,
    DateTime? createdAt,
    double? pickupLat,
    double? pickupLng,
    String? pickupAddress,
    double? dropoffLat,
    double? dropoffLng,
    String? dropoffAddress,
    String? pickupStatus,
    String? dropoffStatus,
    DateTime? pickupTime,
    DateTime? dropoffTime,
    int? stopOrder,
    Ride? ride,
    Map<String, dynamic>? passenger,
    String? driverName,
    String? driverPhone,
    String? routeDescription,
    DateTime? departureDate,
    String? departureTime,
  }) {
    return Booking(
      id: id ?? this.id,
      rideId: rideId ?? this.rideId,
      passengerId: passengerId ?? this.passengerId,
      seatsBooked: seatsBooked ?? this.seatsBooked,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      pickupStatus: pickupStatus ?? this.pickupStatus,
      dropoffStatus: dropoffStatus ?? this.dropoffStatus,
      pickupTime: pickupTime ?? this.pickupTime,
      dropoffTime: dropoffTime ?? this.dropoffTime,
      stopOrder: stopOrder ?? this.stopOrder,
      ride: ride ?? this.ride,
      passenger: passenger ?? this.passenger,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      routeDescription: routeDescription ?? this.routeDescription,
      departureDate: departureDate ?? this.departureDate,
      departureTime: departureTime ?? this.departureTime,
    );
  }
}