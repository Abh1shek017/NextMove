import 'dart:math';
import 'package:flutter/material.dart';

import 'local_trip_service.dart';
import 'navigation_service.dart';
import 'auth_service.dart';
import '../utils/constants.dart';
import '../models/trip_model.dart';

class CreateTripService {
  static Future<void> createTestTrip(
      BuildContext context, String tripType) async {
    Trip testTrip;
    String successMessage;
    List<GpsLog> logs = [];

    switch (tripType) {
      case 'commute':
        logs = _generateNagpurCommuteLogs();
        testTrip = Trip(
          tripId: DateTime.now().millisecondsSinceEpoch,
          startTime: logs.first.timestamp,
          endTime: logs.last.timestamp,
          startLatitude: logs.first.latitude,
          startLongitude: logs.first.longitude,
          endLatitude: logs.last.latitude,
          endLongitude: logs.last.longitude,
          startLocation: 'Sitabuldi, Nagpur',
          endLocation: 'MIHAN, Nagpur',
          distance: _calculateTotalDistance(logs),
          duration:
              logs.last.timestamp.difference(logs.first.timestamp).inSeconds,
          predictedMode: 'Bike',
          purpose: 'Work',
          companions: 1,
          cost: 0.0,
          gpsLogs: logs,
        );
        successMessage = 'Work commute sample trip (Nagpur) created!';
        break;

      case 'leisure':
        logs = _generateNagpurLeisureLogs();
        testTrip = Trip(
          tripId: DateTime.now().millisecondsSinceEpoch,
          startTime: logs.first.timestamp,
          endTime: logs.last.timestamp,
          startLatitude: logs.first.latitude,
          startLongitude: logs.first.longitude,
          endLatitude: logs.last.latitude,
          endLongitude: logs.last.longitude,
          startLocation: 'Futala Lake, Nagpur',
          endLocation: 'Ambazari Lake, Nagpur',
          distance: _calculateTotalDistance(logs),
          duration:
              logs.last.timestamp.difference(logs.first.timestamp).inSeconds,
          predictedMode: 'Walk',
          purpose: 'Leisure',
          companions: 2,
          cost: 0.0,
          gpsLogs: logs,
        );
        successMessage = 'Leisure trip around lakes (Nagpur) created!';
        break;

      case 'shopping':
        logs = _generateNagpurShoppingLogs();
        testTrip = Trip(
          tripId: DateTime.now().millisecondsSinceEpoch,
          startTime: logs.first.timestamp,
          endTime: logs.last.timestamp,
          startLatitude: logs.first.latitude,
          startLongitude: logs.first.longitude,
          endLatitude: logs.last.latitude,
          endLongitude: logs.last.longitude,
          startLocation: 'Sitabuldi Market, Nagpur',
          endLocation: 'Empress Mall, Nagpur',
          distance: _calculateTotalDistance(logs),
          duration:
              logs.last.timestamp.difference(logs.first.timestamp).inSeconds,
          predictedMode: 'Auto/Taxi',
          purpose: 'Shopping',
          companions: 1,
          cost: 30.0,
          gpsLogs: logs,
        );
        successMessage = 'Shopping trip sample (Nagpur) created!';
        break;

      case 'exercise':
        logs = _generateNagpurExerciseLogs();
        testTrip = Trip(
          tripId: DateTime.now().millisecondsSinceEpoch,
          startTime: logs.first.timestamp,
          endTime: logs.last.timestamp,
          startLatitude: logs.first.latitude,
          startLongitude: logs.first.longitude,
          endLatitude: logs.last.latitude,
          endLongitude: logs.last.longitude,
          startLocation: 'Civil Lines, Nagpur',
          endLocation: 'Gorewada Lake, Nagpur',
          distance: _calculateTotalDistance(logs),
          duration:
              logs.last.timestamp.difference(logs.first.timestamp).inSeconds,
          predictedMode: 'Bike',
          purpose: 'Exercise',
          companions: 1,
          cost: 0.0,
          gpsLogs: logs,
        );
        successMessage = 'Exercise ride sample (Nagpur) created!';
        break;

      default:
        return;
    }

    try {
      await LocalTripService.savePendingTrip(testTrip);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppTheme.successGreen,
          ),
        );

        Future.delayed(const Duration(seconds: 1), () {
          if (context.mounted) {
            NavigationService().showTripConfirmationDialog(testTrip);
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating sample trip: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  /// Store confirmed trip to database
  static Future<void> storeConfirmedTripToDatabase({
    required int tripId,
    required String confirmedMode,
    String? purpose,
    String? comment,
    int? companions,
    double? cost,
  }) async {
    try {
      // Store to backend database via AuthService
      await AuthService.confirmTrip(
        tripId: tripId,
        confirmedMode: confirmedMode,
        purpose: purpose,
        comment: comment,
      );

      debugPrint('✅ Trip $tripId confirmed and stored to database');
    } catch (e) {
      debugPrint('❌ Failed to store trip to database: $e');
      rethrow;
    }
  }

  /// Handle trip confirmation with database storage
  static Future<void> handleTripConfirmation({
    required BuildContext context,
    required Trip trip,
    required String confirmedMode,
    String? purpose,
    String? comment,
    int? companions,
    double? cost,
  }) async {
    try {
      // Check if this is a local trip (has a large tripId from timestamp)
      final isLocalTrip = trip.tripId != null && trip.tripId! > 1000000000000;

      if (isLocalTrip) {
        // Handle local trip confirmation
        await LocalTripService.confirmTrip(
          trip.tripId!,
          confirmedMode,
          purpose: purpose,
          comment: comment,
          companions: companions,
          cost: cost,
        );

        // Also store to database for test trips
        await storeConfirmedTripToDatabase(
          tripId: trip.tripId!,
          confirmedMode: confirmedMode,
          purpose: purpose,
          comment: comment,
          companions: companions,
          cost: cost,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip confirmed and saved to database!'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } else {
        // Handle backend trip confirmation
        await AuthService.confirmTrip(
          tripId: trip.tripId!,
          confirmedMode: confirmedMode,
          purpose: purpose,
          comment: comment,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip confirmed!'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm trip: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  /// ✅ Calculate total distance using Haversine formula
  static double _calculateTotalDistance(List<GpsLog> logs) {
    double totalDistance = 0.0;
    for (int i = 0; i < logs.length - 1; i++) {
      totalDistance += _haversineDistance(
        logs[i].latitude,
        logs[i].longitude,
        logs[i + 1].latitude,
        logs[i + 1].longitude,
      );
    }
    return totalDistance;
  }

  /// Haversine formula: returns distance in km
  static double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth radius in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180);

  /// 🔹 Generate realistic Nagpur commute logs
  static List<GpsLog> _generateNagpurCommuteLogs() {
    final logs = <GpsLog>[];
    final startTime = DateTime.now().subtract(const Duration(minutes: 33));

    // More realistic coordinate progression for ~15km commute
    for (int i = 0; i < 12; i++) {
      final timestamp = startTime.add(Duration(minutes: i * 3));
      final lat =
          21.1458 + (i * 0.01); // Increased increment for realistic distance
      final lng =
          79.0882 + (i * 0.008); // Increased increment for realistic distance
      final speed = 20.0 + (i * 1.0);

      logs.add(GpsLog(
        latitude: lat,
        longitude: lng,
        speed: speed,
        timestamp: timestamp,
      ));
    }
    return logs;
  }

  /// 🔹 Leisure trip logs (Nagpur lakeside)
  static List<GpsLog> _generateNagpurLeisureLogs() {
    final logs = <GpsLog>[];
    final startTime = DateTime.now().subtract(const Duration(minutes: 42));

    // More realistic coordinate progression for ~3km walk
    for (int i = 0; i < 15; i++) {
      final timestamp = startTime.add(Duration(minutes: i * 3));
      final lat =
          21.1442 + (i * 0.002); // Increased increment for realistic distance
      final lng =
          79.0885 + (i * 0.0015); // Increased increment for realistic distance
      final speed = 6.0 + (i % 3);

      logs.add(GpsLog(
        latitude: lat,
        longitude: lng,
        speed: speed,
        timestamp: timestamp,
      ));
    }
    return logs;
  }

  /// 🔹 Shopping trip logs (Nagpur)
  static List<GpsLog> _generateNagpurShoppingLogs() {
    final logs = <GpsLog>[];
    final startTime = DateTime.now().subtract(const Duration(minutes: 18));

    // More realistic coordinate progression for ~8km shopping trip
    for (int i = 0; i < 7; i++) {
      final timestamp = startTime.add(Duration(minutes: i * 3));
      final lat =
          21.1471 + (i * 0.008); // Increased increment for realistic distance
      final lng =
          79.0849 + (i * 0.006); // Increased increment for realistic distance
      final speed = 12.0;

      logs.add(GpsLog(
        latitude: lat,
        longitude: lng,
        speed: speed,
        timestamp: timestamp,
      ));
    }
    return logs;
  }

  /// 🔹 Exercise ride logs (Nagpur outskirts)
  static List<GpsLog> _generateNagpurExerciseLogs() {
    final logs = <GpsLog>[];
    final startTime = DateTime.now().subtract(const Duration(minutes: 57));

    // More realistic coordinate progression for ~25km exercise ride
    for (int i = 0; i < 20; i++) {
      final timestamp = startTime.add(Duration(minutes: i * 3));
      final lat =
          21.1265 + (i * 0.012); // Increased increment for realistic distance
      final lng =
          79.0809 + (i * 0.01); // Increased increment for realistic distance
      final speed = 15.0 + (i * 0.3);

      logs.add(GpsLog(
        latitude: lat,
        longitude: lng,
        speed: speed,
        timestamp: timestamp,
      ));
    }
    return logs;
  }
}
