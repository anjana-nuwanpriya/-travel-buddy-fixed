import 'package:flutter/material.dart';
import '../utils/colors.dart';

class RecentSearches extends StatelessWidget {
  // Remove const and use computed dates
  final List<RecentSearch> searches = [
    RecentSearch(
      from: 'Colombo',
      to: 'Kandy',
      date: DateTime.now().subtract(Duration(days: 1)),
    ),
    RecentSearch(
      from: 'Galle',
      to: 'Matara',
      date: DateTime.now().subtract(Duration(days: 3)),
    ),
  ];

  RecentSearches({super.key}); // Remove const from constructor

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Searches',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: Clear recent searches
              },
              child: Text(
                'Clear',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ...searches.map((search) => _buildSearchItem(context, search)),
      ],
    );
  }

  Widget _buildSearchItem(BuildContext context, RecentSearch search) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.history, color: AppColors.primary),
        title: Text(
          '${search.from} → ${search.to}',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _formatDate(search.date),
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // TODO: Navigate to search results with these parameters
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Searching ${search.from} to ${search.to}...'),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class RecentSearch {
  final String from;
  final String to;
  final DateTime date;

  RecentSearch({required this.from, required this.to, required this.date});
}
