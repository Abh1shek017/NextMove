import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_model.dart';
import 'notification_service.dart';
import 'navigation_service.dart';
import 'local_trip_service.dart';
import 'ml_trip_detection_service.dart';
// import 'background_service.dart';

class MotionDetectionService extends ChangeNotifier {
  static final MotionDetectionService _instance =
      MotionDetectionService._internal();
  factory MotionDetectionService() => _instance;
  MotionDetectionService._internal();

  // Motion detection state
  bool _isMonitoring = false;
  bool _isTripActive = false;
  Trip? _currentTrip;
  Trip? _lastCompletedTrip; // Store last completed trip for confirmation

  // Notification service
  final NotificationService _notificationService = NotificationService();

  // ML trip detection service
  final MLTripDetectionService _mlService = MLTripDetectionService();

  // Motion sensor data
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<Position>? _locationSubscription;

  // Motion detection variables
  // ignore: prefer_final_fields
  List<double> _accelerationBuffer = [];
  // ignore: prefer_final_fields
  List<double> _gyroscopeBuffer = [];
  // ignore: prefer_final_fields
  List<GpsLog> _locationBuffer = [];

  // Thresholds for motion detection
  static const int _bufferSize = 10;

  // Trip detection logic - Updated thresholds
  int _motionCount = 0;
  int _stationaryCount = 0;
  static const int _stationaryRequired = 10; // consecutive stationary readings

  // New trip start criteria - OPTIMIZED FOR WALKING & BIKING
  static const double _speedThreshold =
      2.0; // km/h (walking ~3-5, biking ~15-25 km/h)
  static const double _speedDurationMinutes =
      0.5; // 30 seconds of sustained movement
  static const double _minDistanceMeters = 30.0; // meters (30 meters minimum)

  // Speed tracking variables
  DateTime? _speedStartTime;
  double _totalDistanceDuringSpeed = 0.0;
  List<GpsLog> _speedTrackingLogs = [];

  // Getters
  bool get isMonitoring => _isMonitoring;
  bool get isTripActive => _isTripActive;
  Trip? get currentTrip => _currentTrip;
  Trip? get lastCompletedTrip => _lastCompletedTrip;

  /// Start motion and location monitoring
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    debugPrint('🚀 Starting motion detection monitoring...');

    try {
      // Check permissions
      await _checkPermissions();

      // Initialize notification service
      await _notificationService.initialize();

      _isMonitoring = true;
      notifyListeners();

      // Start accelerometer monitoring (using new API)
      _accelerometerSubscription =
          accelerometerEventStream().listen(_handleAccelerometerData);

      // Start gyroscope monitoring (using new API)
      _gyroscopeSubscription =
          gyroscopeEventStream().listen(_handleGyroscopeData);

      // Start location monitoring
      _startLocationMonitoring();

      // Background service handles motion detection when app is closed
      // Foreground service handles motion detection when app is open
      debugPrint('✅ Foreground motion detection started successfully');
    } catch (e) {
      debugPrint('❌ Failed to start motion detection: $e');
      _isMonitoring = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Stop motion and location monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    debugPrint('🛑 Stopping motion detection monitoring...');

    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    await _locationSubscription?.cancel();

    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _locationSubscription = null;

    _isMonitoring = false;
    _isTripActive = false;
    _currentTrip = null;

    _resetBuffers();

    notifyListeners();

    debugPrint('✅ Motion detection stopped');
  }

  /// Check required permissions
  Future<void> _checkPermissions() async {
    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }
  }

  /// Start location monitoring with high accuracy
  void _startLocationMonitoring() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // meters
        timeLimit: Duration(seconds: 10),
      ),
    ).listen(
      _handleLocationData,
      onError: (error) {
        debugPrint('❌ Location stream error: $error');
      },
    );
  }

  /// Handle accelerometer data for motion detection
  void _handleAccelerometerData(AccelerometerEvent event) {
    // Calculate magnitude of acceleration vector
    double magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    // Remove gravity (approximately 9.81 m/s²)
    double netAcceleration = (magnitude - 9.81).abs();

    _accelerationBuffer.add(netAcceleration);
    if (_accelerationBuffer.length > _bufferSize) {
      _accelerationBuffer.removeAt(0);
    }

    // Send data to ML service
    _mlService.addSensorData(
      accelerationX: event.x,
      accelerationY: event.y,
      accelerationZ: event.z,
      gyroscopeX: 0,
      gyroscopeY: 0,
      gyroscopeZ: 0,
      timestamp: DateTime.now(),
    );

    // Analyze motion pattern (rule-based fallback)
    _analyzeMotionPattern(netAcceleration);
  }

  /// Handle gyroscope data for rotation detection
  void _handleGyroscopeData(GyroscopeEvent event) {
    // Calculate magnitude of rotation vector
    double magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    _gyroscopeBuffer.add(magnitude);
    if (_gyroscopeBuffer.length > _bufferSize) {
      _gyroscopeBuffer.removeAt(0);
    }

    // Send gyroscope data to ML service (will be combined with accelerometer data)
    _mlService.addSensorData(
      accelerationX: 0, // Will be updated by accelerometer handler
      accelerationY: 0,
      accelerationZ: 0,
      gyroscopeX: event.x,
      gyroscopeY: event.y,
      gyroscopeZ: event.z,
      timestamp: DateTime.now(),
    );
  }

  /// Handle location data for trip tracking
  void _handleLocationData(Position position) {
    final gpsLog = GpsLog(
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed,
      timestamp: position.timestamp,
    );

    _locationBuffer.add(gpsLog);

    // Keep only recent locations (last 5 minutes)
    final cutoffTime = DateTime.now().subtract(const Duration(minutes: 5));
    _locationBuffer.removeWhere((log) => log.timestamp.isBefore(cutoffTime));

    // Show current speed in terminal
    _logCurrentSpeed(position);

    // Send speed data to ML service
    _mlService.addSensorData(
      accelerationX: 0,
      accelerationY: 0,
      accelerationZ: 0,
      gyroscopeX: 0,
      gyroscopeY: 0,
      gyroscopeZ: 0,
      speed: position.speed * 3.6, // Convert m/s to km/h
      timestamp: position.timestamp,
    );

    // Update persistent notification if trip is active
    if (_isTripActive && _currentTrip != null) {
      _updateActiveTripNotification();
    }

    // Update current trip if active
    if (_isTripActive && _currentTrip != null) {
      _updateCurrentTrip(gpsLog);
    }

    // Check for trip start conditions using speed and distance
    if (!_isTripActive) {
      _checkTripStartConditions(gpsLog);
    }
  }

  /// Log current speed to terminal for debugging
  void _logCurrentSpeed(Position position) {
    final speedMs = position.speed;
    final speedKmh = speedMs * 3.6;
    final accuracy = position.accuracy;
    final timestamp = DateTime.now();

    debugPrint(
        '📊 SPEED: ${speedKmh.toStringAsFixed(2)} km/h (${speedMs.toStringAsFixed(2)} m/s) | Accuracy: ${accuracy.toStringAsFixed(1)}m | Time: ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}');
  }

  /// Check trip start conditions based on speed and distance
  void _checkTripStartConditions(GpsLog gpsLog) {
    // Convert speed from m/s to km/h
    double speedKmh = (gpsLog.speed ?? 0.0) * 3.6;

    if (speedKmh >= _speedThreshold) {
      // Speed is above threshold
      if (_speedStartTime == null) {
        // Start tracking speed
        _speedStartTime = gpsLog.timestamp;
        _totalDistanceDuringSpeed = 0.0;
        _speedTrackingLogs = [gpsLog];
        debugPrint(
            '🚀 Speed above ${_speedThreshold}km/h detected, starting tracking...');
      } else {
        // Continue tracking speed
        _speedTrackingLogs.add(gpsLog);

        // Calculate distance covered during speed tracking
        if (_speedTrackingLogs.length > 1) {
          double distance = Geolocator.distanceBetween(
            _speedTrackingLogs[_speedTrackingLogs.length - 2].latitude,
            _speedTrackingLogs[_speedTrackingLogs.length - 2].longitude,
            gpsLog.latitude,
            gpsLog.longitude,
          );
          _totalDistanceDuringSpeed += distance;
        }

        // Check if conditions are met
        final duration = gpsLog.timestamp.difference(_speedStartTime!);
        if (duration.inMinutes >= _speedDurationMinutes &&
            _totalDistanceDuringSpeed >= _minDistanceMeters) {
          debugPrint(
              '✅ Trip start conditions met: ${duration.inMinutes}min, ${_totalDistanceDuringSpeed.toStringAsFixed(0)}m');
          _startTrip();
          _resetSpeedTracking();
        }
      }
    } else {
      // Speed dropped below threshold, reset tracking
      if (_speedStartTime != null) {
        debugPrint('⚠️ Speed dropped below threshold, resetting tracking...');
        _resetSpeedTracking();
      }
    }
  }

  /// Reset speed tracking variables
  void _resetSpeedTracking() {
    _speedStartTime = null;
    _totalDistanceDuringSpeed = 0.0;
    _speedTrackingLogs.clear();
  }

  /// Analyze motion pattern to detect trip start/stop (legacy method for trip stop)
  void _analyzeMotionPattern(double acceleration) {
    if (_accelerationBuffer.length < 3) return;

    // Calculate average acceleration over buffer
    double avgAcceleration = _accelerationBuffer.reduce((a, b) => a + b) /
        _accelerationBuffer.length;

    // Debug motion magnitude (only log occasionally to avoid spam)
    if (DateTime.now().millisecond % 1000 < 50) {
      // Log ~5% of the time
      debugPrint(
          '📱 Foreground avg acceleration: ${avgAcceleration.toStringAsFixed(3)}');
    }

    // Detect motion vs stationary - optimized for both walking and biking
    bool isMoving = avgAcceleration > 0.8; // Lowered to 0.8 for bike detection

    if (isMoving) {
      _motionCount++;
      _stationaryCount = 0;
      debugPrint(
          '🚗 Foreground: Significant motion detected (${avgAcceleration.toStringAsFixed(2)})');
    } else {
      _stationaryCount++;
      _motionCount = 0;
    }

    // Trip stop detection (still using motion pattern)
    if (_isTripActive && _stationaryCount >= _stationaryRequired) {
      _stopTrip();
    }
  }

  /// Start a new trip
  void _startTrip() async {
    if (_isTripActive) return;

    debugPrint('🚗 Trip started - motion detected');

    try {
      // Get current location
      Position? currentPosition;
      try {
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint('⚠️ Could not get current position: $e');
      }

      // Create new trip
      _currentTrip = Trip(
        startTime: DateTime.now(),
        startLatitude: currentPosition?.latitude,
        startLongitude: currentPosition?.longitude,
        startLocation: currentPosition != null
            ? '${currentPosition.latitude.toStringAsFixed(4)}, ${currentPosition.longitude.toStringAsFixed(4)}'
            : 'Unknown',
        gpsLogs: [],
      );

      // Add initial GPS log if available
      if (currentPosition != null) {
        _currentTrip!.gpsLogs?.add(GpsLog(
          latitude: currentPosition.latitude,
          longitude: currentPosition.longitude,
          speed: currentPosition.speed,
          timestamp: currentPosition.timestamp,
        ));
      }

      _isTripActive = true;
      notifyListeners();

      // Show trip start notification
      await _notificationService.showTripStartNotification(
        startLocation: _currentTrip!.startLocation ?? 'Unknown Location',
        startTime: _currentTrip!.startTime!,
      );

      // Show persistent active trip notification
      await _notificationService.showActiveTripNotification(
        startLocation: _currentTrip!.startLocation ?? 'Unknown Location',
        startTime: _currentTrip!.startTime!,
        currentDistance: _currentTrip!.distance ?? 0.0,
      );

      // Trip start is now handled locally only
      debugPrint('✅ Trip started locally');
    } catch (e) {
      debugPrint('❌ Error starting trip: $e');
    }
  }

  /// Stop the current trip
  void _stopTrip() async {
    if (!_isTripActive || _currentTrip == null) return;

    debugPrint('🛑 Trip stopped - stationary detected');

    try {
      // Get current location
      Position? currentPosition;
      try {
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint('⚠️ Could not get current position: $e');
      }

      // Update trip end details
      _currentTrip = _currentTrip!.copyWith(
        endTime: DateTime.now(),
        endLatitude: currentPosition?.latitude,
        endLongitude: currentPosition?.longitude,
        endLocation: currentPosition != null
            ? '${currentPosition.latitude.toStringAsFixed(4)}, ${currentPosition.longitude.toStringAsFixed(4)}'
            : 'Unknown',
      );

      // Add final GPS log if available
      if (currentPosition != null && _currentTrip!.gpsLogs != null) {
        _currentTrip!.gpsLogs!.add(GpsLog(
          latitude: currentPosition.latitude,
          longitude: currentPosition.longitude,
          speed: currentPosition.speed,
          timestamp: currentPosition.timestamp,
        ));
      }

      // Calculate trip duration
      if (_currentTrip!.startTime != null && _currentTrip!.endTime != null) {
        final duration =
            _currentTrip!.endTime!.difference(_currentTrip!.startTime!);
        _currentTrip = _currentTrip!.copyWith(
          duration: duration.inSeconds,
        );
      }

      // Calculate distance from GPS logs
      _calculateTripDistance();

      // Show trip end notification
      await _notificationService.showTripEndNotification(
        endLocation: _currentTrip!.endLocation ?? 'Unknown Location',
        endTime: _currentTrip!.endTime!,
        distance: _currentTrip!.distance ?? 0.0,
        duration: _currentTrip!.duration ?? 0,
      );

      // Cancel persistent active trip notification
      await _notificationService.cancelActiveTripNotification();

      // Trip end is now handled locally only - will be saved after user confirmation
      debugPrint('✅ Trip completed locally - waiting for user confirmation');

      // Store completed trip for confirmation
      final completedTrip = _currentTrip;
      _lastCompletedTrip = completedTrip;

      // Reset state
      _isTripActive = false;
      _currentTrip = null;
      _resetBuffers();

      notifyListeners();

      // Show trip confirmation dialog after a short delay
      if (completedTrip != null) {
        Future.delayed(const Duration(seconds: 2), () {
          NavigationService().showTripConfirmationDialog(completedTrip);
        });
      }

      debugPrint('✅ Trip completed and saved');
    } catch (e) {
      debugPrint('❌ Error stopping trip: $e');
    }
  }

  /// Update current trip with new GPS data
  void _updateCurrentTrip(GpsLog gpsLog) {
    if (_currentTrip?.gpsLogs != null) {
      _currentTrip!.gpsLogs!.add(gpsLog);

      // Limit GPS logs to prevent memory issues (keep last 1000 points)
      if (_currentTrip!.gpsLogs!.length > 1000) {
        _currentTrip!.gpsLogs!
            .removeRange(0, _currentTrip!.gpsLogs!.length - 1000);
      }
    }
  }

  /// Calculate trip distance from GPS logs
  void _calculateTripDistance() {
    if (_currentTrip?.gpsLogs == null || _currentTrip!.gpsLogs!.length < 2) {
      return;
    }

    double totalDistance = 0.0;
    final logs = _currentTrip!.gpsLogs!;

    for (int i = 1; i < logs.length; i++) {
      double distance = Geolocator.distanceBetween(
        logs[i - 1].latitude,
        logs[i - 1].longitude,
        logs[i].latitude,
        logs[i].longitude,
      );
      totalDistance += distance;
    }

    _currentTrip = _currentTrip!.copyWith(distance: totalDistance);
  }

  /// Reset motion detection buffers
  void _resetBuffers() {
    _accelerationBuffer.clear();
    _gyroscopeBuffer.clear();
    _locationBuffer.clear();
    _motionCount = 0;
    _stationaryCount = 0;
    _resetSpeedTracking();
  }

  /// Manually start a trip (for testing or user override)
  Future<void> manualStartTrip() async {
    if (_isTripActive) return;
    _startTrip();
  }

  /// Manually stop a trip (for testing or user override)
  Future<void> manualStopTrip() async {
    if (!_isTripActive) return;
    _stopTrip();
  }

  /// Update persistent notification with current trip data
  Future<void> _updateActiveTripNotification() async {
    if (_currentTrip == null) return;

    try {
      await _notificationService.showActiveTripNotification(
        startLocation: _currentTrip!.startLocation ?? 'Unknown Location',
        startTime: _currentTrip!.startTime!,
        currentDistance: _currentTrip!.distance ?? 0.0,
      );
    } catch (e) {
      debugPrint('❌ Failed to update active trip notification: $e');
    }
  }

  /// Create a test trip with sample data (for testing purposes)
  Future<void> createTestTrip() async {
    if (_isTripActive) return;

    debugPrint('🧪 Creating test trip...');

    try {
      // Create a test trip with sample data
      final testTrip = Trip(
        tripId: DateTime.now().millisecondsSinceEpoch,
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
        endTime: DateTime.now(),
        startLatitude: 10.8505, // Kochi coordinates
        startLongitude: 76.2711,
        endLatitude: 10.8605,
        endLongitude: 76.2811,
        startLocation: 'Home, Kochi',
        endLocation: 'Office, Kochi',
        distance: 5.2, // km
        duration: 1800, // 30 minutes in seconds
        predictedMode: 'Car',
        purpose: 'Work',
        companions: 0,
        cost: 150.0,
        gpsLogs: _generateTestGpsLogs(),
      );

      // Store as completed trip for confirmation
      _lastCompletedTrip = testTrip;

      // Save trip locally as pending (needs confirmation)
      await LocalTripService.savePendingTrip(testTrip);

      debugPrint('✅ Test trip created and saved locally');

      // Show trip confirmation dialog
      Future.delayed(const Duration(seconds: 1), () {
        NavigationService().showTripConfirmationDialog(testTrip);
      });

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error creating test trip: $e');
    }
  }

  /// Generate sample GPS logs for test trip
  List<GpsLog> _generateTestGpsLogs() {
    final logs = <GpsLog>[];
    final startTime = DateTime.now().subtract(const Duration(minutes: 30));

    // Generate 10 GPS points along a route
    for (int i = 0; i < 10; i++) {
      final timestamp = startTime.add(Duration(minutes: i * 3));
      final lat = 10.8505 + (i * 0.001); // Move north
      final lng = 76.2711 + (i * 0.001); // Move east

      logs.add(GpsLog(
        latitude: lat,
        longitude: lng,
        speed: 25.0 + (i * 2), // Increasing speed
        timestamp: timestamp,
      ));
    }

    return logs;
  }

  /// Handle notification tap for trip confirmation
  void handleTripConfirmationNotification() {
    if (_lastCompletedTrip != null) {
      NavigationService().navigateToTripConfirmation(_lastCompletedTrip!);
    }
  }

  /// Get motion detection statistics
  Map<String, dynamic> getMotionStats() {
    return {
      'isMonitoring': _isMonitoring,
      'isTripActive': _isTripActive,
      'accelerationBuffer': _accelerationBuffer.length,
      'gyroscopeBuffer': _gyroscopeBuffer.length,
      'locationBuffer': _locationBuffer.length,
      'motionCount': _motionCount,
      'stationaryCount': _stationaryCount,
      'speedStartTime': _speedStartTime?.toIso8601String(),
      'totalDistanceDuringSpeed': _totalDistanceDuringSpeed,
      'speedTrackingLogs': _speedTrackingLogs.length,
      'currentTrip': _currentTrip?.toJson(),
      'latestAcceleration':
          _accelerationBuffer.isNotEmpty ? _accelerationBuffer.last : 0.0,
      'avgAcceleration': _accelerationBuffer.isNotEmpty
          ? _accelerationBuffer.reduce((a, b) => a + b) /
              _accelerationBuffer.length
          : 0.0,
    };
  }

  /// Debug function to test motion detection
  void debugMotionDetection() {
    final stats = getMotionStats();
    debugPrint('🔍 MOTION DEBUG:');
    debugPrint('  - Is Monitoring: ${stats['isMonitoring']}');
    debugPrint('  - Is Trip Active: ${stats['isTripActive']}');
    debugPrint('  - Latest Acceleration: ${stats['latestAcceleration']}');
    debugPrint('  - Average Acceleration: ${stats['avgAcceleration']}');
    debugPrint('  - Motion Count: ${stats['motionCount']}');
    debugPrint('  - Stationary Count: ${stats['stationaryCount']}');
    debugPrint('  - Speed Start Time: ${stats['speedStartTime']}');
    debugPrint(
        '  - Distance During Speed: ${stats['totalDistanceDuringSpeed']}');
    debugPrint('  - Location Buffer Size: ${stats['locationBuffer']}');
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
