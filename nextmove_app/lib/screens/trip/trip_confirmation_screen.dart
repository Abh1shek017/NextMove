import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../../models/trip_model.dart';
import '../../services/auth_service.dart';
import '../../services/local_trip_service.dart';

class TripConfirmationScreen extends StatefulWidget {
  final Trip trip;

  const TripConfirmationScreen({
    super.key,
    required this.trip,
  });

  @override
  State<TripConfirmationScreen> createState() => _TripConfirmationScreenState();
}

class _TripConfirmationScreenState extends State<TripConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companionsController = TextEditingController();
  final _costController = TextEditingController();
  final _commentController = TextEditingController();

  String? _selectedMode;
  String? _selectedPurpose;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-select the predicted mode if it exists in the dropdown options
    if (widget.trip.predictedMode != null &&
        AppConstants.transportModes.contains(widget.trip.predictedMode)) {
      _selectedMode = widget.trip.predictedMode;
    }
  }

  @override
  void dispose() {
    _companionsController.dispose();
    _costController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  /// Save the complete confirmed trip to backend
  Future<void> _saveConfirmedTripToBackend() async {
    // Step 1: Start trip in backend
    final startResult = await AuthService.startTrip(
      startLatitude: widget.trip.startLatitude,
      startLongitude: widget.trip.startLongitude,
      startLocation: widget.trip.startLocation,
    );

    // Step 2: Stop trip with basic data
    final tripId = startResult['trip_id'] ?? widget.trip.tripId;
    await AuthService.stopTrip(
      tripId: tripId,
      endLatitude: widget.trip.endLatitude,
      endLongitude: widget.trip.endLongitude,
      endLocation: widget.trip.endLocation,
      purpose: _selectedPurpose,
      companions: int.tryParse(_companionsController.text),
      cost: double.tryParse(_costController.text),
    );

    // Step 3: Confirm trip with user-selected mode
    await AuthService.confirmTrip(
      tripId: tripId,
      confirmedMode: _selectedMode!,
      purpose: _selectedPurpose,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
      companions: int.tryParse(_companionsController.text),
      cost: double.tryParse(_costController.text),
    );
  }

  Future<void> _handleConfirmTrip() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMode == null || _selectedPurpose == null) {
      setState(() {
        _errorMessage = 'Please select both transport mode and trip purpose';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if this is a local trip (has a large tripId from timestamp)
      final isLocalTrip = widget.trip.tripId != null &&
          widget.trip.tripId! > 1000000000000; // Unix timestamp check

      if (isLocalTrip) {
        // Handle local trip confirmation
        await LocalTripService.confirmTrip(
          widget.trip.tripId!,
          _selectedMode!,
          purpose: _selectedPurpose,
          comment: _commentController.text.trim().isEmpty
              ? null
              : _commentController.text.trim(),
          companions: int.tryParse(_companionsController.text),
          cost: double.tryParse(_costController.text),
        );

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip confirmed and saved locally!'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } else {
        // Handle backend trip confirmation
        await _saveConfirmedTripToBackend();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip confirmed and saved to backend!'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      }

      // Navigate back to home
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to confirm trip. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Trip'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Map placeholder
          Container(
            height: 200,
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
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Trip Route Map',
                        style: AppTheme.bodyMedium
                            .copyWith(color: Colors.grey[600]),
                      ),
                      Text(
                        '${widget.trip.startLocation} → ${widget.trip.endLocation}',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),

                // Route info overlay
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.route,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${widget.trip.distanceFormatted} • ${widget.trip.durationFormatted}',
                            style: AppTheme.bodyMedium
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Form content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Auto-detected info section
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(AppConstants.defaultPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Auto-Detected Information',
                              style: AppTheme.headingMedium,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'Trip Time',
                              '${DateFormat('h:mm a').format(widget.trip.startTime!)} - ${DateFormat('h:mm a').format(widget.trip.endTime!)}',
                              Icons.access_time,
                            ),
                            _buildInfoRow(
                              'Distance',
                              widget.trip.distanceFormatted,
                              Icons.straighten,
                            ),
                            _buildInfoRow(
                              'Route',
                              '${widget.trip.startLocation} → ${widget.trip.endLocation}',
                              Icons.route,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // User input section
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(AppConstants.defaultPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Please Confirm Details',
                              style: AppTheme.headingMedium,
                            ),
                            const SizedBox(height: 16),

                            // Transport Mode
                            DropdownButtonFormField<String>(
                              value: _selectedMode,
                              decoration: const InputDecoration(
                                labelText: 'Transport Mode',
                                prefixIcon: Icon(Icons.directions),
                              ),
                              items: AppConstants.transportModes
                                  .map((String mode) {
                                return DropdownMenuItem<String>(
                                  value: mode,
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getModeIcon(mode),
                                        size: 20,
                                        color: _getModeColor(mode),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(mode),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedMode = newValue;
                                  _errorMessage = null;
                                });
                              },
                            ),

                            const SizedBox(height: 16),

                            // Trip Purpose
                            DropdownButtonFormField<String>(
                              value: _selectedPurpose,
                              decoration: const InputDecoration(
                                labelText: 'Trip Purpose',
                                prefixIcon: Icon(Icons.flag),
                              ),
                              items: AppConstants.tripPurposes
                                  .map((String purpose) {
                                return DropdownMenuItem<String>(
                                  value: purpose,
                                  child: Text(purpose),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedPurpose = newValue;
                                  _errorMessage = null;
                                });
                              },
                            ),

                            const SizedBox(height: 16),

                            // Companions
                            TextFormField(
                              controller: _companionsController,
                              decoration: const InputDecoration(
                                labelText: 'Number of Companions',
                                hintText: 'Enter number (optional)',
                                prefixIcon: Icon(Icons.group),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final number = int.tryParse(value);
                                  if (number == null ||
                                      number < 0 ||
                                      number > 20) {
                                    return 'Please enter a valid number (0-20)';
                                  }
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Cost
                            TextFormField(
                              controller: _costController,
                              decoration: const InputDecoration(
                                labelText: 'Trip Cost (₹)',
                                hintText: 'Enter cost (optional)',
                                prefixIcon: Icon(Icons.currency_rupee),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final cost = double.tryParse(value);
                                  if (cost == null ||
                                      cost < 0 ||
                                      cost > 10000) {
                                    return 'Please enter a valid cost (0-10000)';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Error message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppConstants.borderRadius),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppTheme.errorRed, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style:
                                    const TextStyle(color: AppTheme.errorRed),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Confirm button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleConfirmTrip,
                        child: _isLoading
                            ? const SpinKitThreeBounce(
                                color: Colors.white,
                                size: 20,
                              )
                            : const Text('Confirm Trip'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTheme.caption,
          ),
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
      case 'other':
        return Colors.grey[600]!;
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
      case 'other':
        return Icons.help_outline;
      default:
        return Icons.help_outline;
    }
  }
}
