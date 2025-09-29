import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../../models/trip_model.dart';

class TripDetailsScreen extends StatelessWidget {
  final Trip trip;

  const TripDetailsScreen({
    super.key,
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Details'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Share functionality - Coming soon!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Map section
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.grey[200],
              child: Stack(
                children: [
                  // Map placeholder
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Trip Route Map',
                          style: AppTheme.headingMedium
                              .copyWith(color: Colors.grey[600]),
                        ),
                        Text(
                          '${trip.startLocation} → ${trip.endLocation}',
                          style: AppTheme.bodyMedium
                              .copyWith(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),

                  // Mode badge
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getModeColor(trip.confirmedMode),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getModeIcon(trip.confirmedMode),
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            trip.confirmedMode ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Trip information
            Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                children: [
                  // Basic info card
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(AppConstants.defaultPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trip Information',
                            style: AppTheme.headingMedium,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            'Route',
                            '${trip.startLocation} → ${trip.endLocation}',
                            Icons.route,
                          ),
                          _buildInfoRow(
                            'Date',
                            DateFormat('EEEE, MMM d, yyyy')
                                .format(trip.startTime!),
                            Icons.calendar_today,
                          ),
                          _buildInfoRow(
                            'Time',
                            '${DateFormat('h:mm a').format(trip.startTime!)} - ${DateFormat('h:mm a').format(trip.endTime!)}',
                            Icons.access_time,
                          ),
                          _buildInfoRow(
                            'Duration',
                            trip.durationFormatted,
                            Icons.timer,
                          ),
                          _buildInfoRow(
                            'Distance',
                            trip.distanceFormatted,
                            Icons.straighten,
                          ),
                          if (trip.purpose != null)
                            _buildInfoRow(
                              'Purpose',
                              trip.purpose!,
                              Icons.flag,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Additional details card
                  if (trip.companions != null || trip.cost != null)
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(AppConstants.defaultPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Additional Details',
                              style: AppTheme.headingMedium,
                            ),
                            const SizedBox(height: 16),
                            if (trip.companions != null)
                              _buildInfoRow(
                                'Companions',
                                trip.companions == 0
                                    ? 'Traveled alone'
                                    : '${trip.companions} companion${trip.companions! > 1 ? 's' : ''}',
                                Icons.group,
                              ),
                            if (trip.cost != null)
                              _buildInfoRow(
                                'Cost',
                                '₹${trip.cost!.toStringAsFixed(2)}',
                                Icons.currency_rupee,
                              ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Statistics card
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(AppConstants.defaultPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trip Statistics',
                            style: AppTheme.headingMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  'Average Speed',
                                  _calculateAverageSpeed(),
                                  Icons.speed,
                                  AppTheme.primaryBlue,
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  'CO₂ Saved',
                                  _calculateCO2Saved(),
                                  Icons.eco,
                                  AppTheme.successGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Actions card
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(AppConstants.defaultPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Actions',
                            style: AppTheme.headingMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    // TODO: Implement edit functionality
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Edit trip - Coming soon!')),
                                    );
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit Trip'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _showDeleteConfirmation(context);
                                  },
                                  icon: const Icon(Icons.delete,
                                      color: AppTheme.errorRed),
                                  label: const Text(
                                    'Delete',
                                    style: TextStyle(color: AppTheme.errorRed),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: AppTheme.errorRed),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTheme.headingMedium.copyWith(color: color),
        ),
        Text(
          label,
          style: AppTheme.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _calculateAverageSpeed() {
    if (trip.distance == null || trip.duration == null || trip.duration == 0) {
      return 'N/A';
    }

    final speedKmh = (trip.distance! / 1000) / (trip.duration! / 3600);
    return '${speedKmh.toStringAsFixed(1)} km/h';
  }

  String _calculateCO2Saved() {
    if (trip.distance == null) return 'N/A';

    // Rough CO2 calculation based on mode vs car
    double co2PerKm = 0;
    switch (trip.confirmedMode?.toLowerCase()) {
      case 'walk':
      case 'bike':
        co2PerKm = 0.21; // CO2 saved by not using car
        break;
      case 'bus':
        co2PerKm = 0.08; // CO2 saved vs car
        break;
      case 'train':
        co2PerKm = 0.15; // CO2 saved vs car
        break;
      default:
        co2PerKm = 0;
    }

    final co2Saved = (trip.distance! / 1000) * co2PerKm;
    return co2Saved > 0 ? '${co2Saved.toStringAsFixed(2)} kg' : 'N/A';
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text(
          'Are you sure you want to delete this trip? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to trips list
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trip deleted successfully'),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getModeColor(String? mode) {
    switch (mode?.toLowerCase()) {
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

  IconData _getModeIcon(String? mode) {
    switch (mode?.toLowerCase()) {
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
