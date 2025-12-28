import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/booking.dart';
import 'notification_service.dart';

class BookingService {
  final SupabaseClient _client = SupabaseConfig.client;
  final NotificationService _notificationService = NotificationService();

  /// ✅ BULLETPROOF: Create booking with TRIPLE seat validation & rollback
  Future<Map<String, dynamic>> createBooking({
    required String rideId,
    required int seatsBooked,
    required double totalPrice,
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
  }) async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      print('🔵 Creating booking with passenger locations...');
      print('Ride ID: $rideId, Seats: $seatsBooked, Price: $totalPrice');
      print('📍 Pickup: $pickupAddress ($pickupLat, $pickupLng)');
      print('📍 Dropoff: $dropoffAddress ($dropoffLat, $dropoffLng)');

      // ✅ VALIDATION CHECK #1: Get ride data with ALL needed fields
      print('📊 VALIDATION #1: Fetching ride data...');
      final rideResponse = await _client
          .from('rides')
          .select('id, available_seats, driver_id, from_location, to_location, status')
          .eq('id', rideId)
          .single();

      final availableSeats = rideResponse['available_seats'] as int;
      final driverId = rideResponse['driver_id'] as String;
      final fromLocation = rideResponse['from_location'] as String;
      final toLocation = rideResponse['to_location'] as String;
      final rideStatus = rideResponse['status'] as String?;

      print('📊 Ride Information:');
      print('   Ride ID: $rideId');
      print('   Available Seats: $availableSeats');
      print('   Seats Requested: $seatsBooked');
      print('   Ride Status: $rideStatus');

      // ✅ VALIDATION CHECK #2: Check if ride is active
      if (rideStatus != 'active' && rideStatus != null) {
        print('❌ VALIDATION #2 FAILED: Ride is not active');
        return {
          'success': false,
          'error': 'This ride is no longer available (Status: $rideStatus)',
        };
      }

      // ✅ VALIDATION CHECK #3: Ensure seats requested is valid
      if (seatsBooked <= 0) {
        print('❌ VALIDATION #3 FAILED: Invalid seat count');
        return {
          'success': false,
          'error': 'You must book at least 1 seat',
        };
      }

      // ✅ VALIDATION CHECK #4: Check if enough seats available
      if (availableSeats < seatsBooked) {
        print('❌ VALIDATION #4 FAILED: Not enough seats!');
        print('   Available: $availableSeats, Requested: $seatsBooked');
        return {
          'success': false,
          'error': 'Not enough seats available. Only $availableSeats seat${availableSeats > 1 ? 's' : ''} left.',
        };
      }

      // ✅ VALIDATION CHECK #5: Ensure result won't go negative
      final resultingSeats = availableSeats - seatsBooked;
      if (resultingSeats < 0) {
        print('❌ VALIDATION #5 FAILED: Would result in negative seats!');
        print('   Calculation: $availableSeats - $seatsBooked = $resultingSeats');
        return {
          'success': false,
          'error': 'Booking would violate seat constraint. This should not happen!',
        };
      }

      print('✅ ALL VALIDATIONS PASSED! Proceeding with booking...');

      // Get passenger info
      final passengerResponse = await _client
          .from('user_profiles')
          .select('full_name')
          .eq('id', userId)
          .single();

      final passengerName = passengerResponse['full_name'] ?? 'A passenger';

      // Prepare booking data
      final bookingData = {
        'ride_id': rideId,
        'passenger_id': userId,
        'seats_booked': seatsBooked,
        'total_price': totalPrice,
        'status': 'pending',
        'payment_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'pickup_address': pickupAddress,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'dropoff_address': dropoffAddress,
        'pickup_status': 'pending',
        'dropoff_status': 'pending',
      };

      // ✅ STEP 1: Create booking in database FIRST
      print('📝 STEP 1: Creating booking record...');
      String? createdBookingId;
      try {
        final response = await _client
            .from('bookings')
            .insert(bookingData)
            .select()
            .single();

        createdBookingId = response['id'] as String;
        print('✅ Booking created with ID: $createdBookingId');
      } catch (e) {
        print('❌ STEP 1 FAILED: Could not create booking');
        print('   Error: $e');
        return {
          'success': false,
          'error': 'Failed to create booking record: $e',
        };
      }

      // ✅ STEP 2: Update available seats (WITH ROLLBACK IF FAILS)
      print('🔄 STEP 2: Updating ride available seats...');
      print('   Current: $availableSeats → New: $resultingSeats');
      
      try {
        final updateResponse = await _client
            .from('rides')
            .update({
              'available_seats': resultingSeats,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', rideId)
            .select()
            .single();

        final confirmedSeats = updateResponse['available_seats'] as int;
        print('✅ Ride seats updated successfully');
        print('   Confirmed new seat count: $confirmedSeats');

        // Verify the update worked correctly
        if (confirmedSeats != resultingSeats) {
          print('❌ WARNING: Seat count mismatch!');
          print('   Expected: $resultingSeats, Got: $confirmedSeats');
          print('🔄 Rolling back booking due to mismatch...');
          
          try {
            await _client.from('bookings').delete().eq('id', createdBookingId);
            print('⚠️ Booking rolled back due to seat verification mismatch');
          } catch (rollbackError) {
            print('❌ CRITICAL: Rollback failed! Manual cleanup needed!');
            print('   Booking ID to delete manually: $createdBookingId');
          }
          
          return {
            'success': false,
            'error': 'Seat update verification failed. Booking cancelled.',
          };
        }
      } catch (e) {
        // If seat update fails, rollback the booking
        print('❌ STEP 2 FAILED: Could not update seats');
        print('   Error: $e');
        print('🔄 Attempting to rollback booking...');
        
        try {
          await _client
              .from('bookings')
              .delete()
              .eq('id', createdBookingId);
          print('⚠️ Booking rolled back successfully');
        } catch (rollbackError) {
          print('❌ CRITICAL: Rollback FAILED!');
          print('   Booking ID to delete manually: $createdBookingId');
          print('   Rollback Error: $rollbackError');
        }
        
        return {
          'success': false,
          'error': 'Failed to update ride availability. Booking cancelled. Error: $e',
        };
      }

      // ✅ STEP 3: Get booking data for response
      print('📖 STEP 3: Fetching booking details for response...');
      late final Booking createdBooking;
      try {
        final bookingResponseData = await _client
            .from('bookings')
            .select('*')
            .eq('id', createdBookingId)
            .single();
        
        createdBooking = Booking.fromJson(bookingResponseData);
        print('✅ Booking details retrieved');
      } catch (e) {
        print('⚠️ Warning: Could not fetch booking details: $e');
        // Continue anyway - booking is created
      }

      // ✅ STEP 4: Send notification to driver
      print('🔔 STEP 4: Sending notification to driver...');
      try {
        await _notificationService.sendNotification(
          userId: driverId,
          title: '🎫 New Booking Request',
          message: '$passengerName wants to book $seatsBooked seat${seatsBooked > 1 ? 's' : ''} from $pickupAddress to $dropoffAddress',
          type: 'booking_request',
          data: {'bookingId': createdBookingId},
        );
        print('✅ Notification sent to driver');
      } catch (e) {
        // Notification failure shouldn't fail the booking
        print('⚠️ Warning: Could not send notification: $e');
      }

      print('✅✅✅ BOOKING COMPLETED SUCCESSFULLY! ✅✅✅');
      print('   Booking ID: $createdBookingId');
      print('   Seats Booked: $seatsBooked');
      print('   Ride Seats Remaining: $resultingSeats');

      return {
        'success': true,
        'booking': createdBooking,
        'message': 'Booking created successfully',
      };
    } catch (e) {
      print('❌ UNEXPECTED ERROR: $e');
      print('   Error Type: ${e.runtimeType}');
      print('   Stack Trace: $e');
      
      // Parse error message for better UX
      String errorMessage = e.toString();
      if (errorMessage.contains('available_seats_check')) {
        errorMessage = 'Seat availability constraint violation. Please refresh and try again.';
      } else if (errorMessage.contains('violates check constraint')) {
        errorMessage = 'This ride no longer has enough seats. Please refresh the search.';
      } else if (errorMessage.contains('UNIQUE constraint failed')) {
        errorMessage = 'You already have a booking for this ride.';
      }
      
      return {'success': false, 'error': errorMessage};
    }
  }

  /// Get single booking details with all related data
  Future<Map<String, dynamic>> getBookingDetails(String bookingId) async {
    try {
      print('🔵 Fetching booking details: $bookingId');

      final response = await _client
          .from('bookings')
          .select('''
            *,
            ride:rides(*),
            passenger:user_profiles!bookings_passenger_id_fkey(*)
          ''')
          .eq('id', bookingId)
          .single();

      print('✅ Booking details fetched');

      final booking = Booking.fromJson(response);

      return {
        'success': true,
        'booking': booking,
      };
    } catch (e) {
      print('❌ Error fetching booking details: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get user's bookings (as passenger)
  Future<Map<String, dynamic>> getMyBookings() async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      print('🔵 Fetching user bookings...');

      final response = await _client
          .from('bookings')
          .select('''
            *,
            ride:rides(
              *,
              driver:user_profiles!rides_driver_id_fkey(
                id,
                full_name,
                email,
                phone
              )
            )
          ''')
          .eq('passenger_id', userId)
          .order('created_at', ascending: false);

      print('✅ Fetched ${response.length} bookings');

      final bookings = (response as List)
          .map((json) => Booking.fromJson(json))
          .toList();

      return {'success': true, 'bookings': bookings};
    } catch (e) {
      print('❌ Error fetching bookings: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get bookings for a ride (as driver)
  Future<Map<String, dynamic>> getRideBookings(String rideId) async {
    try {
      print('🔵 Fetching ride bookings...');

      final response = await _client
          .from('bookings')
          .select('''
            *,
            passenger:user_profiles!bookings_passenger_id_fkey(
              id,
              full_name,
              email,
              phone,
              avatar_url
            )
          ''')
          .eq('ride_id', rideId)
          .order('created_at', ascending: false);

      print('✅ Fetched ${response.length} bookings for ride');

      return {'success': true, 'bookings': response};
    } catch (e) {
      print('❌ Error fetching ride bookings: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update booking status
  Future<Map<String, dynamic>> updateBookingStatus(
    String bookingId,
    String status,
  ) async {
    try {
      print('🔵 Updating booking status to: $status');

      final response = await _client
          .from('bookings')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId)
          .select()
          .single();

      print('✅ Booking status updated');

      return {
        'success': true,
        'booking': Booking.fromJson(response),
        'message': 'Booking status updated',
      };
    } catch (e) {
      print('❌ Error updating booking: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cancel booking
  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      print('🔵 Cancelling booking...');

      final bookingResponse = await _client
          .from('bookings')
          .select('ride_id, seats_booked, status')
          .eq('id', bookingId)
          .single();

      if (bookingResponse['status'] == 'cancelled') {
        return {'success': false, 'error': 'Booking already cancelled'};
      }

      await _client
          .from('bookings')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      final rideId = bookingResponse['ride_id'];
      final seatsBooked = bookingResponse['seats_booked'] as int;

      final rideResponse = await _client
          .from('rides')
          .select('available_seats')
          .eq('id', rideId)
          .single();

      final currentAvailableSeats = rideResponse['available_seats'] as int;

      await _client
          .from('rides')
          .update({
            'available_seats': currentAvailableSeats + seatsBooked,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId);

      print('✅ Booking cancelled and seats returned');

      return {'success': true, 'message': 'Booking cancelled successfully'};
    } catch (e) {
      print('❌ Error cancelling booking: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check if user has existing booking for a ride
  Future<bool> hasExistingBooking(String rideId) async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _client
          .from('bookings')
          .select('id')
          .eq('ride_id', rideId)
          .eq('passenger_id', userId)
          .not('status', 'eq', 'cancelled');

      return response.isNotEmpty;
    } catch (e) {
      print('❌ Error checking existing booking: $e');
      return false;
    }
  }

  /// Confirm booking (driver accepts)
  Future<Map<String, dynamic>> confirmBooking(String bookingId) async {
    return updateBookingStatus(bookingId, 'confirmed');
  }

  /// Complete booking (ride finished)
  Future<Map<String, dynamic>> completeBooking(String bookingId) async {
    return updateBookingStatus(bookingId, 'completed');
  }

  /// Update payment status
  Future<Map<String, dynamic>> updatePaymentStatus(
    String bookingId,
    String paymentStatus,
  ) async {
    try {
      print('🔵 Updating payment status to: $paymentStatus');

      await _client
          .from('bookings')
          .update({
            'payment_status': paymentStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      print('✅ Payment status updated');

      return {'success': true, 'message': 'Payment status updated'};
    } catch (e) {
      print('❌ Error updating payment: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get booking statistics for user
  Future<Map<String, dynamic>> getBookingStats() async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final response = await _client
          .from('bookings')
          .select('status, seats_booked, total_price')
          .eq('passenger_id', userId);

      int totalBookings = response.length;
      int completedBookings = response.where((b) => b['status'] == 'completed').length;
      int pendingBookings = response.where((b) => b['status'] == 'pending').length;
      int cancelledBookings = response.where((b) => b['status'] == 'cancelled').length;

      double totalSpent = response.fold(0.0, (sum, b) {
        if (b['status'] != 'cancelled') {
          return sum + (double.tryParse(b['total_price'].toString()) ?? 0.0);
        }
        return sum;
      });

      return {
        'success': true,
        'stats': {
          'total': totalBookings,
          'completed': completedBookings,
          'pending': pendingBookings,
          'cancelled': cancelledBookings,
          'totalSpent': totalSpent,
        },
      };
    } catch (e) {
      print('❌ Error getting stats: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get booking requests for driver
  Future<Map<String, dynamic>> getMyBookingRequests() async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        print('❌ User not authenticated');
        return {'success': false, 'error': 'User not authenticated'};
      }

      print('🔵 Fetching booking requests for driver: $userId');

      final ridesResponse = await _client.from('rides').select('id').eq('driver_id', userId);

      print('📊 Found ${ridesResponse.length} rides for this driver');

      if (ridesResponse.isEmpty) {
        print('⚠️ Driver has no rides posted');
        return {'success': true, 'bookings': []};
      }

      final rideIds = (ridesResponse as List).map((r) => r['id'].toString()).toList();

      print('🔍 Searching for bookings in rides: $rideIds');

      final bookingsResponse = await _client
          .from('bookings')
          .select('''
            *,
            ride:rides(
              *,
              driver:user_profiles!rides_driver_id_fkey(
                id,
                full_name,
                email,
                phone
              )
            ),
            passenger:user_profiles!bookings_passenger_id_fkey(
              id,
              full_name,
              email,
              phone,
              avatar_url
            )
          ''')
          .inFilter('ride_id', rideIds)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      print('✅ Found ${bookingsResponse.length} pending booking requests');

      final bookings = (bookingsResponse as List).map((json) => Booking.fromJson(json)).toList();

      return {'success': true, 'bookings': bookings};
    } catch (e) {
      print('❌ Error fetching booking requests: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Approve booking - FIXED: Only ONE notification sent
  Future<Map<String, dynamic>> approveBooking(String bookingId) async {
    try {
      print('🔵 Approving booking: $bookingId');

      final bookingResponse = await _client
          .from('bookings')
          .select('''
            *,
            ride:rides(id, from_location, to_location, driver_id),
            passenger:user_profiles!bookings_passenger_id_fkey(id, full_name)
          ''')
          .eq('id', bookingId)
          .single();

      final passengerId = bookingResponse['passenger']['id'];
      final passengerName = bookingResponse['passenger']['full_name'] ?? 'Passenger';
      final rideId = bookingResponse['ride']['id'];
      final driverId = bookingResponse['ride']['driver_id'];
      final fromLocation = bookingResponse['ride']['from_location'];
      final toLocation = bookingResponse['ride']['to_location'];

      // Step 1: Update booking status
      final result = await updateBookingStatus(bookingId, 'confirmed');

      if (result['success']) {
        try {
          // Step 2: Create conversation if doesn't exist
          final existingConv = await _client
              .from('conversations')
              .select('id')
              .eq('ride_id', rideId)
              .or('and(participant1_id.eq.$driverId,participant2_id.eq.$passengerId),and(participant1_id.eq.$passengerId,participant2_id.eq.$driverId)')
              .maybeSingle();

          if (existingConv == null) {
            final welcomeMessage = '🎉 Booking confirmed! Looking forward to the ride from $fromLocation to $toLocation.';

            final convResponse = await _client.from('conversations').insert({
              'ride_id': rideId,
              'participant1_id': driverId,
              'participant2_id': passengerId,
              'last_message': welcomeMessage,
              'last_message_time': DateTime.now().toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
            }).select('id').single();

            await _client.from('messages').insert({
              'conversation_id': convResponse['id'],
              'sender_id': driverId,
              'message': welcomeMessage,
              'message_type': 'text',
              'is_read': false,
              'created_at': DateTime.now().toIso8601String(),
            });

            print('✅ Conversation created and welcome message sent');
          }
        } catch (e) {
          print('⚠️ Error creating conversation: $e');
        }

        // Step 3: Send ONE notification only using sendNotification
        print('🔔 Sending confirmation notification to passenger...');
        await _notificationService.sendNotification(
          userId: passengerId,
          title: '✅ Booking Confirmed!',
          message: 'Your booking for $fromLocation → $toLocation has been confirmed!',
          type: 'booking_confirmed',
          data: {'bookingId': bookingId},
        );

        print('✅ Booking approved and passenger notified (ONE notification)');
      }

      return result;
    } catch (e) {
      print('❌ Error approving booking: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Reject booking - FIXED: Only ONE notification sent
  Future<Map<String, dynamic>> rejectBooking(String bookingId) async {
    try {
      print('🔵 Rejecting booking: $bookingId');

      final bookingResponse = await _client
          .from('bookings')
          .select('''
            ride_id,
            seats_booked,
            status,
            ride:rides(from_location, to_location),
            passenger:user_profiles!bookings_passenger_id_fkey(id, full_name)
          ''')
          .eq('id', bookingId)
          .single();

      final passengerId = bookingResponse['passenger']['id'];
      final fromLocation = bookingResponse['ride']['from_location'];
      final toLocation = bookingResponse['ride']['to_location'];

      // Step 1: Update booking status to cancelled
      await _client
          .from('bookings')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      // Step 2: Return seats to ride
      final rideId = bookingResponse['ride_id'];
      final seatsBooked = bookingResponse['seats_booked'] as int;

      final rideResponse = await _client.from('rides').select('available_seats').eq('id', rideId).single();

      final currentAvailableSeats = rideResponse['available_seats'] as int;

      await _client
          .from('rides')
          .update({
            'available_seats': currentAvailableSeats + seatsBooked,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId);

      // Step 3: Send ONE notification only using sendNotification
      print('🔔 Sending rejection notification to passenger...');
      await _notificationService.sendNotification(
        userId: passengerId,
        title: '❌ Booking Declined',
        message: 'Your booking request for $fromLocation → $toLocation was declined by the driver',
        type: 'booking_declined',
        data: {'bookingId': bookingId},
      );

      print('✅ Booking rejected, seats returned, and passenger notified (ONE notification)');

      return {'success': true, 'message': 'Booking rejected'};
    } catch (e) {
      print('❌ Error rejecting booking: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}