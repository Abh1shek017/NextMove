import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../screens/trip/trip_confirmation_screen.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Navigate to trip confirmation screen
  void navigateToTripConfirmation(Trip trip) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TripConfirmationScreen(trip: trip),
        ),
      );
    }
  }

  /// Show trip confirmation dialog
  void showTripConfirmationDialog(Trip trip) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Trip Completed!'),
          content: Text(
            'Your trip from ${trip.startLocation} to ${trip.endLocation} has been completed.\n\n'
            'Distance: ${trip.distanceFormatted}\n'
            'Duration: ${trip.durationFormatted}\n\n'
            'Would you like to confirm the trip details?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                navigateToTripConfirmation(trip);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
    }
  }

  /// Navigate back to home
  void navigateToHome() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Navigate to a specific screen
  void navigateTo(Widget screen) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => screen),
      );
    }
  }
}
