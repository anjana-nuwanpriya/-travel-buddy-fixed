import 'package:intl/intl.dart';

class Ride {
  final String id;
  final String driverId;
  final String fromLocation;
  final double? fromLat;
  final double? fromLng;
  final double fromLatitude;
  final double fromLongitude;
  final String toLocation;
  final double? toLat;
  final double? toLng;
  final double toLatitude;
  final double toLongitude;
  final DateTime departureDate;
  final String departureTime;
  final DateTime dateTime;
  final int availableSeats;
  final double pricePerSeat;
  final String? vehicleType;
  final String? vehicleNumber;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? notes;
  final String status;
  final String? rideStatus;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;

  // Route info
  final String? routePolyline;
  final List<dynamic>? waypoints;
  final String? routeSummary;
  final String? distance;
  final String? duration;

  // Preferences
  final bool allowsSmoking;
  final bool allowsPets;
  final bool luggageAllowed;
  final bool? instantApproval;
  final bool? middleSeatEmpty;

  // Driver info
  final Map<String, dynamic>? driver;
  final String? driverName;
  final String? driverEmail;
  final String? driverPhone;
  final double? driverRating;

  // ✅ NEW: Bookings data for stop cards in driving mode
  final List<Map<String, dynamic>>? bookings;

  Ride({
    required this.id,
    required this.driverId,
    required this.fromLocation,
    this.fromLat,
    this.fromLng,
    required this.fromLatitude,
    required this.fromLongitude,
    required this.toLocation,
    this.toLat,
    this.toLng,
    required this.toLatitude,
    required this.toLongitude,
    required this.departureDate,
    required this.departureTime,
    required this.dateTime,
    required this.availableSeats,
    required this.pricePerSeat,
    this.vehicleType,
    this.vehicleNumber,
    this.vehicleMake,
    this.vehicleModel,
    this.notes,
    required this.status,
    this.rideStatus,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
    this.routePolyline,
    this.waypoints,
    this.routeSummary,
    this.distance,
    this.duration,
    this.allowsSmoking = false,
    this.allowsPets = false,
    this.luggageAllowed = false,
    this.instantApproval,
    this.middleSeatEmpty = false,
    this.driver,
    this.driverName,
    this.driverEmail,
    this.driverPhone,
    this.driverRating,
    this.bookings,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    print('📦 Parsing Ride from JSON');
    print('   Keys: ${json.keys.toList()}');

    // Handle driver data if it exists
    final driverData = json['driver'] as Map<String, dynamic>?;

    // ✅ NEW: Handle bookings data
    final bookingsData = json['bookings'] as List<dynamic>?;
    final List<Map<String, dynamic>>? parsedBookings = bookingsData
        ?.map((b) => Map<String, dynamic>.from(b as Map))
        .toList();

    // Parse date and time with better error handling
    DateTime parsedDateTime;
    try {
      // Try different date/time field names
      String? dateTimeStr = json['date_time'] as String?;
      dateTimeStr ??= json['departure_date'] as String?;
      
      if (dateTimeStr != null) {
        parsedDateTime = DateTime.parse(dateTimeStr);
      } else {
        parsedDateTime = DateTime.now();
      }
    } catch (e) {
      print('⚠️ Error parsing datetime: $e');
      parsedDateTime = DateTime.now();
    }

    // Helper function to safely parse double
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    try {
      return Ride(
        id: json['id'] as String? ?? 'unknown',
        driverId: json['driver_id'] as String? ?? '',
        fromLocation: json['from_location'] as String? ?? 'Unknown',
        fromLat: parseDouble(json['from_lat']),
        fromLng: parseDouble(json['from_lng']),
        fromLatitude: parseDouble(json['from_latitude']) ?? parseDouble(json['from_lat']) ?? 0.0,
        fromLongitude: parseDouble(json['from_longitude']) ?? parseDouble(json['from_lng']) ?? 0.0,
        toLocation: json['to_location'] as String? ?? 'Unknown',
        toLat: parseDouble(json['to_lat']),
        toLng: parseDouble(json['to_lng']),
        toLatitude: parseDouble(json['to_latitude']) ?? parseDouble(json['to_lat']) ?? 0.0,
        toLongitude: parseDouble(json['to_longitude']) ?? parseDouble(json['to_lng']) ?? 0.0,
        departureDate: json['departure_date'] != null
            ? DateTime.parse(json['departure_date'] as String)
            : parsedDateTime,
        departureTime: json['departure_time'] as String? ?? 
            DateFormat('HH:mm').format(parsedDateTime),
        dateTime: parsedDateTime,
        availableSeats: json['available_seats'] as int? ?? 1,
        pricePerSeat: parseDouble(json['price_per_seat']) ?? 0.0,
        vehicleType: json['vehicle_type'] as String?,
        vehicleNumber: json['vehicle_number'] as String?,
        vehicleMake: json['vehicle_make'] as String?,
        vehicleModel: json['vehicle_model'] as String?,
        notes: json['notes'] as String?,
        status: json['status'] as String? ?? 'active',
        rideStatus: json['ride_status'] as String?,
        startedAt: json['started_at'] != null
            ? DateTime.parse(json['started_at'] as String)
            : null,
        endedAt: json['ended_at'] != null
            ? DateTime.parse(json['ended_at'] as String)
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        routePolyline: json['route_polyline'] as String?,
        waypoints: json['waypoints'] as List<dynamic>?,
        routeSummary: json['route_summary'] as String?,
        distance: json['distance'] as String?,
        duration: json['duration'] as String?,
        allowsSmoking: json['allows_smoking'] as bool? ?? false,
        allowsPets: json['allows_pets'] as bool? ?? false,
        luggageAllowed: json['luggage_allowed'] as bool? ?? false,
        instantApproval: json['instant_approval'] as bool?,
        middleSeatEmpty: json['middle_seat_empty'] as bool? ?? false,
        driver: driverData,
        driverName: driverData?['full_name'] as String?,
        driverEmail: driverData?['email'] as String?,
        driverPhone: driverData?['phone'] as String?,
        driverRating: parseDouble(driverData?['rating']),
        bookings: parsedBookings,
      );
    } catch (e) {
      print('❌ Error parsing Ride: $e');
      print('   JSON: $json');
      
      // Return a minimal valid Ride object
      return Ride(
        id: json['id'] as String? ?? 'unknown',
        driverId: json['driver_id'] as String? ?? '',
        fromLocation: json['from_location'] as String? ?? 'Unknown',
        fromLatitude: 0.0,
        fromLongitude: 0.0,
        toLocation: json['to_location'] as String? ?? 'Unknown',
        toLatitude: 0.0,
        toLongitude: 0.0,
        departureDate: DateTime.now(),
        departureTime: '00:00',
        dateTime: DateTime.now(),
        availableSeats: json['available_seats'] as int? ?? 1,
        pricePerSeat: 0.0,
        status: json['status'] as String? ?? 'active',
        createdAt: DateTime.now(),
        bookings: null,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'from_location': fromLocation,
      'from_lat': fromLat,
      'from_lng': fromLng,
      'from_latitude': fromLatitude,
      'from_longitude': fromLongitude,
      'to_location': toLocation,
      'to_lat': toLat,
      'to_lng': toLng,
      'to_latitude': toLatitude,
      'to_longitude': toLongitude,
      'departure_date': departureDate.toIso8601String(),
      'departure_time': departureTime,
      'date_time': dateTime.toIso8601String(),
      'available_seats': availableSeats,
      'price_per_seat': pricePerSeat,
      'vehicle_type': vehicleType,
      'vehicle_number': vehicleNumber,
      'vehicle_make': vehicleMake,
      'vehicle_model': vehicleModel,
      'notes': notes,
      'status': status,
      'ride_status': rideStatus,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'route_polyline': routePolyline,
      'waypoints': waypoints,
      'route_summary': routeSummary,
      'distance': distance,
      'duration': duration,
      'allows_smoking': allowsSmoking,
      'allows_pets': allowsPets,
      'luggage_allowed': luggageAllowed,
      'instant_approval': instantApproval,
      'middle_seat_empty': middleSeatEmpty,
      'bookings': bookings,
    };
  }

  // Computed properties
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  bool get isScheduled => rideStatus == 'scheduled' || rideStatus == null;
  bool get isInProgress => rideStatus == 'in_progress';
  bool get isRideCompleted => rideStatus == 'completed';

  String get formattedDate => DateFormat('MMM dd, yyyy').format(dateTime);
  String get formattedTime => DateFormat('hh:mm a').format(dateTime);
  String get formattedDateTime =>
      DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);

  // ✅ NEW: Computed property for vehicle info
  String get vehicleInfo {
    if (vehicleMake != null && vehicleModel != null) {
      return '$vehicleMake $vehicleModel';
    }
    return vehicleType ?? 'Vehicle';
  }

  // ✅ NEW: Computed property for route description
  String get routeDescription {
    return '$fromLocation → $toLocation';
  }

  // Copy with method
  Ride copyWith({
    String? id,
    String? driverId,
    String? fromLocation,
    double? fromLat,
    double? fromLng,
    double? fromLatitude,
    double? fromLongitude,
    String? toLocation,
    double? toLat,
    double? toLng,
    double? toLatitude,
    double? toLongitude,
    DateTime? departureDate,
    String? departureTime,
    DateTime? dateTime,
    int? availableSeats,
    double? pricePerSeat,
    String? vehicleType,
    String? vehicleNumber,
    String? vehicleMake,
    String? vehicleModel,
    String? notes,
    String? status,
    String? rideStatus,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? createdAt,
    String? routePolyline,
    List<dynamic>? waypoints,
    String? routeSummary,
    String? distance,
    String? duration,
    bool? allowsSmoking,
    bool? allowsPets,
    bool? luggageAllowed,
    bool? middleSeatEmpty,
    bool? instantApproval,
    Map<String, dynamic>? driver,
    String? driverName,
    String? driverEmail,
    String? driverPhone,
    double? driverRating,
    List<Map<String, dynamic>>? bookings,
  }) {
    return Ride(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      fromLocation: fromLocation ?? this.fromLocation,
      fromLat: fromLat ?? this.fromLat,
      fromLng: fromLng ?? this.fromLng,
      fromLatitude: fromLatitude ?? this.fromLatitude,
      fromLongitude: fromLongitude ?? this.fromLongitude,
      toLocation: toLocation ?? this.toLocation,
      toLat: toLat ?? this.toLat,
      toLng: toLng ?? this.toLng,
      toLatitude: toLatitude ?? this.toLatitude,
      toLongitude: toLongitude ?? this.toLongitude,
      departureDate: departureDate ?? this.departureDate,
      departureTime: departureTime ?? this.departureTime,
      dateTime: dateTime ?? this.dateTime,
      availableSeats: availableSeats ?? this.availableSeats,
      pricePerSeat: pricePerSeat ?? this.pricePerSeat,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleMake: vehicleMake ?? this.vehicleMake,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      rideStatus: rideStatus ?? this.rideStatus,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt ?? this.createdAt,
      routePolyline: routePolyline ?? this.routePolyline,
      waypoints: waypoints ?? this.waypoints,
      routeSummary: routeSummary ?? this.routeSummary,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      allowsSmoking: allowsSmoking ?? this.allowsSmoking,
      allowsPets: allowsPets ?? this.allowsPets,
      luggageAllowed: luggageAllowed ?? this.luggageAllowed,
      middleSeatEmpty: middleSeatEmpty ?? this.middleSeatEmpty,
      instantApproval: instantApproval ?? this.instantApproval,
      driver: driver ?? this.driver,
      driverName: driverName ?? this.driverName,
      driverEmail: driverEmail ?? this.driverEmail,
      driverPhone: driverPhone ?? this.driverPhone,
      driverRating: driverRating ?? this.driverRating,
      bookings: bookings ?? this.bookings,
    );
  }
}