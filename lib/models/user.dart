class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final double rating;
  final int totalTrips;
  final DateTime memberSince;
  final bool isVerified;
  final String? profileImage;
  final List<Vehicle>? vehicles;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.rating,
    required this.totalTrips,
    required this.memberSince,
    required this.isVerified,
    this.profileImage,
    this.vehicles,
  });
}

class Vehicle {
  final String id;
  final String make;
  final String model;
  final String year;
  final String color;
  final String plateNumber;
  final int seats;
  final bool isVerified;

  Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plateNumber,
    required this.seats,
    required this.isVerified,
  });
}
