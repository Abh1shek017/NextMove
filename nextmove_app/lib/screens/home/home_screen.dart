// lib/screens/home_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../models/trip_model.dart';
import '../trip/trip_confirmation_screen.dart';
import '../../services/motion_detection_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_trip_service.dart';
import '../../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Trip> todayTrips = [];
  List<Trip> pendingConfirmations = [];
  String userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTodayTrips();
    _loadPendingConfirmations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to motion service changes to refresh data
    final motionService =
        Provider.of<MotionDetectionService>(context, listen: false);
    motionService.addListener(_onMotionServiceChanged);
  }

  @override
  void dispose() {
    final motionService =
        Provider.of<MotionDetectionService>(context, listen: false);
    motionService.removeListener(_onMotionServiceChanged);
    super.dispose();
  }

  void _onMotionServiceChanged() {
    // Refresh data when motion service changes (e.g., trip confirmed)
    _loadTodayTrips();
    _loadPendingConfirmations();
  }

  /// Pull-to-refresh callback
  Future<void> _refreshData() async {
    // Show loading indicators while refreshing
    await Future.wait([
      _loadTodayTrips(),
      _loadPendingConfirmations(),
    ]);
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString(AppConstants.keyFullName) ?? 'User';
    });
  }

  Future<void> _loadTodayTrips() async {
    try {
      final List<Trip> allTodayTrips = [];

      // Load trips from backend (confirmed trips)
      try {
        final tripsData = await AuthService.getPastTrips(limit: 50);
        final today = DateTime.now();

        // Filter backend trips for today
        final todayBackendTrips = tripsData
            .where((tripData) {
              if (tripData['start_time'] == null) return false;
              final tripDate = DateTime.parse(tripData['start_time']);
              return DateUtils.isSameDay(tripDate, today);
            })
            .map((data) => Trip.fromJson(data))
            .toList();

        allTodayTrips.addAll(todayBackendTrips);
      } catch (e) {
        debugPrint('Failed to load backend trips: $e');
      }

      // Load trips from local storage (confirmed local trips)
      try {
        final localTodayTrips = await LocalTripService.getTodaysTrips();
        allTodayTrips.addAll(localTodayTrips);
      } catch (e) {
        debugPrint('Failed to load local trips: $e');
      }

      // Sort by start time (newest first)
      allTodayTrips.sort((a, b) {
        if (a.startTime == null && b.startTime == null) return 0;
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        return b.startTime!.compareTo(a.startTime!);
      });

      setState(() {
        todayTrips = allTodayTrips;
      });
    } catch (e) {
      debugPrint('Failed to load today\'s trips: $e');
      setState(() {
        todayTrips = [];
      });
    }
  }

  Future<void> _loadPendingConfirmations() async {
    try {
      final List<Trip> allPendingTrips = [];

      // Load pending trips from backend
      try {
        final tripsData = await AuthService.getPastTrips(limit: 50);

        // Filter trips that have predicted mode but no confirmed mode
        final pendingBackendTrips = tripsData
            .where((tripData) {
              return tripData['predicted_mode'] != null &&
                  tripData['confirmed_mode'] == null &&
                  tripData['end_time'] != null;
            })
            .map((data) => Trip.fromJson(data))
            .toList();

        allPendingTrips.addAll(pendingBackendTrips);
      } catch (e) {
        debugPrint('Failed to load pending backend trips: $e');
      }

      // Load pending trips from local storage
      try {
        final localPendingTrips = await LocalTripService.getUnconfirmedTrips();
        allPendingTrips.addAll(localPendingTrips);
      } catch (e) {
        debugPrint('Failed to load local pending trips: $e');
      }

      // Sort by start time (newest first)
      allPendingTrips.sort((a, b) {
        if (a.startTime == null && b.startTime == null) return 0;
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        return b.startTime!.compareTo(a.startTime!);
      });

      setState(() {
        pendingConfirmations = allPendingTrips;
      });
    } catch (e) {
      debugPrint('Failed to load pending confirmations: $e');
      setState(() {
        pendingConfirmations = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MotionDetectionService>(
      builder: (context, motionService, child) {
        return Scaffold(
            appBar: AppBar(
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryBlue, AppTheme.successGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.directions_car_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(width: 8),
                  Text("NextMove",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
              centerTitle: false,
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              actions: [
                // Motion detection status indicator
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: motionService.isMonitoring
                        ? (motionService.isTripActive
                            ? AppTheme.successGreen
                            : AppTheme.primaryBlue)
                        : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        motionService.isTripActive
                            ? Icons.directions_car
                            : motionService.isMonitoring
                                ? Icons.location_searching
                                : Icons.location_disabled,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        motionService.isTripActive
                            ? 'Trip Active'
                            : motionService.isMonitoring
                                ? 'Monitoring'
                                : 'Offline',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    // TODO: Show notifications
                  },
                ),
              ],
            ),
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.blue[50]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: RefreshIndicator(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      _buildHeaderSection(),
                      const SizedBox(height: 24),

                      // Current Trip Status (if active)
                      if (motionService.isTripActive &&
                          motionService.currentTrip != null)
                        _buildCurrentTripCard(motionService.currentTrip!),
                      if (motionService.isTripActive &&
                          motionService.currentTrip != null)
                        const SizedBox(height: 20),

                      // Today's Activity Card
                      _buildTodayActivityCard(),
                      const SizedBox(height: 20),

                      // Unconfirmed Trips Section
                      _buildUnconfirmedTripsSection(),
                      const SizedBox(height: 20),

                      // Quick Actions Section
                      _buildQuickActionsSection(),
                    ],
                  ),
                ),
              ),
            ));
      },
    );
  }

  Widget _buildHeaderSection() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Hi, $userName 👋",
          style: AppTheme.headingLarge.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 4),
        Text(
          formattedDate,
          style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildTodayActivityCard() {
    final totalTrips = todayTrips.length;
    final totalDistance =
        todayTrips.fold<double>(0, (sum, trip) => sum + (trip.distance ?? 0));
    final totalTime =
        todayTrips.fold<int>(0, (sum, trip) => sum + (trip.duration ?? 0));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.today,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Today's Activity",
                  style: AppTheme.headingMedium,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (totalTrips == 0)
              _buildEmptyState()
            else
              _buildActivityMetrics(totalTrips, totalDistance, totalTime),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Column(
        children: [
          Icon(
            Icons.directions_walk,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            "No trips recorded yet today",
            style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          const Text(
            "Start moving to see your activity here!",
            style: AppTheme.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityMetrics(
      int totalTrips, double totalDistance, int totalTime) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricItem(
            'Total Trips',
            totalTrips.toString(),
            Icons.directions,
            AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricItem(
            'Distance',
            '${totalDistance.toStringAsFixed(1)} km',
            Icons.straighten,
            AppTheme.successGreen,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricItem(
            'Travel Time',
            '${(totalTime / 60).toStringAsFixed(1)}h',
            Icons.access_time,
            AppTheme.warningOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.headingMedium.copyWith(color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUnconfirmedTripsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.pending_actions,
                color: AppTheme.warningOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Unconfirmed Trips",
              style: AppTheme.headingMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (pendingConfirmations.isEmpty)
          _buildNoPendingTripsState()
        else
          ...pendingConfirmations.map((trip) => _buildTripCard(trip)),
      ],
    );
  }

  Widget _buildNoPendingTripsState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: AppTheme.successGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppTheme.successGreen,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're all caught up!",
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "No trips need confirmation right now.",
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.successGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: InkWell(
        onTap: () => _navigateToTripConfirmation(trip),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map snippet
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    // Map placeholder
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map,
                            size: 32,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${trip.startLocation} → ${trip.endLocation}',
                            style: AppTheme.caption,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Route info overlay
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          '${(trip.distance ?? 0).toStringAsFixed(1)} km',
                          style: AppTheme.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Trip details
              Row(
                children: [
                  Icon(
                    _getModeIcon(trip.predictedMode ?? 'Unknown'),
                    color: _getModeColor(trip.predictedMode ?? 'Unknown'),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Detected: ${trip.predictedMode ?? 'Unknown'}',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    trip.startTime != null
                        ? DateFormat('h:mm a').format(trip.startTime!)
                        : 'Unknown',
                    style: AppTheme.caption,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToTripConfirmation(trip),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToTripConfirmation(Trip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripConfirmationScreen(trip: trip),
      ),
    ).then((_) {
      // Refresh data when returning from confirmation
      _loadPendingConfirmations();
      _loadTodayTrips();
    });
  }

  Color _getModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'car':
        return AppTheme.warningOrange;
      case 'bus':
        return AppTheme.primaryBlue;
      case 'walk':
        return AppTheme.successGreen;
      case 'bike':
        return Colors.purple;
      case 'auto/taxi':
        return Colors.yellow[700]!;
      case 'train':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getModeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'bus':
        return Icons.directions_bus;
      case 'walk':
        return Icons.directions_walk;
      case 'bike':
        return Icons.directions_bike;
      case 'auto/taxi':
        return Icons.local_taxi;
      case 'train':
        return Icons.train;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildCurrentTripCard(Trip trip) {
    final duration = trip.startTime != null
        ? DateTime.now().difference(trip.startTime!)
        : Duration.zero;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue.withValues(alpha: 0.1),
              AppTheme.primaryBlue.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trip in Progress',
                        style: AppTheme.headingMedium.copyWith(
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Started ${_formatDuration(duration)} ago',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_searching,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (trip.startLocation != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.radio_button_checked,
                    size: 16,
                    color: AppTheme.successGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.startLocation!,
                      style: AppTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Icon(
                  Icons.radio_button_unchecked,
                  size: 16,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tracking destination...',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(duration),
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (trip.gpsLogs != null && trip.gpsLogs!.isNotEmpty) ...[
                  Icon(
                    Icons.straighten,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_calculateDistance(trip.gpsLogs!).toStringAsFixed(1)} km',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  double _calculateDistance(List<GpsLog> gpsLogs) {
    if (gpsLogs.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 1; i < gpsLogs.length; i++) {
      // Simple distance calculation (not accurate for long distances)
      double latDiff = gpsLogs[i].latitude - gpsLogs[i - 1].latitude;
      double lonDiff = gpsLogs[i].longitude - gpsLogs[i - 1].longitude;
      double distance = sqrt(latDiff * latDiff + lonDiff * lonDiff) *
          111; // rough km conversion
      totalDistance += distance;
    }
    return totalDistance;
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.flash_on,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Quick Actions",
              style: AppTheme.headingMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Create a test trip
                  final motionService = Provider.of<MotionDetectionService>(
                      context,
                      listen: false);
                  await motionService.createTestTrip();

                  // Refresh the data to show the new trip
                  _loadPendingConfirmations();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Test trip created! Check unconfirmed trips section.'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                },
                icon: const Icon(Icons.add_location),
                label: const Text('Create Test Trip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Clear all local trip data
                  await LocalTripService.clearAllLocalData();
                  _loadTodayTrips();
                  _loadPendingConfirmations();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Local trip data cleared!'),
                      backgroundColor: AppTheme.warningOrange,
                    ),
                  );
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Data'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
