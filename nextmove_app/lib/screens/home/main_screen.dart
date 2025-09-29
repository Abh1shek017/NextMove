import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/motion_detection_service.dart';
import '../../widgets/bottom_nav.dart';
import 'home_screen.dart';
import '../trip/trip_history_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // Start with Home tab

  @override
  void initState() {
    super.initState();
    // Initialize auth service and motion detection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthService>(context, listen: false).initialize();
      _initializeMotionDetection();
    });
  }

  Future<void> _initializeMotionDetection() async {
    try {
      final motionService =
          Provider.of<MotionDetectionService>(context, listen: false);
      await motionService.startMonitoring();
      debugPrint('✅ Motion detection initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize motion detection: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Motion detection failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const TripHistoryScreen(),
      const HomeScreen(),
      const ProfileTabScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
