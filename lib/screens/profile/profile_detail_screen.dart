import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../models/user.dart';

class ProfileDetailScreen extends StatefulWidget {
  final User user;

  const ProfileDetailScreen({super.key, required this.user});

  @override
  _ProfileDetailScreenState createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late User currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    currentUser = widget.user;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              currentUser.name,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '100% complete',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: TextStyle(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Edit profile'),
            Tab(text: 'View profile'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildEditProfileTab(), _buildViewProfileTab()],
      ),
    );
  }

  Widget _buildEditProfileTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Profile Header
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                // Profile Picture
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: NetworkImage(
                            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?ixlib=rb-1.2.1&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Yash, 22',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'INTERMEDIATE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Traveller, adventure seeker',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 16),
                // Rating
                InkWell(
                  onTap: () {
                    // Navigate to ratings
                  },
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.orange, size: 18),
                      SizedBox(width: 4),
                      Text(
                        '5.0',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '• 0 Ratings',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Preferences Section
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildPreferenceItem(
                  Icons.chat_bubble_outline,
                  'I\'m chatty when I feel comfortable',
                ),
                _buildPreferenceItem(
                  Icons.music_note,
                  'Like listening to music while travelling',
                ),
                _buildPreferenceItem(Icons.pets, 'Pets are allowed'),
                _buildPreferenceItem(
                  Icons.smoke_free,
                  'Smoking is not allowed',
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Verifications Section
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildVerificationItem(
                  Icons.verified_user,
                  'Govt ID verified',
                  true,
                ),
                _buildVerificationItem(
                  Icons.card_membership,
                  'Drivers License verified',
                  true,
                ),
                _buildVerificationItem(Icons.email, 'Email ID verified', true),
                _buildVerificationItem(
                  Icons.phone,
                  'Phone number verified',
                  true,
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildViewProfileTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Profile Header (same as edit)
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                // Profile Picture
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: NetworkImage(
                            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?ixlib=rb-1.2.1&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Yash, 22',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'INTERMEDIATE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Traveller, adventure seeker',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Travel Preferences
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildPreferenceItem(
                  Icons.chat_bubble_outline,
                  'I\'m chatty when I feel comfortable',
                ),
                _buildPreferenceItem(
                  Icons.music_note,
                  'Like listening to music while travelling',
                ),
                _buildPreferenceItem(Icons.pets, 'Pets are allowed'),
                _buildPreferenceItem(
                  Icons.smoke_free,
                  'Smoking is not allowed',
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Verifications
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildVerificationItem(
                  Icons.verified_user,
                  'Govt ID verified',
                  true,
                ),
                _buildVerificationItem(
                  Icons.card_membership,
                  'Drivers License verified',
                  true,
                ),
                _buildVerificationItem(Icons.email, 'Email ID verified', true),
                _buildVerificationItem(
                  Icons.phone,
                  'Phone number verified',
                  true,
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Additional Info
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildInfoItem(Icons.directions_car, '1 rides published'),
                _buildInfoItem(Icons.person, 'Member since March 2021'),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Vehicle Info
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildVehicleItem(Icons.directions_car, 'Nexon (white)'),
                _buildVehicleItem(Icons.directions_car, 'XUV 500 (black)'),
              ],
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPreferenceItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationItem(IconData icon, String text, bool isVerified) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isVerified ? AppColors.success : AppColors.divider,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, color: Colors.white, size: 16),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
