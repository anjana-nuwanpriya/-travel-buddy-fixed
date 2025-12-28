import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../screens/driver_verification/driver_documents_hub_screen.dart';

class VerificationBlockedScreen extends StatelessWidget {
  final String verificationStatus;

  const VerificationBlockedScreen({
    super.key,
    required this.verificationStatus,
  });

  @override
  Widget build(BuildContext context) {
    // Determine message based on status
    String title;
    String subtitle;
    IconData icon;
    Color iconColor;

    switch (verificationStatus) {
      case 'pending_review':
        title = 'Your documents are under review';
        subtitle = 'This usually takes 1-2 business days. We\'ll notify you once approved';
        icon = Icons.hourglass_empty;
        iconColor = Colors.orange;
        break;

      case 'rejected':
        title = 'Some documents need attention';
        subtitle = 'Please review and resubmit rejected documents to start posting rides';
        icon = Icons.warning_amber_rounded;
        iconColor = AppColors.error;
        break;

      case 'incomplete':
      case 'not_submitted':
      default:
        title = 'Complete your driver verification to start posting rides';
        subtitle = 'Upload all required documents to become a verified driver';
        icon = Icons.verified_user_outlined;
        iconColor = AppColors.primary;
        break;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Post a Ride',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 60,
                  color: iconColor,
                ),
              ),

              SizedBox(height: 32),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              SizedBox(height: 16),

              // Subtitle
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              SizedBox(height: 40),

              // Button to go to Driver Documents
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DriverDocumentsHubScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Go to Driver Documents',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Secondary info text
              if (verificationStatus != 'pending_review')
                Text(
                  'You can find Driver Documents under Profile > Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}