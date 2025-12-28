import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../services/simplified_unified_auth_service.dart';
import '../../widgets/profile_menu_item.dart';
import '../driver_verification/driver_documents_hub_screen.dart';
import 'edit_profile_screen.dart';
import 'points_screen.dart';
import 'targets_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = SimplifiedUnifiedAuthService();
  
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _authService.currentUser;

      if (user == null) {
        Navigator.pushReplacementNamed(context, '/auth');
        return;
      }

      final profile = await _authService.getUserProfile(user.id);

      if (!mounted) return;

      setState(() {
        _userProfile = profile ??
            {
              'id': user.id,
              'email': user.email,
              'phone': user.phone,
              'full_name':
                  user.userMetadata?['full_name'] ?? user.email?.split('@')[0],
              'display_name':
                  user.userMetadata?['name'] ?? user.email?.split('@')[0],
              'avatar_url': user.userMetadata?['avatar_url'],
            };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditProfileScreen()),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      _loadUserProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final fullName = _userProfile?['full_name'] ?? 'User';
    final email = _userProfile?['email'] ?? '';
    final avatarUrl = _userProfile?['avatar_url'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: AppColors.textPrimary),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(
                            fullName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        fullName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: AppColors.textPrimary),
                    ],
                  ),
                ],
              ),
            ),

            // Points + Targets
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: _buildFeatureCard(
                      title: 'Points',
                      subtitle: 'Track Earnings',
                      icon: Icons.stars_rounded,
                      gradient: LinearGradient(
                        colors: [Colors.amber[700]!, Colors.amber[500]!],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PointsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _buildTargetsCard(
                      title: 'Targets',
                      subtitle: 'Weekly Goals',
                      icon: Icons.emoji_events_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TargetsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 8),

            // ACCOUNT section
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _sectionHeader("Account"),
                  ProfileMenuItem(
                    icon: Icons.person_outline,
                    title: 'Personal Information',
                    onTap: () => _navigateToEditProfile(),
                  ),
                  ProfileMenuItem(
                    icon: Icons.verified_user,
                    title: 'Driver Account Documents',
                    subtitle: 'Verify your driver account',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DriverDocumentsHubScreen(),
                      ),
                    ),
                  ),
                  ProfileMenuItem(
                    icon: Icons.directions_car_outlined,
                    title: 'My Vehicles',
                    onTap: () => Navigator.pushNamed(context, '/vehicles'),
                  ),
                  ProfileMenuItem(
                    icon: Icons.payment_outlined,
                    title: 'Payment Methods',
                    onTap: () =>
                        Navigator.pushNamed(context, '/payment-methods'),
                  ),
                  ProfileMenuItem(
                    icon: Icons.star_outline,
                    title: 'Reviews & Ratings',
                    onTap: () => Navigator.pushNamed(context, '/reviews'),
                  ),
                ],
              ),
            ),

            SizedBox(height: 8),

            // APP SETTINGS
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _sectionHeader("App Settings"),
                  ProfileMenuItem(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    onTap: () =>
                        Navigator.pushNamed(context, '/notification-settings'),
                  ),
                  ProfileMenuItem(
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () => _showLanguageSelector(),
                  ),
                  ProfileMenuItem(
                    icon: Icons.accessibility_outlined,
                    title: 'Accessibility',
                    onTap: () => Navigator.pushNamed(context, '/accessibility'),
                  ),
                ],
              ),
            ),

            SizedBox(height: 8),

            // SUPPORT
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _sectionHeader("Support"),
                  ProfileMenuItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () => Navigator.pushNamed(context, '/help'),
                  ),
                  ProfileMenuItem(
                    icon: Icons.description_outlined,
                    title: 'Terms & Conditions',
                    onTap: () => Navigator.pushNamed(context, '/terms'),
                  ),
                  ProfileMenuItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () => Navigator.pushNamed(context, '/privacy'),
                  ),
                  ProfileMenuItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    textColor: AppColors.error,
                    onTap: () => _showLogoutDialog(),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            Text(
              'Travel Buddy v1.0.0',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),

            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.35),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(
                  subtitle,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetsCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: Colors.orange,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(
                  subtitle,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Language',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            ListTile(
              title: Text('English'),
              trailing: Icon(Icons.check, color: AppColors.primary),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: Text('Hindi'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: Text('Tamil'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/auth', (route) => false);
            },
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }
}