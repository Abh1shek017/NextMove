// lib/screens/trips/trips_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/trip_model.dart';
import '../../services/auth_service.dart';
import '../../services/local_trip_service.dart';
import '../../utils/constants.dart';
import 'trip_details_screen.dart';

class TripsListScreen extends StatefulWidget {
  const TripsListScreen({super.key});

  @override
  State<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends State<TripsListScreen> {
  List<Trip> allTrips = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAllTrips();
  }

  Future<void> _loadAllTrips() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final List<Trip> trips = [];

      // Load trips from backend
      try {
        final tripsData = await AuthService.getPastTrips(limit: 100);
        final backendTrips =
            tripsData.map((data) => Trip.fromJson(data)).toList();
        trips.addAll(backendTrips);
      } catch (e) {
        debugPrint('Failed to load backend trips: $e');
      }

      // Load trips from local storage
      try {
        final localTrips = await LocalTripService.getLocalTrips();
        final pendingTrips = await LocalTripService.getPendingTrips();
        trips.addAll(localTrips);
        trips.addAll(pendingTrips);
      } catch (e) {
        debugPrint('Failed to load local trips: $e');
      }

      // Remove duplicates and sort by start time (newest first)
      final uniqueTrips = <String, Trip>{};
      for (final trip in trips) {
        final key =
            '${trip.startTime?.millisecondsSinceEpoch}_${trip.distance}';
        if (!uniqueTrips.containsKey(key)) {
          uniqueTrips[key] = trip;
        }
      }

      final sortedTrips = uniqueTrips.values.toList()
        ..sort((a, b) {
          if (a.startTime == null && b.startTime == null) return 0;
          if (a.startTime == null) return 1;
          if (b.startTime == null) return -1;
          return b.startTime!.compareTo(a.startTime!);
        });

      setState(() {
        allTrips = sortedTrips;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load trips: $e');
      setState(() {
        errorMessage = 'Failed to load trips. Please try again.';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          "All Trips",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllTrips,
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
          onRefresh: _loadAllTrips,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllTrips,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (allTrips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No trips found',
              style: AppTheme.headingMedium.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Start moving to see your trips here!',
              style: AppTheme.bodyMedium.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trips list
          _buildTripsList(),
        ],
      ),
    );
  }

  Widget _buildTripsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.list,
                color: AppTheme.successGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "All Trips (${allTrips.length})",
              style: AppTheme.headingMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...allTrips.map((trip) => _buildTripCard(trip)),
      ],
    );
  }

  Widget _buildTripCard(Trip trip) {
    final isConfirmed = trip.confirmedMode != null;
    final mode = trip.confirmedMode ?? trip.predictedMode ?? 'Unknown';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: InkWell(
        onTap: () => _navigateToTripDetails(trip),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trip header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getModeColor(mode).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getModeIcon(mode),
                      color: _getModeColor(mode),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mode,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (trip.startTime != null)
                          Text(
                            DateFormat('MMM d, y • h:mm a')
                                .format(trip.startTime!),
                            style: AppTheme.caption,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isConfirmed
                          ? AppTheme.successGreen
                          : AppTheme.warningOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isConfirmed ? 'Confirmed' : 'Pending',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Route info
              if (trip.startLocation != null || trip.endLocation != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${trip.startLocation ?? 'Unknown'} → ${trip.endLocation ?? 'Unknown'}',
                        style: AppTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Trip metrics
              Row(
                children: [
                  if (trip.distance != null) ...[
                    Icon(
                      Icons.straighten,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${trip.distance!.toStringAsFixed(1)} km',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (trip.duration != null) ...[
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(trip.duration! / 60).toStringAsFixed(1)}h',
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
      ),
    );
  }

  void _navigateToTripDetails(Trip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripDetailsScreen(trip: trip),
      ),
    );
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
}
