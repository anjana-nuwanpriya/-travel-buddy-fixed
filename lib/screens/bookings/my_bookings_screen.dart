import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../models/ride.dart';
import '../../services/booking_service.dart';
import '../../services/ride_tracking_service.dart';
import '../../services/message_service.dart';
import '../../utils/colors.dart';
import '../../config/supabase_config.dart';
import '../rides/live_tracking_passenger_screen.dart';
import '../messages/chat_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final RideTrackingService _rideTrackingService = RideTrackingService();
  final MessageService _messageService = MessageService();

  List<Booking> _allBookings = [];
  List<Booking> _filteredBookings = [];
  bool _isLoading = true;

  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Track loading states for each ride
  final Map<String, bool> _rideLoadingStates = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
          _filterBookings();
        });
      }
    });
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);

    try {
      final result = await _bookingService.getMyBookings();

      if (result['success'] && mounted) {
        setState(() {
          _allBookings = result['bookings'] as List<Booking>;
          _filterBookings();
        });
      }
    } catch (e) {
      print('Error loading bookings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterBookings() {
    setState(() {
      switch (_selectedTabIndex) {
        case 0: // Upcoming
          _filteredBookings = _allBookings
              .where((b) => b.status == 'confirmed' || b.status == 'pending')
              .toList();
          break;
        case 1: // Completed
          _filteredBookings = _allBookings
              .where((b) => b.status == 'completed')
              .toList();
          break;
        case 2: // Cancelled
          _filteredBookings = _allBookings
              .where((b) => b.status == 'cancelled')
              .toList();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Bookings',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(
              text:
                  'Upcoming (${_allBookings.where((b) => b.status == 'confirmed' || b.status == 'pending').length})',
            ),
            Tab(
              text:
                  'Completed (${_allBookings.where((b) => b.status == 'completed').length})',
            ),
            Tab(
              text:
                  'Cancelled (${_allBookings.where((b) => b.status == 'cancelled').length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _filteredBookings.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    itemCount: _filteredBookings.length,
                    itemBuilder: (context, index) {
                      return _buildBookingCard(_filteredBookings[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final ride = booking.ride;
    if (ride == null) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      ride.formattedDate,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.access_time, size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      ride.formattedTime,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(booking.status),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Route
                Row(
                  children: [
                    Icon(
                      Icons.radio_button_checked,
                      size: 16,
                      color: Colors.green,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ride.fromLocation.split(',').first,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: EdgeInsets.only(left: 7),
                  child: Container(
                    height: 20,
                    width: 2,
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),

                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ride.toLocation.split(',').first,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Booking details
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBookingInfo(
                        Icons.event_seat,
                        '${booking.seatsBooked}',
                        'Seats',
                      ),
                      Container(width: 1, height: 30, color: Colors.grey[300]),
                      _buildBookingInfo(
                        Icons.payments,
                        'Rs. ${booking.totalPrice.toStringAsFixed(0)}',
                        'Total',
                      ),
                      Container(width: 1, height: 30, color: Colors.grey[300]),
                      _buildBookingInfo(
                        Icons.person,
                        (ride.driver?['full_name'] as String?)
                                ?.split(' ')
                                .first ??
                            'Driver',
                        'Driver',
                      ),
                    ],
                  ),
                ),

                // Action buttons for CONFIRMED bookings
                if (booking.status == 'confirmed') ...[
                  SizedBox(height: 16),

                  // Chat Button - ALWAYS SHOW for confirmed bookings
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openChatWithDriver(booking),
                      icon: Icon(Icons.chat_bubble_outline, size: 20),
                      label: Text(
                        'Chat with Driver',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary, width: 2),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 8),

                  // Check if ride is started and show track button
                  FutureBuilder<bool>(
                    future: _checkIfRideStarted(ride.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: null,
                            icon: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.grey,
                              ),
                            ),
                            label: Text('Checking status...'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey,
                              side: BorderSide(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      final isStarted = snapshot.data ?? false;

                      if (isStarted) {
                        // Ride has started - show TRACK button
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _viewLiveTracking(ride),
                            icon: Icon(Icons.navigation, size: 20),
                            label: Text(
                              'Track Ride Live',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        );
                      } else {
                        // Ride not started yet - show waiting message and cancel
                        return Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Waiting for driver to start the ride...',
                                      style: TextStyle(
                                        color: Colors.orange[800],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _cancelBooking(booking),
                                icon: Icon(Icons.cancel_outlined, size: 18),
                                label: Text('Cancel Booking'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: BorderSide(color: Colors.red),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],

                // Pending status message
                if (booking.status == 'pending') ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.hourglass_empty,
                          color: Colors.orange,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Waiting for driver confirmation...',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChatWithDriver(Booking booking) async {
    try {
      final ride = booking.ride;
      if (ride == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ride information not available'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      // Get or create conversation
      final conversationId = await _messageService.getOrCreateConversation(
        rideId: ride.id,
        otherUserId: ride.driverId,
      );

      // Hide loading
      if (mounted) Navigator.pop(context);

      if (conversationId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to open chat'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get full conversation data
      final conversations = await _messageService.getConversations();
      final conversation = conversations.firstWhere(
        (c) => c['id'] == conversationId,
        orElse: () => {
          'id': conversationId,
          'ride_id': ride.id,
          'participant1_id': SupabaseConfig.currentUserId,
          'participant2_id': ride.driverId,
          'participant1': null,
          'participant2': ride.driver,
          'ride': {
            'from_location': ride.fromLocation,
            'to_location': ride.toLocation,
          },
          'last_message': 'Start chatting',
          'last_message_time': DateTime.now().toIso8601String(),
        },
      );

      // Navigate to chat
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(conversation: conversation),
          ),
        );
      }
    } catch (e) {
      print('Error opening chat: $e');
      if (mounted) {
        Navigator.pop(context); // Hide loading if showing
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _checkIfRideStarted(String rideId) async {
    if (_rideLoadingStates[rideId] == true) {
      return false;
    }

    setState(() {
      _rideLoadingStates[rideId] = true;
    });

    try {
      final result = await _rideTrackingService.checkIfRideStarted(rideId);
      return result;
    } catch (e) {
      print('Error checking ride status: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _rideLoadingStates[rideId] = false;
        });
      }
    }
  }

  void _viewLiveTracking(Ride ride) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveTrackingPassengerScreen(
          rideId: ride.id,
          from: ride.fromLocation,
          to: ride.toLocation,
        ),
      ),
    );
  }

  Widget _buildBookingInfo(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'confirmed':
        color = Colors.green;
        text = 'Confirmed';
        break;
      case 'pending':
        color = Colors.orange;
        text = 'Pending';
        break;
      case 'completed':
        color = Colors.blue;
        text = 'Completed';
        break;
      case 'cancelled':
        color = Colors.red;
        text = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    String subMessage;

    switch (_selectedTabIndex) {
      case 1:
        message = 'No completed bookings';
        subMessage = 'Your completed rides will appear here';
        break;
      case 2:
        message = 'No cancelled bookings';
        subMessage = 'Your cancelled bookings will appear here';
        break;
      default:
        message = 'No upcoming bookings';
        subMessage = 'Book a ride to start your journey';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_seat, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            subMessage,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          if (_selectedTabIndex == 0) ...[
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/search');
              },
              icon: Icon(Icons.search),
              label: Text('Find a Ride'),
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

  Future<void> _cancelBooking(Booking booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Booking?'),
        content: Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _bookingService.cancelBooking(booking.id);

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Booking cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadBookings();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Failed to cancel booking'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}