import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/colors.dart';
import '../../services/ride_service.dart';
import '../../models/ride.dart';
import 'ride_details_screen.dart';

class BrowseRidesScreen extends StatefulWidget {
  const BrowseRidesScreen({super.key});

  @override
  _BrowseRidesScreenState createState() => _BrowseRidesScreenState();
}

class _BrowseRidesScreenState extends State<BrowseRidesScreen> {
  final RideService _rideService = RideService();

  List<Ride> _allRides = [];
  List<Ride> _filteredRides = [];
  bool _isLoading = false;
  String _selectedTab = 'All';

  String? _fromLocation;
  String? _toLocation;
  DateTime? _selectedDate;
  int _passengerCount = 1;

  // 🔥 PASSENGER PICKUP/DROPOFF COORDINATES
  double? _pickupLat;
  double? _pickupLng;
  double? _dropoffLat;
  double? _dropoffLng;

  // ✅ Store relevance scores
  final Map<String, double> _rideScores = {};

  @override
  void initState() {
    super.initState();
    // Don't load here - wait for didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _fromLocation = args['from'];
      _toLocation = args['to'];
      _selectedDate = args['date'];
      _passengerCount = args['passengers'] ?? 1;
      
      // 🔥 GET COORDINATES FROM home_screen.dart
      _pickupLat = args['fromLat'] as double?;
      _pickupLng = args['fromLng'] as double?;
      _dropoffLat = args['toLat'] as double?;
      _dropoffLng = args['toLng'] as double?;
      
      print('📍 Browse screen loaded with passenger locations:');
      print('   Pickup: $_fromLocation ($_pickupLat, $_pickupLng)');
      print('   Dropoff: $_toLocation ($_dropoffLat, $_dropoffLng)');
      print('   Passengers: $_passengerCount');
      
      // ⚠️ Validation check
      if (_pickupLat == null || _pickupLng == null || 
          _dropoffLat == null || _dropoffLng == null) {
        print('⚠️ WARNING: Some coordinates are missing!');
        _showError('Location coordinates missing. Please search again.');
        return;
      }

      // ✅ Load rides using Option C (Proximity-based search)
      _loadRidesByProximity();
    }
  }

  /// ✅ Load rides using proximity-based search with ranking
  Future<void> _loadRidesByProximity() async {
    setState(() => _isLoading = true);

    try {
      print('🚀 Starting proximity-based search...');
      
      final result = await _rideService.searchRidesByProximity(
        fromLat: _pickupLat!,
        fromLng: _pickupLng!,
        toLat: _dropoffLat!,
        toLng: _dropoffLng!,
        departureDate: _selectedDate!,
        minSeats: _passengerCount,
        searchRadius: 10.0, // 10 km search radius
      );

      if (result['success']) {
        // Store rides and scores
        final rides = result['rides'] as List<Ride>;
        final scoresList = result['scores'] as List<dynamic>?;
        
        // ✅ FIXED: Filter out rides with 0 available seats
        final availableRides = rides.where((ride) => ride.availableSeats > 0).toList();
        
        // Build score map for display
        if (scoresList != null) {
          for (var scoreItem in scoresList) {
            _rideScores[scoreItem['rideId']] = 
              double.parse(scoreItem['score']);
          }
        }
        
        setState(() {
          _allRides = availableRides;
          _applyFilter();
        });

        print('✅ Loaded ${availableRides.length} rides ranked by relevance');
        if (rides.length != availableRides.length) {
          print('🚫 Filtered out ${rides.length - availableRides.length} fully booked rides');
        }
      } else {
        _showError(result['error'] ?? 'Failed to load rides');
      }
    } catch (e) {
      print('Error loading rides: $e');
      _showError('Failed to load rides: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter() {
    switch (_selectedTab) {
      case 'All':
        _filteredRides = _allRides;
        break;
      case 'Free':
        _filteredRides = _allRides.where((r) => r.pricePerSeat == 0).toList();
        break;
      case 'Paid':
        _filteredRides = _allRides.where((r) => r.pricePerSeat > 0).toList();
        break;
      case 'Live':
        _filteredRides = _allRides;
        break;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _fromLocation ?? "From",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_forward, size: 16, color: Colors.black),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _toLocation ?? 'To',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_selectedDate != null)
              Text(
                'Date (${DateFormat('dd - MM - yyyy').format(_selectedDate!)}), $_passengerCount passenger${_passengerCount > 1 ? 's' : ''}',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text('Filter', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildTab('All', _allRides.length),
                SizedBox(width: 16),
                _buildTab(
                  'Free',
                  _allRides.where((r) => r.pricePerSeat == 0).length,
                ),
                SizedBox(width: 16),
                _buildTab(
                  'Paid',
                  _allRides.where((r) => r.pricePerSeat > 0).length,
                ),
                SizedBox(width: 16),
                _buildTab('Live', _allRides.length),
              ],
            ),
          ),

          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Text(
              _filteredRides.isEmpty && !_isLoading
                  ? 'No rides found'
                  : 'Results by relevance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _filteredRides.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: EdgeInsets.only(top: 8),
                    itemCount: _filteredRides.length,
                    itemBuilder: (context, index) =>
                        _buildRideCard(_filteredRides[index], index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count) {
    final isSelected = _selectedTab == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = label;
          _applyFilter();
        });
      },
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.black : Colors.grey[600],
            ),
          ),
          Text(
            '$count',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          SizedBox(height: 4),
          if (isSelected)
            Container(height: 2, width: 40, color: AppColors.primary),
        ],
      ),
    );
  }

  /// ✅ Updated ride card with relevance badge and available seats
  Widget _buildRideCard(Ride ride, int position) {
    final driverName =
        ride.driver?['full_name'] as String? ?? ride.driverName ?? 'Driver';
    
    // Get relevance score
    final score = _rideScores[ride.id] ?? 0.0;
    final relevanceText = _getRelevanceText(score);
    final relevanceColor = _getRelevanceColor(score);
    
    // ✅ Determine seat color based on availability
    final seatColor = ride.availableSeats > 3 
        ? Colors.green 
        : ride.availableSeats > 1 
            ? Colors.orange 
            : Colors.red;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: InkWell(
        onTap: () {
          // 🔥 VALIDATION: Check if coordinates exist before navigation
          if (_pickupLat == null || _pickupLng == null || 
              _dropoffLat == null || _dropoffLng == null) {
            _showError('❌ Location coordinates missing. Please search again.');
            return;
          }

          // 🔥 PASS PASSENGER LOCATIONS VIA NAVIGATION
          print('🚀 Navigating to ride details with passenger locations:');
          print('   Pickup: $_fromLocation ($_pickupLat, $_pickupLng)');
          print('   Dropoff: $_toLocation ($_dropoffLat, $_dropoffLng)');
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RideDetailsScreen(ride: ride),
              settings: RouteSettings(
                arguments: {
                  'pickupLat': _pickupLat!,
                  'pickupLng': _pickupLng!,
                  'pickupAddress': _fromLocation ?? 'Unknown Pickup',
                  'dropoffLat': _dropoffLat!,
                  'dropoffLng': _dropoffLng!,
                  'dropoffAddress': _toLocation ?? 'Unknown Dropoff',
                },
              ),
            ),
          );
        },
        child: Column(
          children: [
            // ✅ Relevance badge at top
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${position + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: relevanceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: relevanceColor, width: 1),
                  ),
                  child: Text(
                    relevanceText,
                    style: TextStyle(
                      fontSize: 11,
                      color: relevanceColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Original ride details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Text(
                      ride.formattedTime,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 30),
                    Text(
                      _calculateArrivalTime(ride.formattedTime),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
                SizedBox(width: 12),
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 3),
                        color: Colors.white,
                      ),
                    ),
                    Container(width: 2, height: 40, color: AppColors.primary),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride.fromLocation.split(',').first,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ride.fromLocation.split(',').skip(1).join(',').trim(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 20),
                      Text(
                        ride.toLocation.split(',').first,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ride.toLocation.split(',').skip(1).join(',').trim(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Text(
                  ride.pricePerSeat == 0
                      ? 'Free'
                      : 'from\nRs. ${ride.pricePerSeat.toStringAsFixed(0)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ride.pricePerSeat == 0
                        ? Colors.green
                        : AppColors.primary,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),
            Divider(height: 1),
            SizedBox(height: 12),

            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[300],
                  child: Icon(Icons.person, size: 20, color: Colors.grey[600]),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 12, color: Colors.amber),
                          SizedBox(width: 2),
                          Text(
                            ride.driverRating?.toStringAsFixed(1) ?? "N/A",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Rating',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ✅ FIXED: Show available seats with color coding
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: seatColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: seatColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_seat, size: 16, color: seatColor),
                      SizedBox(width: 4),
                      Text(
                        '${ride.availableSeats} ${ride.availableSeats > 1 ? 'seats' : 'seat'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: seatColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Get relevance text based on score
  String _getRelevanceText(double score) {
    if (score >= 90) return '⭐⭐⭐ Best Match';
    if (score >= 75) return '⭐⭐ Good Match';
    if (score >= 60) return '⭐ Fair Match';
    return 'Available';
  }

  /// ✅ Get relevance color based on score
  Color _getRelevanceColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return AppColors.primary;
    if (score >= 60) return Colors.orange;
    return Colors.grey;
  }

  String _calculateArrivalTime(String departureTime) {
    try {
      final parts = departureTime.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      minute += 40;
      hour += 2;

      if (minute >= 60) {
        hour += minute ~/ 60;
        minute = minute % 60;
      }

      if (hour >= 24) {
        hour = hour % 24;
      }

      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '00:00';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No rides found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching different locations or dates',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}