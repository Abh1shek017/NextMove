import 'dart:async';
// import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/trip_model.dart';
import '../utils/constants.dart';

class LocationService extends ChangeNotifier {
  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  final List<GpsLog> _gpsBuffer = [];
  Timer? _batchTimer;
  bool _isTracking = false;
  String? _lastError;
  double _totalDistance = 0.0;
  DateTime? _lastLocationTime;
  Position? _lastPosition;

  // Getters
  bool get isTracking => _isTracking;
  Position? get currentPosition => _currentPosition;
  String? get lastError => _lastError;
  double get totalDistance => _totalDistance;
  List<GpsLog> get currentBuffer => List.unmodifiable(_gpsBuffer);

  // Events
  final StreamController<List<GpsLog>> _gpsBufferController =
      StreamController.broadcast();
  final StreamController<Position> _positionController =
      StreamController.broadcast();

  Stream<List<GpsLog>> get gpsBufferStream => _gpsBufferController.stream;
  Stream<Position> get positionStream => _positionController.stream;

  // Check and request permissions
  Future<bool> checkPermissions() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _lastError = 'Location permissions are permanently denied';
        notifyListeners();
        return false;
      }

      if (permission == LocationPermission.denied) {
        _lastError = 'Location permissions denied';
        notifyListeners();
        return false;
      }

      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _lastError = 'Location services are disabled';
        notifyListeners();
        return false;
      }

      _lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Permission check failed: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Start location tracking
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    if (!await checkPermissions()) {
      return false;
    }

    try {
      _resetTracking();

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onLocationUpdate,
        onError: _onLocationError,
        cancelOnError: false,
      );

      // Start batch timer
      _batchTimer = Timer.periodic(
        const Duration(seconds: AppConstants.gpsIntervalSeconds),
        (_) => _processBatch(),
      );

      _isTracking = true;
      _lastError = null;
      notifyListeners();

      debugPrint('Location tracking started');
      return true;
    } catch (e) {
      _lastError = 'Failed to start tracking: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Stop location tracking
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    await _positionStream?.cancel();
    _positionStream = null;

    _batchTimer?.cancel();
    _batchTimer = null;

    // Process any remaining logs in buffer
    if (_gpsBuffer.isNotEmpty) {
      _processBatch();
    }

    _isTracking = false;
    notifyListeners();

    debugPrint('Location tracking stopped');
  }

  // Handle location updates
  void _onLocationUpdate(Position position) {
    _currentPosition = position;

    // Calculate speed if available, otherwise derive from movement
    double speed = position.speed;
    if (speed < 0 || speed.isNaN) {
      speed = _calculateSpeed(position);
    }

    // Update distance tracking
    _updateDistance(position);

    // Add to buffer
    final gpsLog = GpsLog(
      latitude: position.latitude,
      longitude: position.longitude,
      speed: speed,
      timestamp: DateTime.now(),
    );

    _gpsBuffer.add(gpsLog);
    _positionController.add(position);

    _lastError = null;
    notifyListeners();

    debugPrint('GPS: ${position.latitude.toStringAsFixed(6)}, '
        '${position.longitude.toStringAsFixed(6)}, '
        'Speed: ${speed.toStringAsFixed(1)} m/s');
  }

  // Handle location errors
  void _onLocationError(dynamic error) {
    _lastError = 'Location error: ${error.toString()}';
    notifyListeners();
    debugPrint('Location error: $error');
  }

  // Calculate speed from position changes
  double _calculateSpeed(Position position) {
    if (_lastPosition == null || _lastLocationTime == null) {
      _lastPosition = position;
      _lastLocationTime = DateTime.now();
      return 0.0;
    }

    final now = DateTime.now();
    final timeDiff = now.difference(_lastLocationTime!).inMilliseconds / 1000.0;

    if (timeDiff < 1.0) return 0.0; // Too short to calculate

    final distance = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    _lastPosition = position;
    _lastLocationTime = now;

    return distance / timeDiff; // m/s
  }

  // Update total distance
  void _updateDistance(Position position) {
    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      _totalDistance += distance;
    }
  }

  // Process GPS batch
  void _processBatch() {
    if (_gpsBuffer.isEmpty) return;

    final batch = List<GpsLog>.from(_gpsBuffer);
    _gpsBuffer.clear();

    _gpsBufferController.add(batch);

    debugPrint('GPS batch processed: ${batch.length} points');
  }

  // Reset tracking state
  void _resetTracking() {
    _gpsBuffer.clear();
    _totalDistance = 0.0;
    _lastPosition = null;
    _lastLocationTime = null;
    _currentPosition = null;
  }

  // Get current location once
  Future<Position?> getCurrentLocation() async {
    if (!await checkPermissions()) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _currentPosition = position;
      _lastError = null;
      notifyListeners();

      return position;
    } catch (e) {
      _lastError = 'Failed to get location: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  // Calculate distance between two points
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Format coordinates for display
  static String formatCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  @override
  void dispose() {
    stopTracking();
    _gpsBufferController.close();
    _positionController.close();
    super.dispose();
  }
}
