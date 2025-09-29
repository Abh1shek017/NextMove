import 'package:flutter/material.dart';
import 'package:nextmove_app/screens/home/main_screen.dart';
import 'package:nextmove_app/screens/trip/trip_confirmation_screen.dart';
import 'package:nextmove_app/screens/trip/trip_details_screen.dart';
import 'package:nextmove_app/models/trip_model.dart';

class AppRoutes {
  static const String main = '/';
  static const String tripConfirmation = '/trip-confirmation';
  static const String tripDetails = '/trip-details';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case main:
        return MaterialPageRoute(builder: (_) => const MainScreen());

      case tripConfirmation:
        final trip = settings.arguments as Trip;
        return MaterialPageRoute(
          builder: (_) => TripConfirmationScreen(trip: trip),
        );

      case tripDetails:
        final trip = settings.arguments as Trip;
        return MaterialPageRoute(
          builder: (_) => TripDetailsScreen(trip: trip),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
