import 'package:flutter/material.dart';
import '../../utils/colors.dart';

class DatabaseSetupScreen extends StatelessWidget {
  const DatabaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Setup Required'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: Colors.orange[700],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Points & Targets System Setup',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'The Points and Targets features require database tables to be created. Follow the steps below to complete the setup.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Setup Steps
            _buildStepCard(
              step: '1',
              title: 'Open Supabase Dashboard',
              description: 'Go to your Supabase project dashboard at supabase.com',
              icon: Icons.dashboard,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),

            _buildStepCard(
              step: '2',
              title: 'Navigate to SQL Editor',
              description: 'Click on "SQL Editor" in the left sidebar',
              icon: Icons.code,
              color: Colors.purple,
            ),
            const SizedBox(height: 16),

            _buildStepCard(
              step: '3',
              title: 'Run Database Setup',
              description: 'Copy and run the SQL from database_schema_updates.sql file',
              icon: Icons.play_arrow,
              color: Colors.green,
            ),
            const SizedBox(height: 16),

            _buildStepCard(
              step: '4',
              title: 'Enable Row Level Security',
              description: 'Run the RLS policies from the implementation guide',
              icon: Icons.security,
              color: Colors.orange,
            ),
            const SizedBox(height: 32),

            // Files Needed
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Files You Need',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFileItem('database_schema_updates.sql'),
                  _buildFileItem('IMPLEMENTATION_GUIDE.md'),
                  _buildFileItem('QUICK_START.md'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'I\'ve Completed Setup',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Help Text
            Center(
              child: TextButton(
                onPressed: () {
                  _showHelpDialog(context);
                },
                child: const Text('Need more help?'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String step,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: color),
        ],
      ),
    );
  }

  Widget _buildFileItem(String fileName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            fileName,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setup Help'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Setup Checklist:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('✓ Open Supabase Dashboard'),
              const Text('✓ Go to SQL Editor'),
              const Text('✓ Run database_schema_updates.sql'),
              const Text('✓ Run RLS policies'),
              const Text('✓ Restart your app'),
              const SizedBox(height: 16),
              const Text(
                'Common Issues:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '• Make sure all SQL statements run successfully\n'
                '• Check for any error messages in SQL Editor\n'
                '• Verify RLS policies are enabled\n'
                '• Restart the Flutter app after setup',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}