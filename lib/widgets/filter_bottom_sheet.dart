import 'package:flutter/material.dart';
import '../utils/colors.dart';

class FilterBottomSheet extends StatefulWidget {
  final Map<String, dynamic> activeFilters;
  final Function(Map<String, dynamic>) onFiltersApplied;

  const FilterBottomSheet({
    super.key,
    required this.activeFilters,
    required this.onFiltersApplied,
  });

  @override
  _FilterBottomSheetState createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late Map<String, dynamic> filters;
  RangeValues priceRange = RangeValues(0, 1000);

  @override
  void initState() {
    super.initState();
    filters = Map.from(widget.activeFilters);
    priceRange = filters['priceRange'] ?? RangeValues(0, 1000);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Spacer(),
                TextButton(
                  onPressed: () =>
                      setState(() => priceRange = RangeValues(0, 1000)),
                  child: Text('Clear All'),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price range
                  Text(
                    'Price Range',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 16),

                  RangeSlider(
                    values: priceRange,
                    min: 0,
                    max: 2000,
                    divisions: 40,
                    activeColor: AppColors.primary,
                    labels: RangeLabels(
                      'LKR${priceRange.start.round()}',
                      'LKR${priceRange.end.round()}',
                    ),
                    onChanged: (values) => setState(() => priceRange = values),
                  ),
                ],
              ),
            ),
          ),

          // Apply button
          Container(
            padding: EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  widget.onFiltersApplied({'priceRange': priceRange});
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Apply Filters',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
