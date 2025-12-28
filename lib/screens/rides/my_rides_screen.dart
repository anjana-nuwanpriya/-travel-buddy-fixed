import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/ride.dart';
import '../../models/booking.dart';
import '../../services/ride_service.dart';
import '../../services/booking_service.dart';
import '../../services/tracking_service.dart';
import '../../services/notification_service.dart';
import '../../services/ride_stops_service.dart';
import '../../utils/colors.dart';
import 'ride_details_screen.dart';
import 'live_tracking_passenger_screen.dart';
import 'passenger_management_screen.dart';

class MyRidesScreen extends StatefulWidget {
  final int initialTabIndex;
  
  const MyRidesScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();

  // ✅ Static method to navigate with success toast
  static void navigateToPublishedRides(BuildContext context) {
    print('📍 Navigating to Published Rides with success toast');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ride published successfully!',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    Future.delayed(Duration(milliseconds: 500), () {
      Navigator.pushNamed(
        context,
        '/my-rides',
        arguments: {'initialTabIndex': 1},
      );
    });
  }
}

class _MyRidesScreenState extends State<MyRidesScreen>
    with SingleTickerProviderStateMixin {
  final RideService _rideService = RideService();
  final BookingService _bookingService = BookingService();
  final TrackingService _trackingService = TrackingService();
  final NotificationService _notificationService = NotificationService();
  final RideStopsService _rideStopsService = RideStopsService();

  List<Ride> _publishedRides = [];
  List<Booking> _bookedRides = [];
  bool _isLoading = true;

  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    
    print('🟢 MyRidesScreen.initState() called');
    
    int tabIndex = widget.initialTabIndex;
    print('🔵 Initial tab index from widget: $tabIndex');
    
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: tabIndex,
    );
    _selectedTabIndex = tabIndex;
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
          print('📍 Tab changed to: $_selectedTabIndex');
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args.containsKey('initialTabIndex')) {
        final routeTabIndex = args['initialTabIndex'] as int;
        print('🔵 Route argument tab index: $routeTabIndex');
        
        if (routeTabIndex != tabIndex && _tabController.length > 0) {
          print('✅ Updating tab to: $routeTabIndex');
          _tabController.animateTo(routeTabIndex);
          setState(() {
            _selectedTabIndex = routeTabIndex;
          });
        }
      }
    });

    _loadAllRides();
  }

  Future<void> _loadAllRides() async {
    print('🟡 _loadAllRides() called - OPTIMIZED VERSION');
    setState(() => _isLoading = true);

    try {
      print('📍 Fetching published rides (NO driver info queries)...');
      final publishedResult = await _rideService.getMyRides();
      
      print('📍 Fetching booked rides...');
      final bookedResult = await _bookingService.getMyBookings();

      if (mounted) {
        setState(() {
          if (publishedResult['success']) {
            _publishedRides = publishedResult['rides'] as List<Ride>;
            print('✅ Loaded ${_publishedRides.length} published rides FAST');
          }
          if (bookedResult['success']) {
            _bookedRides = bookedResult['bookings'] as List<Booking>;
            print('✅ Loaded ${_bookedRides.length} booked rides');
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading rides: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inProgressCount = _publishedRides
        .where((r) => r.rideStatus == 'in_progress')
        .length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My rides',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_selectedTabIndex == 1 && inProgressCount > 0)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _stopAllActiveRides,
                icon: Icon(Icons.stop_circle, size: 18),
                label: Text('Stop All'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  backgroundColor: Colors.red.withOpacity(0.1),
                  padding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
          tabs: [
            Tab(text: 'Booked'),
            Tab(text: 'Published'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBookedRidesTab(),
                _buildPublishedRidesTab(),
              ],
            ),
    );
  }

  Widget _buildBookedRidesTab() {
    if (_bookedRides.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_seat,
        message: 'No booked rides',
        subMessage: 'Your booked rides will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllRides,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _bookedRides.length,
        itemBuilder: (context, index) {
          return _buildBookedRideCard(_bookedRides[index]);
        },
      ),
    );
  }

  Widget _buildBookedRideCard(Booking booking) {
    final ride = booking.ride;
    if (ride == null) return SizedBox.shrink();

    Color statusColor;
    String statusText;
    
    switch (booking.status) {
      case 'confirmed':
        statusColor = Colors.green;
        statusText = 'Upcoming';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusText = booking.status;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: AppColors.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ride.fromLocation.split(',').first,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ride.toLocation.split(',').first,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Rs ${booking.totalPrice.toStringAsFixed(0)}',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(ride.formattedDate, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                SizedBox(width: 16),
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(ride.formattedTime, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
          SizedBox(height: 16),
          if (booking.status == 'confirmed' && ride.rideStatus == 'in_progress')
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _trackRide(booking),
                  icon: Icon(Icons.location_on, size: 20),
                  label: Text('Track Ride', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            )
          else
            SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPublishedRidesTab() {
    if (_publishedRides.isEmpty) {
      return _buildEmptyState(
        icon: Icons.directions_car,
        message: 'No published rides',
        subMessage: 'Publish a ride to start earning',
        showButton: true,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllRides,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _publishedRides.length,
        itemBuilder: (context, index) {
          return _buildPublishedRideCard(_publishedRides[index]);
        },
      ),
    );
  }

  Widget _buildPublishedRideCard(Ride ride) {
    final bool isRideInProgress = ride.rideStatus == 'in_progress';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isRideInProgress ? Border.all(color: Colors.green, width: 2) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ride.fromLocation.split(',').first,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ride.toLocation.split(',').first,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Rs ${ride.pricePerSeat.toStringAsFixed(0)} per seat',
              style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(ride.formattedDate, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                SizedBox(width: 16),
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(ride.formattedTime, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _bookingService.getRideBookings(ride.id),
              builder: (context, snapshot) {
                final count = snapshot.data?['bookings']?.length ?? 0;
                return Text(
                  '$count ${count == 1 ? 'Passenger' : 'Passengers'}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                );
              },
            ),
          ),
          SizedBox(height: 16),
          if (ride.status == 'active') ...[
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  if (ride.rideStatus == null || ride.rideStatus == 'scheduled')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _startRide(ride),
                        icon: Icon(Icons.navigation, size: 20),
                        label: Text('Start Ride', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    )
                  else if (ride.rideStatus == 'in_progress') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _viewDrivingMode(ride),
                        icon: Icon(Icons.navigation, size: 20),
                        label: Text('View Driving Mode', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _endRide(ride),
                        icon: Icon(Icons.stop, size: 20),
                        label: Text('End Ride', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => RideDetailsScreen(ride: ride)),
                        ).then((_) => _loadAllRides());
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey[400]!),
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('View Details'),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ride.status == 'completed' ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      ride.status == 'completed' ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: ride.status == 'completed' ? Colors.green : Colors.grey,
                    ),
                    SizedBox(width: 8),
                    Text(
                      ride.status == 'completed' ? 'Completed' : 'Cancelled',
                      style: TextStyle(
                        color: ride.status == 'completed' ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== ACTIONS ====================
  
  Future<void> _trackRide(Booking booking) async {
    if (booking.ride == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Ride data not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveTrackingPassengerScreen(
          ride: booking.ride!,
          bookingId: booking.id,
        ),
      ),
    );
  }

  // ✅ FIXED: Fetch ride with bookings before navigation
  Future<void> _viewDrivingMode(Ride ride) async {
    try {
      print('🔵 Fetching ride with bookings...');
      
      // Fetch ride WITH booking data
      final rideWithBookings = await _rideService.getRideWithBookings(ride.id);
      
      print('✅ Ride with bookings fetched');
      print('   Bookings: ${rideWithBookings.bookings?.length ?? 0}');
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PassengerManagementScreen(
              ride: rideWithBookings,  // ← Now has bookings!
            ),
          ),
        ).then((_) => _loadAllRides());
      }
    } catch (e) {
      print('❌ Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading ride: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startRide(Ride ride) async {
    final hasPermission = await _trackingService.checkLocationPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permission is required to start ride'), backgroundColor: Colors.red),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start Ride?'),
        content: Text(
          'This will:\n• Calculate optimal pickup/dropoff route\n• Start GPS tracking\n• Notify passengers',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Start'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      print('🚀 Starting ride tracking...');
      
      final trackingResult = await _trackingService.startRideTracking(ride.id);

      if (!trackingResult['success']) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start tracking: ${trackingResult['error']}'), backgroundColor: Colors.red),
        );
        return;
      }

      final ridesResult = await _rideService.getMyRides();
      Ride freshRide = ride;
      if (ridesResult['success']) {
        final rides = ridesResult['rides'] as List<Ride>;
        try {
          freshRide = rides.firstWhere((r) => r.id == ride.id);
        } catch (e) {
          print('⚠️ Could not find fresh ride data, using original');
        }
      }

      print('📊 Calculating optimized route for passengers...');

      final routeResult = await _rideStopsService.calculateOptimizedRoute(
        freshRide.id,
        freshRide.fromLatitude,
        freshRide.fromLongitude,
      );

      Navigator.pop(context);

      if (routeResult['success']) {
        final stopsCount = routeResult['stops_count'] ?? 0;
        print('✅ Route optimized: $stopsCount stops calculated');

        final bookingsResult = await _bookingService.getRideBookings(freshRide.id);
        if (bookingsResult['success']) {
          final bookings = bookingsResult['bookings'] as List;
          for (var booking in bookings) {
            if (booking['status'] == 'confirmed') {
              await _notificationService.sendNotification(
                userId: booking['passenger_id'],
                title: '🚗 Ride Started!',
                message: 'Your ride has started. Track it now!',
                type: 'ride_started',
                data: {'ride_id': freshRide.id, 'booking_id': booking['id']},
              );
            }
          }
        }

        // ✅ FIXED: Fetch ride with bookings before opening passenger management
        try {
          print('🔵 Fetching ride with bookings before opening management screen...');
          final rideWithBookings = await _rideService.getRideWithBookings(freshRide.id);
          
          print('✅ Ride with bookings fetched');
          print('   Bookings: ${rideWithBookings.bookings?.length ?? 0}');
          
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PassengerManagementScreen(
                  ride: rideWithBookings,  // ← Now has bookings!
                ),
              ),
            );
            _loadAllRides();
          }
        } catch (e) {
          print('❌ Error loading ride with bookings: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ No confirmed passengers to pick up yet'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadAllRides();
      }
    } catch (e) {
      Navigator.pop(context);
      print('❌ Error in _startRide: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting ride: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _endRide(Ride ride) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End Ride?'),
        content: Text('Are you sure you want to end this ride?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('End'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await _trackingService.endRideTracking(ride.id);

      if (result['success']) {
        final bookingsResult = await _bookingService.getRideBookings(ride.id);
        if (bookingsResult['success']) {
          final bookings = bookingsResult['bookings'] as List;
          for (var booking in bookings) {
            if (booking['status'] == 'confirmed') {
              await _notificationService.sendNotification(
                userId: booking['passenger_id'],
                title: '🏁 Ride Completed!',
                message: 'Your ride has been completed. Thank you!',
                type: 'ride_completed',
                data: {'ride_id': ride.id, 'booking_id': booking['id']},
              );
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ride completed successfully!'), backgroundColor: Colors.green),
        );
        _loadAllRides();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _stopAllActiveRides() async {
    final inProgressRides = _publishedRides.where((ride) => ride.rideStatus == 'in_progress').toList();

    if (inProgressRides.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stop All Rides?'),
        content: Text('Stop all ${inProgressRides.length} rides in progress?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Stop All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      for (final ride in inProgressRides) {
        await _trackingService.endRideTracking(ride.id);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All rides stopped successfully!'), backgroundColor: Colors.green),
      );
      _loadAllRides();
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subMessage,
    bool showButton = false,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          SizedBox(height: 8),
          Text(subMessage, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          if (showButton) ...[
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/post-ride').then((_) => _loadAllRides());
              },
              icon: Icon(Icons.add),
              label: Text('Publish a Ride'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}