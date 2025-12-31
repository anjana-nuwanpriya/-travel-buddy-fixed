import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'utils/colors.dart';
import 'providers/user_provider.dart';
import 'providers/ride_provider.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/rides/my_rides_screen.dart';
import 'screens/messages/messages_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'config/supabase_config.dart';
import 'services/session_manager.dart';
import 'services/simplified_unified_auth_service.dart';

import 'screens/rides/browse_rides_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/bookings/booking_requests_screen.dart';
import 'screens/ride/publish_ride_wizard_screen.dart';

// ==================== NEW SIMPLIFIED AUTH SCREENS ====================
import 'screens/auth/1_welcome_screen.dart' as welcome_screen;
import 'screens/auth/2_signin_screen.dart' as signin_screen;
import 'screens/auth/2a_signin_phone_screen.dart';
import 'screens/auth/2b_signin_email_screen.dart';
import 'screens/auth/3_signup_screen.dart' as signup_screen;
import 'screens/auth/3a_signup_phone_screen.dart';
import 'screens/auth/3a_email_signup_screen.dart';
import 'screens/auth/3b_signup_basic_info_screen.dart';
import 'screens/auth/4_email_verification_screen.dart';

// ==================== ENTRY POINT ====================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Only initialize Supabase here - check session later
  try {
    await SupabaseConfig.initialize(
      url: 'https://qgeefajkplektjzroxex.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFnZWVmYWprcGxla3RqenJveGV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk0ODU4NDYsImV4cCI6MjA3NTA2MTg0Nn0.MZPfdHQQqPArJRYygNbiSAgyDkiWe8-f7oTqCgolZuU',
    );
    debugPrint('✅ Supabase initialized');
  } catch (e) {
    debugPrint('❌ Failed to initialize Supabase: $e');
  }

  // ✅ Run app immediately - don't wait for session check
  runApp(const TravelBuddyApp());
}

// ==================== MAIN APP ====================

class TravelBuddyApp extends StatelessWidget {
  const TravelBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
      ],
      child: MaterialApp(
        title: 'Travel Buddy',
        theme: ThemeData(
          primaryColor: AppColors.primary,
          textTheme: GoogleFonts.interTextTheme().apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          ),
          fontFamily: GoogleFonts.inter().fontFamily,
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            titleTextStyle: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: GoogleFonts.inter().fontFamily,
            ),
          ),
        ),
        // ✅ Use SplashScreen as home - it handles session check
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
        routes: {
          // ==================== ORIGINAL ROUTES ====================
          '/onboarding': (context) => const OnboardingScreen(),
          '/home': (context) => const MainScreen(),
          '/post-ride': (context) => PublishRideWizardScreen(),
          '/browse-rides': (context) => BrowseRidesScreen(),
          '/edit-profile': (context) => EditProfileScreen(),
          '/my-rides': (context) {
            final args = ModalRoute.of(context)?.settings.arguments
                as Map<String, dynamic>?;
            final tabIndex = args?['initialTabIndex'] as int? ?? 0;
            return MyRidesScreen(initialTabIndex: tabIndex);
          },
          '/messages': (context) => MessagesScreen(),
          '/profile': (context) => ProfileScreen(),
          '/notifications': (context) => NotificationsScreen(),
          '/booking-requests': (context) => BookingRequestsScreen(),

          // ==================== NEW SIMPLIFIED AUTH ROUTES ====================
          '/welcome': (context) => const welcome_screen.WelcomeScreen(),
          '/signin': (context) => const signin_screen.SignInScreen(),
          '/signin-phone': (context) => const SignInPhoneScreen(),
          '/signin-email': (context) => const SignInEmailScreen(),
          '/signup': (context) => const signup_screen.SignUpScreen(),
          '/signup-phone': (context) => const SignUpPhoneScreen(),
          '/signup-email': (context) => const EmailSignUpScreen(),
          '/signup-basic-info': (context) {
            final authData = ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>? ??
                {};
            return SignUpBasicInfoScreen(authData: authData);
          },
          '/email-verification': (context) => const EmailVerificationScreen(),
        },
        onGenerateRoute: (settings) {
          // Handle routes that need arguments
          switch (settings.name) {
            default:
              return MaterialPageRoute(
                builder: (context) => const welcome_screen.WelcomeScreen(),
              );
          }
        },
      ),
    );
  }
}

// ==================== SPLASH SCREEN - Fast Loading ====================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // ✅ Check session AFTER first frame renders (non-blocking)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndNavigate();
    });
  }

  Future<void> _initializeAndNavigate() async {
    try {
      // Initialize auth service
      await SimplifiedUnifiedAuthService().initialize();
      debugPrint('✅ Auth Service initialized');

      // Check session
      final sessionManager = SessionManager();
      final hasSession = await sessionManager.hasValidSession();
      debugPrint('📍 Has valid session: $hasSession');

      if (!mounted) return;

      // Navigate based on session
      if (hasSession) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    } catch (e) {
      debugPrint('❌ Error during initialization: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo or icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.directions_car,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Travel Buddy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MAIN SCREEN WITH NAVIGATION ====================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(), // Tab 0: Find a Ride
      PublishRideWizardScreen(), // Tab 1: Post a Ride
      MyRidesScreen(), // Tab 2: My Rides
      MessagesScreen(), // Tab 3: Chat
      ProfileScreen(), // Tab 4: Profile
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.search,
                  activeIcon: Icons.search,
                  index: 0,
                  label: 'Find',
                ),
                _buildNavItem(
                  icon: Icons.add_circle_outline,
                  activeIcon: Icons.add_circle,
                  index: 1,
                  label: 'Post',
                ),
                _buildNavItem(
                  icon: Icons.directions_car_outlined,
                  activeIcon: Icons.directions_car,
                  index: 2,
                  label: 'My Rides',
                ),
                _buildNavItem(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  index: 3,
                  label: 'Chat',
                ),
                _buildNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  index: 4,
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required int index,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : Colors.grey[600],
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}