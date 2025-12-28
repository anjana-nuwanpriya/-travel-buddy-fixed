import 'package:flutter/material.dart';

class SearchResultsScreen extends StatelessWidget {
  final String from;
  final String to;
  final DateTime date;

  const SearchResultsScreen({
    super.key,
    required this.from,
    required this.to,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search Results')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text('Search Results Coming Soon!', style: TextStyle(fontSize: 20)),
            SizedBox(height: 8),
            Text('$from → $to'),
          ],
        ),
      ),
    );
  }
}
