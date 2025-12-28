import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/colors.dart';
import '../screens/maps/location_picker_screen.dart';

enum SearchType { findRide, offerRide }

class SearchCard extends StatefulWidget {
  final SearchType type;

  const SearchCard({super.key, required this.type});

  @override
  _SearchCardState createState() => _SearchCardState();
}

class _SearchCardState extends State<SearchCard> {
  String fromLocation = '';
  String toLocation = '';
  LatLng? fromLatLng;
  LatLng? toLatLng;
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Location inputs
          Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(width: 2, height: 40, color: AppColors.divider),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    // From location
                    InkWell(
                      onTap: () => _selectLocation(true),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          fromLocation.isEmpty ? 'From' : fromLocation,
                          style: TextStyle(
                            fontSize: 16,
                            color: fromLocation.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Divider(),
                    // To location
                    InkWell(
                      onTap: () => _selectLocation(false),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          toLocation.isEmpty ? 'To' : toLocation,
                          style: TextStyle(
                            fontSize: 16,
                            color: toLocation.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _swapLocations,
                icon: Icon(Icons.swap_vert, color: AppColors.textSecondary),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Date and time selection
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _selectTime,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          selectedTime.format(context),
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (widget.type == SearchType.offerRide) ...[
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Passengers: 3',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'LKR',
                          style: TextStyle(
                            fontSize: 13, // same size as your icon
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '450',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          SizedBox(height: 24),

          // Search button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _canSearch() ? _handleSearch : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: AppColors.divider,
              ),
              child: Text(
                widget.type == SearchType.findRide ? 'Search' : 'Publish Ride',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectLocation(bool isFromLocation) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          title: isFromLocation
              ? 'Select Pickup Location'
              : 'Select Drop Location',
          initialLocation: isFromLocation ? fromLatLng : toLatLng,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isFromLocation) {
          fromLocation = result['address'];
          fromLatLng = result['location'];
        } else {
          toLocation = result['address'];
          toLatLng = result['location'];
        }
      });
    }
  }

  void _swapLocations() {
    setState(() {
      final tempLocation = fromLocation;
      final tempLatLng = fromLatLng;
      fromLocation = toLocation;
      fromLatLng = toLatLng;
      toLocation = tempLocation;
      toLatLng = tempLatLng;
    });
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  void _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null && picked != selectedTime) {
      setState(() => selectedTime = picked);
    }
  }

  bool _canSearch() {
    return fromLocation.isNotEmpty && toLocation.isNotEmpty;
  }

  void _handleSearch() {
    if (widget.type == SearchType.findRide) {
      Navigator.pushNamed(
        context,
        '/search-results',
        arguments: {
          'from': fromLocation,
          'to': toLocation,
          'fromLatLng': fromLatLng,
          'toLatLng': toLatLng,
          'date': selectedDate,
          'time': selectedTime,
        },
      );
    } else {
      // Handle publish ride
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Publishing ride...'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}
