import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/motion_detection_service.dart';
import '../services/local_trip_service.dart';
import '../services/create_trip.dart';
import '../utils/constants.dart';

class QuickActionsWidget extends StatelessWidget {
  final bool showEmptyState;

  const QuickActionsWidget({
    super.key,
    this.showEmptyState = false,
  });

  @override
  Widget build(BuildContext context) {
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
        if (showEmptyState) _buildEmptyState() else _buildQuickActions(context),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Column(
        children: [
          Icon(
            Icons.flash_on,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            "No quick actions available",
            style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          const Text(
            "Quick actions will appear here when available!",
            style: AppTheme.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Show trip type selection dialog
                  _showTripTypeDialog(context);
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

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Local trip data cleared!'),
                        backgroundColor: AppTheme.warningOrange,
                      ),
                    );
                  }
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
        const SizedBox(height: 16),
        // Debug and manual trip buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () =>
                    MotionDetectionService().debugMotionDetection(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningOrange,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text('Debug Motion'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Consumer<MotionDetectionService>(
                builder: (context, motionService, child) => ElevatedButton(
                  onPressed: () async {
                    if (motionService.isTripActive) {
                      await motionService.stopTripManually();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bike trip stopped manually!'),
                            backgroundColor: AppTheme.warningOrange,
                          ),
                        );
                      }
                    } else {
                      await motionService.startTripManually();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bike trip started manually!'),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: motionService.isTripActive
                        ? AppTheme.warningOrange
                        : AppTheme.successGreen,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(motionService.isTripActive
                      ? 'Stop Trip'
                      : 'Start Bike Trip'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showTripTypeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Trip Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.work, color: AppTheme.primaryBlue),
                title: const Text('Work Commute'),
                subtitle: const Text('Sitabuldi → MIHAN (Bike)'),
                onTap: () {
                  Navigator.of(context).pop();
                  CreateTripService.createTestTrip(context, 'commute');
                },
              ),
              ListTile(
                leading: const Icon(Icons.directions_walk,
                    color: AppTheme.successGreen),
                title: const Text('Leisure Walk'),
                subtitle: const Text('Futala → Ambazari Lake'),
                onTap: () {
                  Navigator.of(context).pop();
                  CreateTripService.createTestTrip(context, 'leisure');
                },
              ),
              ListTile(
                leading: const Icon(Icons.shopping_cart,
                    color: AppTheme.warningOrange),
                title: const Text('Shopping Trip'),
                subtitle: const Text('Sitabuldi Market → Empress Mall'),
                onTap: () {
                  Navigator.of(context).pop();
                  CreateTripService.createTestTrip(context, 'shopping');
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.directions_bike, color: Colors.purple),
                title: const Text('Exercise Ride'),
                subtitle: const Text('Civil Lines → Gorewada Lake'),
                onTap: () {
                  Navigator.of(context).pop();
                  CreateTripService.createTestTrip(context, 'exercise');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
