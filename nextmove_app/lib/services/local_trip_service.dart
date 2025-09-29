import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_model.dart';

class LocalTripService {
  static const String _tripsKey = 'local_trips';
  static const String _pendingTripsKey = 'pending_trips';

  /// Save a trip locally
  static Future<void> saveTrip(Trip trip) async {
    final prefs = await SharedPreferences.getInstance();
    final existingTrips = await getLocalTrips();

    // Add the new trip
    existingTrips.add(trip);

    // Save back to storage
    final tripsJson = existingTrips.map((trip) => trip.toJson()).toList();
    await prefs.setString(_tripsKey, jsonEncode(tripsJson));
  }

  /// Save a pending trip (needs confirmation)
  static Future<void> savePendingTrip(Trip trip) async {
    final prefs = await SharedPreferences.getInstance();
    final existingPendingTrips = await getPendingTrips();

    // Add the new pending trip
    existingPendingTrips.add(trip);

    // Save back to storage
    final tripsJson =
        existingPendingTrips.map((trip) => trip.toJson()).toList();
    await prefs.setString(_pendingTripsKey, jsonEncode(tripsJson));
  }

  /// Get all local trips
  static Future<List<Trip>> getLocalTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final tripsJson = prefs.getString(_tripsKey);

    if (tripsJson == null) return [];

    try {
      final List<dynamic> tripsList = jsonDecode(tripsJson);
      return tripsList.map((tripData) => Trip.fromJson(tripData)).toList();
    } catch (e) {
      debugPrint('Error parsing local trips: $e');
      return [];
    }
  }

  /// Get all pending trips (unconfirmed)
  static Future<List<Trip>> getPendingTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final tripsJson = prefs.getString(_pendingTripsKey);

    if (tripsJson == null) return [];

    try {
      final List<dynamic> tripsList = jsonDecode(tripsJson);
      return tripsList.map((tripData) => Trip.fromJson(tripData)).toList();
    } catch (e) {
      debugPrint('Error parsing pending trips: $e');
      return [];
    }
  }

  /// Move trip from pending to confirmed (local)
  static Future<void> confirmTrip(int tripId, String confirmedMode,
      {String? purpose, String? comment, int? companions, double? cost}) async {
    final pendingTrips = await getPendingTrips();
    final confirmedTrips = await getLocalTrips();

    // Find and move the trip
    final tripIndex = pendingTrips.indexWhere((trip) => trip.tripId == tripId);
    if (tripIndex != -1) {
      final trip = pendingTrips[tripIndex];
      final confirmedTrip = trip.copyWith(
        confirmedMode: confirmedMode,
        purpose: purpose ?? trip.purpose,
        comment: comment ?? trip.comment,
        companions: companions ?? trip.companions,
        cost: cost ?? trip.cost,
      );

      // Remove from pending and add to confirmed
      pendingTrips.removeAt(tripIndex);
      confirmedTrips.add(confirmedTrip);

      // Save both lists
      await _savePendingTrips(pendingTrips);
      await _saveConfirmedTrips(confirmedTrips);

      debugPrint('✅ Trip confirmed locally: $tripId');
    }
  }

  /// Get today's trips (both local and from backend)
  static Future<List<Trip>> getTodaysTrips() async {
    final localTrips = await getLocalTrips();
    final today = DateTime.now();

    // Filter local trips for today
    final todayLocalTrips = localTrips.where((trip) {
      if (trip.startTime == null) return false;
      return DateTime(trip.startTime!.year, trip.startTime!.month,
              trip.startTime!.day) ==
          DateTime(today.year, today.month, today.day);
    }).toList();

    return todayLocalTrips;
  }

  /// Get all unconfirmed trips (pending)
  static Future<List<Trip>> getUnconfirmedTrips() async {
    return await getPendingTrips();
  }

  /// Clear all local data (for testing)
  static Future<void> clearAllLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tripsKey);
    await prefs.remove(_pendingTripsKey);
  }

  /// Helper method to save confirmed trips
  static Future<void> _saveConfirmedTrips(List<Trip> trips) async {
    final prefs = await SharedPreferences.getInstance();
    final tripsJson = trips.map((trip) => trip.toJson()).toList();
    await prefs.setString(_tripsKey, jsonEncode(tripsJson));
  }

  /// Helper method to save pending trips
  static Future<void> _savePendingTrips(List<Trip> trips) async {
    final prefs = await SharedPreferences.getInstance();
    final tripsJson = trips.map((trip) => trip.toJson()).toList();
    await prefs.setString(_pendingTripsKey, jsonEncode(tripsJson));
  }
}
