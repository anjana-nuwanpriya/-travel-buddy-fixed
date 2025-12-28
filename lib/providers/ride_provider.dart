import 'package:flutter/material.dart';
import '../models/ride.dart';
import '../models/booking.dart';

class RideProvider with ChangeNotifier {
  List<Ride> _availableRides = [];
  final List<Booking> _bookings = [];
  final List<Ride> _publishedRides = [];
  bool _isLoading = false;

  List<Ride> get availableRides => _availableRides;
  List<Booking> get bookings => _bookings;
  List<Ride> get publishedRides => _publishedRides;
  bool get isLoading => _isLoading;

  Future<void> searchRides({
    required String from,
    required String to,
    required DateTime date,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.delayed(Duration(seconds: 1));
      _availableRides = _getMockRides(from, to, date);
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> bookRide(String rideId, int seats) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.delayed(Duration(seconds: 1));

      final booking = Booking(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        rideId: rideId,
        passengerId: 'current_user',
        seatsBooked: seats,
        totalPrice: 450.0 * seats,
        status: 'confirmed',
        createdAt: DateTime.now(),
      );

      _bookings.add(booking);
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> publishRide(Ride ride) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.delayed(Duration(seconds: 1));
      _publishedRides.add(ride);
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  List<Ride> _getMockRides(String from, String to, DateTime date) {
    // Parse coordinates from location strings (mock data)
    double fromLat = 6.9271;
    double fromLng = 79.8612;
    double toLat = 7.2906;
    double toLng = 80.6337;

    return [
      Ride(
        id: '1',
        driverId: 'driver1',
        fromLocation: from,
        fromLat: fromLat,
        fromLng: fromLng,
        fromLatitude: fromLat,
        fromLongitude: fromLng,
        toLocation: to,
        toLat: toLat,
        toLng: toLng,
        toLatitude: toLat,
        toLongitude: toLng,
        departureDate: date,
        departureTime: '08:00',
        dateTime: DateTime(date.year, date.month, date.day, 8, 0),
        availableSeats: 3,
        pricePerSeat: 450.0,
        vehicleType: 'SUV',
        vehicleNumber: 'ABC-1234',
        vehicleMake: 'Toyota',
        vehicleModel: 'Innova',
        notes: 'AC available, Music allowed',
        status: 'active',
        createdAt: DateTime.now(),
        allowsSmoking: false,
        allowsPets: false,
        luggageAllowed: true,
        instantApproval: true,
        driverName: 'John Doe',
        driverEmail: 'john@example.com',
        driverPhone: '+94771234567',
        driverRating: 4.8,
      ),
      Ride(
        id: '2',
        driverId: 'driver2',
        fromLocation: from,
        fromLat: fromLat,
        fromLng: fromLng,
        fromLatitude: fromLat,
        fromLongitude: fromLng,
        toLocation: to,
        toLat: toLat,
        toLng: toLng,
        toLatitude: toLat,
        toLongitude: toLng,
        departureDate: date,
        departureTime: '10:30',
        dateTime: DateTime(date.year, date.month, date.day, 10, 30),
        availableSeats: 2,
        pricePerSeat: 500.0,
        vehicleType: 'Sedan',
        vehicleNumber: 'XYZ-5678',
        vehicleMake: 'Honda',
        vehicleModel: 'Civic',
        notes: 'Comfortable ride, No smoking',
        status: 'active',
        createdAt: DateTime.now(),
        allowsSmoking: false,
        allowsPets: true,
        luggageAllowed: true,
        instantApproval: false,
        driverName: 'Jane Smith',
        driverEmail: 'jane@example.com',
        driverPhone: '+94777654321',
        driverRating: 4.9,
      ),
    ];
  }
}
