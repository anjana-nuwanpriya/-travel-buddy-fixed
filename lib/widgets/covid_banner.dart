import 'package:flutter/material.dart';
import '../utils/colors.dart';

class CovidBanner extends StatelessWidget {
  const CovidBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety, color: AppColors.success, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book Now & Save Up to 50%!',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '🌍 www.travelbuddy.com',
                  style: TextStyle(color: AppColors.success, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: AppColors.success, size: 16),
        ],
      ),
    );
  }
}
