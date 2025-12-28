import 'package:flutter/material.dart';
import '../config/supabase_config.dart';

class TestConnectionScreen extends StatefulWidget {
  const TestConnectionScreen({super.key});

  @override
  State<TestConnectionScreen> createState() => _TestConnectionScreenState();
}

class _TestConnectionScreenState extends State<TestConnectionScreen> {
  String _status = 'Testing connection...';

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    try {
      final client = SupabaseConfig.client;

      // Test database connection
      final response = await client
          .from('user_profiles')
          .select('count')
          .limit(1);

      setState(() {
        _status = 'Connection successful!\n\n';
        _status += 'Supabase URL: ${SupabaseConfig.supabaseUrl}\n';
        _status += 'Database query works!\n\n';
        _status += 'Backend is ready to use.';
      });
    } catch (e) {
      setState(() {
        _status = 'Connection failed!\n\n';
        _status += 'Error: $e\n\n';
        _status += 'Check:\n';
        _status += '1. Supabase URL is correct\n';
        _status += '2. Anon key is correct\n';
        _status += '3. Tables are created';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Backend')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_status, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
