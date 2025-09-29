import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../../models/trip_model.dart';
import '../../services/auth_service.dart';
import 'trip_details_screen.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Car',
    'Bus',
    'Walk',
    'Bike',
    'Other'
  ];

  List<Trip> _allTrips = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPastTrips();
  }

  Future<void> _loadPastTrips() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tripsData = await AuthService.getPastTrips();
      setState(() {
        _allTrips = tripsData.map((data) => Trip.fromJson(data)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load trips: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  bool _isTripEditable(Trip trip) {
    if (trip.endTime == null) return false;
    final now = DateTime.now();
    final timeDifference = now.difference(trip.endTime!);
    return timeDifference.inHours < 24; // Editable if within 24 hours
  }

  List<Trip> get _filteredTrips {
    if (_selectedFilter == 'All') return _allTrips;
    return _allTrips.where((trip) {
      final mode = trip.confirmedMode ?? trip.predictedMode;
      return mode?.toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();
  }

  Map<String, List<Trip>> get _groupedTrips {
    final Map<String, List<Trip>> grouped = {};
    final now = DateTime.now();

    for (final trip in _filteredTrips) {
      final tripDate = trip.startTime!;
      String dateKey;

      if (DateUtils.isSameDay(tripDate, now)) {
        dateKey = 'Today';
      } else if (DateUtils.isSameDay(
          tripDate, now.subtract(const Duration(days: 1)))) {
        dateKey = 'Yesterday';
      } else if (tripDate.isAfter(now.subtract(const Duration(days: 7)))) {
        dateKey = DateFormat('EEEE').format(tripDate);
      } else {
        dateKey = DateFormat('MMM d').format(tripDate);
      }

      grouped.putIfAbsent(dateKey, () => []).add(trip);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // ✅ Professional Black AppBar
      appBar: AppBar(
        title: const Text("Past Trips",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadPastTrips,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterDialog,
          ),
        ],
      ),

      body: Column(
        children: [
          // ✅ Professional Filter Bar
          if (_selectedFilter != 'All')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedFilter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _selectedFilter = 'All'),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "${_filteredTrips.length} trips",
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          // ✅ Modernized Trip List
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : _filteredTrips.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(
                                AppConstants.defaultPadding),
                            itemCount: _groupedTrips.length,
                            itemBuilder: (context, index) {
                              final dateKey =
                                  _groupedTrips.keys.elementAt(index);
                              final trips = _groupedTrips[dateKey]!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ✅ Professional Section Header
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Text(
                                      dateKey,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  ...trips.map(_buildTripCard),
                                  const SizedBox(height: 16),
                                ],
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      color: Colors.white,
      child: InkWell(
        onTap: () => _navigateToTripDetails(trip),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Mode icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                ),
                child: Icon(
                  _getModeIcon(trip.confirmedMode ?? trip.predictedMode),
                  color: Colors.black87,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Trip details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${trip.startLocation} → ${trip.endLocation}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 14, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat("h:mm a").format(trip.startTime!),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.straighten,
                            size: 14, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          trip.distanceFormatted,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                    if (trip.purpose != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.flag,
                              size: 14, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            trip.purpose!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Right side details
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_isTripEditable(trip))
                    IconButton(
                      icon: const Icon(Icons.edit,
                          size: 20, color: Colors.black87),
                      onPressed: () => _showEditTripDialog(trip),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                    ),
                  if (trip.cost != null)
                    Text(
                      "₹${trip.cost!.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                  if (trip.companions != null && trip.companions! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.group,
                              size: 14, color: Colors.black54),
                          const SizedBox(width: 2),
                          Text(
                            "+${trip.companions}",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Professional States
  Widget _buildLoadingState() => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
  Widget _buildErrorState() => Center(
        child: Text(
          _errorMessage ?? "Error",
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      );
  Widget _buildEmptyState() => const Center(
        child: Text(
          "No trips found",
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );

  // Helpers
  void _navigateToTripDetails(Trip trip) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
  }

  IconData _getModeIcon(String? mode) {
    switch (mode?.toLowerCase()) {
      case "car":
        return Icons.directions_car;
      case "bus":
        return Icons.directions_bus;
      case "walk":
        return Icons.directions_walk;
      case "bike":
        return Icons.directions_bike;
      case "auto/taxi":
        return Icons.local_taxi;
      case "train":
        return Icons.train;
      default:
        return Icons.help_outline;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          "Filter Trips",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _filterOptions.map((filter) {
            return RadioListTile<String>(
              title: Text(
                filter,
                style: const TextStyle(color: Colors.black87),
              ),
              value: filter,
              groupValue: _selectedFilter,
              activeColor: Colors.black,
              onChanged: (value) {
                setState(() => _selectedFilter = value!);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditTripDialog(Trip trip) {
    final purposeController = TextEditingController(text: trip.purpose ?? '');
    final startLocationController =
        TextEditingController(text: trip.startLocation ?? '');
    final endLocationController =
        TextEditingController(text: trip.endLocation ?? '');
    final costController =
        TextEditingController(text: trip.cost?.toString() ?? '');
    final companionsController =
        TextEditingController(text: trip.companions?.toString() ?? '0');
    final commentController = TextEditingController(text: trip.comment ?? '');

    String selectedMode = trip.confirmedMode ?? trip.predictedMode ?? 'Car';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Edit Trip',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Purpose
                TextField(
                  controller: purposeController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: 'Purpose',
                    labelStyle: TextStyle(color: Colors.black87),
                    hintText: 'e.g., Work, Shopping, Recreation',
                    hintStyle: TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Transportation Mode
                DropdownButtonFormField<String>(
                  value: selectedMode,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: 'Transportation Mode',
                    labelStyle: TextStyle(color: Colors.black87),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Car',
                        child:
                            Text('Car', style: TextStyle(color: Colors.black))),
                    DropdownMenuItem(
                        value: 'Bus',
                        child:
                            Text('Bus', style: TextStyle(color: Colors.black))),
                    DropdownMenuItem(
                        value: 'Walk',
                        child: Text('Walk',
                            style: TextStyle(color: Colors.black))),
                    DropdownMenuItem(
                        value: 'Bike',
                        child: Text('Bike',
                            style: TextStyle(color: Colors.black))),
                    DropdownMenuItem(
                        value: 'Auto/Taxi',
                        child: Text('Auto/Taxi',
                            style: TextStyle(color: Colors.black))),
                    DropdownMenuItem(
                        value: 'Train',
                        child: Text('Train',
                            style: TextStyle(color: Colors.black))),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedMode = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Start Location
                TextField(
                  controller: startLocationController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: 'Start Location',
                    labelStyle: TextStyle(color: Colors.black87),
                    hintText: 'e.g., Home, Office',
                    hintStyle: TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // End Location
                TextField(
                  controller: endLocationController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: 'End Location',
                    labelStyle: TextStyle(color: Colors.black87),
                    hintText: 'e.g., Mall, Hospital',
                    hintStyle: TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Cost
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: 'Cost (₹)',
                    labelStyle: TextStyle(color: Colors.black87),
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Companions
                TextField(
                  controller: companionsController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: 'Companions',
                    labelStyle: TextStyle(color: Colors.black87),
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Comment
                TextField(
                  controller: commentController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: 'Comment (Optional)',
                    labelStyle: TextStyle(color: Colors.black87),
                    hintText: 'Additional notes...',
                    hintStyle: TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black87),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 2,
              ),
              onPressed: () async {
                try {
                  await AuthService.editTrip(
                    tripId: trip.tripId!,
                    purpose: purposeController.text.trim().isEmpty
                        ? null
                        : purposeController.text.trim(),
                    confirmedMode: selectedMode,
                    startLocation: startLocationController.text.trim().isEmpty
                        ? null
                        : startLocationController.text.trim(),
                    endLocation: endLocationController.text.trim().isEmpty
                        ? null
                        : endLocationController.text.trim(),
                    cost: costController.text.trim().isEmpty
                        ? null
                        : double.tryParse(costController.text.trim()),
                    companions:
                        int.tryParse(companionsController.text.trim()) ?? 0,
                    comment: commentController.text.trim().isEmpty
                        ? null
                        : commentController.text.trim(),
                  );

                  Navigator.of(context).pop();

                  // Refresh the trips list
                  await _loadPastTrips();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Trip updated successfully!',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.black,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to update trip: ${e.toString()}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.black87,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
