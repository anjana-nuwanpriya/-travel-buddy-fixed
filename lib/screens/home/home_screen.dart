import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';
import '../notifications/notifications_screen.dart';
import '../ride/widgets/location_selection_step.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NotificationService _notificationService = NotificationService();

  // Location data
  String? _pickupLocation;
  String? _destinationLocation;
  double? _pickupLat;
  double? _pickupLng;
  double? _destLat;
  double? _destLng;
  
  DateTime _selectedDate = DateTime.now();
  int _passengerCount = 1;

  /// Remove Plus Code from address (e.g., "W9MQ+776, City, Country" -> "City, Country")
  String _cleanAddress(String address) {
    // Split by comma and check if first part contains Plus Code pattern
    List<String> parts = address.split(', ');
    
    // Check if first part looks like a Plus Code (contains + or all caps with numbers)
    if (parts.isNotEmpty && (parts[0].contains('+') || RegExp(r'^[A-Z0-9]+\+[0-9]+$').hasMatch(parts[0]))) {
      // Remove the first part (Plus Code) and rejoin
      return parts.sublist(1).join(', ');
    }
    
    return address;
  }

  /// Navigate to location selection screen for pickup
  Future<void> _selectPickupLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: LocationSelectionStep(
            title: 'Where are you leaving from?',
            maxRecentItems: 10, // ✅ Dynamic limit, will show based on screen space
            onLocationSelected: (location, lat, lng) {
              Navigator.pop(context, {
                'location': location,
                'lat': lat,
                'lng': lng,
              });
            },
          ),
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _pickupLocation = _cleanAddress(result['location'] as String? ?? '');
        _pickupLat = result['lat'] as double?;
        _pickupLng = result['lng'] as double?;
      });

      print('✅ Pickup location selected:');
      print('   Location: $_pickupLocation');
      print('   Coordinates: $_pickupLat, $_pickupLng');
    }
  }

  /// Navigate to location selection screen for destination
  Future<void> _selectDestinationLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: LocationSelectionStep(
            title: 'Where are you heading?',
            maxRecentItems: 10, // ✅ Dynamic limit, will show based on screen space
            onLocationSelected: (location, lat, lng) {
              Navigator.pop(context, {
                'location': location,
                'lat': lat,
                'lng': lng,
              });
            },
          ),
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _destinationLocation = _cleanAddress(result['location'] as String? ?? '');
        _destLat = result['lat'] as double?;
        _destLng = result['lng'] as double?;
      });

      print('✅ Destination location selected:');
      print('   Location: $_destinationLocation');
      print('   Coordinates: $_destLat, $_destLng');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ==========================
          // 🔥 GRADIENT HEADER (Top 50%)
          // ==========================
          Positioned(
            top: 70, // leaves 90px WHITE TOP SPACE
            left: 0,
            right: 0,
            child: Container(
              height: screenHeight * 0.47,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 231, 62, 0),
                    Color(0xFFFF6B35),
                    Color.fromARGB(255, 255, 228, 51),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // ==========================
          // MAIN CONTENT
          // ==========================
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 90), // WHITE TOP AREA

                // -----------------------------------
                // HEADER TITLE + BELL ICON
                // -----------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Find A Ride',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NotificationsScreen(),
                            ),
                          );
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                            FutureBuilder<int>(
                              future: _notificationService.getUnreadCount(),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                if (count == 0) return const SizedBox.shrink();

                                return Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      count > 9 ? '9+' : '$count',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ======================
                // WHITE SEARCH CARD
                // ======================
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // ✅ PICKUP BUTTON (navigates to location screen)
                            _buildLocationButton(
                              label: _pickupLocation ?? "PickUp",
                              onTap: _selectPickupLocation,
                              isSelected: _pickupLocation != null,
                            ),

                            const SizedBox(height: 16),

                            // ✅ DESTINATION BUTTON (navigates to location screen)
                            _buildLocationButton(
                              label: _destinationLocation ?? "Going to",
                              onTap: _selectDestinationLocation,
                              isSelected: _destinationLocation != null,
                            ),

                            const SizedBox(height: 26),

                            _buildDateSelector(),
                            const SizedBox(height: 8),
                            _buildPassengerSelector(),
                          ],
                        ),
                      ),

                      // SEARCH BUTTON
                      GestureDetector(
                        onTap: _searchRides,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF4500),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Search',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 70),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // ✅ LOCATION BUTTON
  // =======================================================================
  Widget _buildLocationButton({
    required String label,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Color(0xFFFF4500) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Color(0xFFFF4500) : Colors.black87,
                  width: 2,
                ),
              ),
              child: Center(
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: isSelected ? Color(0xFFFF4500) : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: isSelected ? Colors.black87 : Colors.grey.shade500,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================================
  // ✅ DATE SELECTOR - Opens full screen with professional calendar
  // =======================================================================
  Widget _buildDateSelector() {
    return InkWell(
      onTap: _selectDate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Date of departure",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat("EEEE, d MMMM").format(_selectedDate),
                style: const TextStyle(fontSize: 15),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.grey.shade300),
        ],
      ),
    );
  }

  // =======================================================================
  // ✅ PASSENGER SELECTOR - Opens full screen
  // =======================================================================
  Widget _buildPassengerSelector() {
    return InkWell(
      onTap: _showPassengerPicker,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Passengers",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$_passengerCount ${_passengerCount == 1 ? 'passenger' : 'passengers'}",
                style: const TextStyle(fontSize: 15),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.grey.shade300),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _InlineDateSelectionScreen(
          initialDate: _selectedDate,
        ),
      ),
    );

    if (result != null && result is DateTime) {
      setState(() => _selectedDate = result);
    }
  }

  void _showPassengerPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PassengerSelectionScreen(
          initialCount: _passengerCount,
        ),
      ),
    );

    if (result != null && result is int) {
      setState(() => _passengerCount = result);
    }
  }

  void _searchRides() {
    if (_pickupLocation == null || _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select both pickup and destination"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      "/browse-rides",
      arguments: {
        "from": _pickupLocation!,
        "to": _destinationLocation!,
        "fromLat": _pickupLat,
        "fromLng": _pickupLng,
        "toLat": _destLat,
        "toLng": _destLng,
        "date": _selectedDate,
        "passengers": _passengerCount,
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// =======================================================================
// ✅ INLINE CALENDAR - Exactly like Post a Ride page
// =======================================================================
class _InlineDateSelectionScreen extends StatefulWidget {
  final DateTime initialDate;

  const _InlineDateSelectionScreen({required this.initialDate});

  @override
  State<_InlineDateSelectionScreen> createState() =>
      _InlineDateSelectionScreenState();
}

class _InlineDateSelectionScreenState
    extends State<_InlineDateSelectionScreen> {
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
  }

  List<Widget> _buildCalendarForMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startingDayOfWeek = firstDay.weekday; // 1=Monday, 7=Sunday

    List<Widget> days = [];

    // Empty cells for days before the month starts
    for (int i = 0; i < startingDayOfWeek - 1; i++) {
      days.add(const SizedBox(height: 50, child: Center(child: Text(''))));
    }

    // Days of the month
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isSelected = day == selectedDate.day &&
          month.month == selectedDate.month &&
          month.year == selectedDate.year;
      final isPast = date.isBefore(DateTime.now().subtract(Duration(days: 1))) &&
          !isSelected;

      days.add(
        GestureDetector(
          onTap: !isPast
              ? () {
                  setState(() => selectedDate = date);
                  Future.delayed(Duration(milliseconds: 300), () {
                    if (mounted) {
                      Navigator.pop(context, selectedDate);
                    }
                  });
                }
              : null,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFF4500) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : isPast
                          ? Colors.grey[300]
                          : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return days;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Date',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // December
              Text(
                DateFormat('MMMM').format(selectedDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF4500),
                ),
              ),
              const SizedBox(height: 16),

              // Days header
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map((day) => Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500],
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),

              // Calendar grid
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: _buildCalendarForMonth(selectedDate),
              ),
              const SizedBox(height: 40),

              // Next month (January)
              Text(
                DateFormat('MMMM').format(
                    DateTime(selectedDate.year, selectedDate.month + 1)),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF4500),
                ),
              ),
              const SizedBox(height: 16),

              // Days header
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map((day) => Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500],
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),

              // Calendar grid for next month
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: _buildCalendarForMonth(
                    DateTime(selectedDate.year, selectedDate.month + 1)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================================
// ✅ FULL SCREEN PASSENGER SELECTION
// =======================================================================
class _PassengerSelectionScreen extends StatefulWidget {
  final int initialCount;

  const _PassengerSelectionScreen({required this.initialCount});

  @override
  State<_PassengerSelectionScreen> createState() =>
      _PassengerSelectionScreenState();
}

class _PassengerSelectionScreenState extends State<_PassengerSelectionScreen> {
  late int passengerCount;

  @override
  void initState() {
    super.initState();
    passengerCount = widget.initialCount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Number of Passengers',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 60),
          const Text(
            'How many passengers?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: passengerCount > 1
                    ? () => setState(() => passengerCount--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: const Color(0xFFFF4500),
                iconSize: 48,
                disabledColor: Colors.grey.shade300,
              ),
              const SizedBox(width: 40),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFF4500), width: 3),
                ),
                child: Center(
                  child: Text(
                    "$passengerCount",
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF4500),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 40),
              IconButton(
                onPressed: passengerCount < 8
                    ? () => setState(() => passengerCount++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: const Color(0xFFFF4500),
                iconSize: 48,
                disabledColor: Colors.grey.shade300,
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, passengerCount);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4500),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Confirm - $passengerCount ${passengerCount == 1 ? 'passenger' : 'passengers'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}