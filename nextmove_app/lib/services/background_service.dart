import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_model.dart';
import 'app_lifecycle_service.dart';

/// Background service for continuous trip detection
class BackgroundService {
  static BackgroundService? _instance;
  static BackgroundService get instance => _instance ??= BackgroundService._();

  BackgroundService._();

  /// Initialize the background service
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode:
            false, // Start as background service, only go foreground when needed
        notificationChannelId: 'trip_tracking',
        initialNotificationTitle: 'NextMove',
        initialNotificationContent: 'Trip detection is running',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Start the background service
  static Future<void> start() async {
    final service = FlutterBackgroundService();

    // Check if already running
    final isRunning = await service.isRunning();
    if (isRunning) {
      debugPrint('✅ Background service already running');
      return;
    }

    // Only start if app is actually in background
    final lifecycleService = AppLifecycleService();
    if (lifecycleService.isAppInForeground) {
      debugPrint('⚠️ App is in foreground, not starting background service');
      return;
    }

    await service.startService();
    debugPrint('🚀 Background service started');
  }

  /// Stop the background service
  static Future<void> stop() async {
    final service = FlutterBackgroundService();

    final isRunning = await service.isRunning();
    if (!isRunning) {
      debugPrint('⚠️ Background service not running');
      return;
    }

    debugPrint('🛑 Stopping background service...');
    service.invoke('stop');

    // Clear any persistent notifications
    service.invoke('clear_notification');

    // Wait a bit for the service to actually stop
    await Future.delayed(const Duration(milliseconds: 500));

    // Verify it's stopped
    final stillRunning = await service.isRunning();
    if (stillRunning) {
      debugPrint('⚠️ Background service still running after stop command');
    } else {
      debugPrint('✅ Background service successfully stopped');
    }
  }

  /// Check if service is running
  static Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  /// Send data to background service
  static Future<void> sendData(Map<String, dynamic> data) async {
    final service = FlutterBackgroundService();
    service.invoke('data', data);
  }

  /// Send trip start command
  static Future<void> startTrip() async {
    await sendData({'action': 'start_trip'});
  }

  /// Send trip stop command
  static Future<void> stopTrip() async {
    await sendData({'action': 'stop_trip'});
  }

  /// Send trip confirmation
  static Future<void> confirmTrip(int tripId, String mode) async {
    await sendData({
      'action': 'confirm_trip',
      'trip_id': tripId,
      'mode': mode,
    });
  }
}

/// Background service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  debugPrint('🚀 Background service started');

  // Initialize background trip detector
  final detector = BackgroundTripDetector();
  await detector.initialize();

  // Handle service lifecycle
  service.on('stop').listen((_) {
    debugPrint('🛑 Background service stopping...');
    detector.dispose();
    service.stopSelf();
  });

  // Handle clearing notifications
  service.on('clear_notification').listen((_) {
    debugPrint('🧹 Clearing background service notification...');
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(title: '', content: '');
    }
  });

  // Handle data from main app
  service.on('data').listen((event) async {
    final data = event as Map<String, dynamic>;
    await detector.handleData(data);
  });

  // Keep service alive - only show notification during active trips
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      // Only show notification if there's an active trip
      if (detector._isTripActive) {
        service.setForegroundNotificationInfo(
          title: 'NextMove',
          content: 'Trip in progress',
        );
      } else {
        // Clear notification when no active trip
        service.setForegroundNotificationInfo(
          title: '',
          content: '',
        );
      }
    }

    // Update detector status
    await detector.updateStatus();
  });
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  debugPrint('🍎 iOS background service');
  return true;
}

/// Background trip detector running in isolate - OPTIMIZED FOR BATTERY
class BackgroundTripDetector {
  // GPS is only active during trips - NOT always running
  StreamSubscription<Position>? _locationSubscription;

  // Motion detection is always running (lightweight)
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  bool _isMotionMonitoring = false;
  bool _isGpsActive = false;
  bool _isTripActive = false;
  Trip? _currentTrip;

  // Trip detection variables
  final List<Position> _locationBuffer = [];
  final List<AccelerometerEvent> _motionBuffer = [];

  // Detection thresholds - OPTIMIZED FOR WALKING & BIKING
  static const double _speedThreshold =
      2.0; // km/h (walking ~3-5, biking ~15-25 km/h)
  static const double _minDistanceMeters = 30.0; // meters (30 meters minimum)
  static const int _stationaryRequired = 10; // for trip stop detection

  int _stationaryCount = 0;
  DateTime? _speedStartTime;
  double _totalDistanceDuringSpeed = 0.0;

  /// Initialize the detector - OPTIMIZED APPROACH
  Future<void> initialize() async {
    debugPrint('🔧 Initializing OPTIMIZED background trip detector...');

    try {
      // Check permissions
      final hasPermission = await _checkPermissions();
      if (!hasPermission) {
        debugPrint('❌ Background service: No location permission');
        return;
      }

      // Start ONLY motion monitoring (lightweight, always-on)
      await _startMotionMonitoring();

      debugPrint(
          '✅ OPTIMIZED Background detector initialized - Motion only, GPS will start during trips');
    } catch (e) {
      debugPrint('❌ Failed to initialize background detector: $e');
    }
  }

  /// Check location permissions
  Future<bool> _checkPermissions() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('❌ Permission check failed: $e');
      return false;
    }
  }

  /// Start ONLY motion monitoring (lightweight, always-on)
  Future<void> _startMotionMonitoring() async {
    if (_isMotionMonitoring) return;

    try {
      // Start ONLY motion monitoring (lightweight)
      _accelerometerSubscription =
          accelerometerEventStream().listen(_onAccelerometerUpdate);

      _isMotionMonitoring = true;
      debugPrint(
          '✅ Lightweight motion monitoring started (GPS will start during trips)');
    } catch (e) {
      debugPrint('❌ Failed to start motion monitoring: $e');
    }
  }

  /// Start GPS monitoring ONLY during trips
  Future<void> _startGpsMonitoring() async {
    if (_isGpsActive) return;

    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(_onLocationUpdate, onError: _onLocationError);

      _isGpsActive = true;
      debugPrint('🚀 GPS monitoring started for trip');
    } catch (e) {
      debugPrint('❌ Failed to start GPS monitoring: $e');
    }
  }

  /// Stop GPS monitoring when trip ends
  Future<void> _stopGpsMonitoring() async {
    if (!_isGpsActive) return;

    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _isGpsActive = false;

    debugPrint('🛑 GPS monitoring stopped - battery optimized');
  }

  /// Handle location updates
  void _onLocationUpdate(Position position) {
    _locationBuffer.add(position);

    // Keep only recent positions
    final cutoffTime = DateTime.now().subtract(const Duration(minutes: 5));
    _locationBuffer.removeWhere((pos) => pos.timestamp.isBefore(cutoffTime));

    // Show current speed in terminal
    _logCurrentSpeed(position);

    // Process for trip detection
    _processLocationForTripDetection(position);
  }

  /// Handle accelerometer updates - OPTIMIZED APPROACH
  void _onAccelerometerUpdate(AccelerometerEvent event) {
    _motionBuffer.add(event);

    // Keep only recent events (sensors_plus doesn't have timestamp, use current time)
    // For now, keep all events since we can't filter by timestamp
    if (_motionBuffer.length > 100) {
      _motionBuffer.removeRange(0, 50); // Remove old events
    }

    // Process motion for trip detection
    _processMotionForTripDetection(event);
  }

  /// Log current speed to terminal for debugging (Background Service)
  void _logCurrentSpeed(Position position) {
    final speedMs = position.speed;
    final speedKmh = speedMs * 3.6;
    final accuracy = position.accuracy;
    final timestamp = DateTime.now();

    debugPrint(
        '🔄 BACKGROUND SPEED: ${speedKmh.toStringAsFixed(2)} km/h (${speedMs.toStringAsFixed(2)} m/s) | Accuracy: ${accuracy.toStringAsFixed(1)}m | Time: ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}');
  }

  /// Process location for trip start detection
  void _processLocationForTripDetection(Position position) {
    final speedKmh = position.speed * 3.6; // Convert m/s to km/h

    if (speedKmh > _speedThreshold) {
      // Moving - track speed and distance
      if (_speedStartTime == null) {
        _speedStartTime = position.timestamp;
        _totalDistanceDuringSpeed = 0.0;
        debugPrint('🚗 Background: Speed tracking started');
      } else {
        // Calculate distance since speed start
        final lastPosition = _locationBuffer.isNotEmpty
            ? _locationBuffer[_locationBuffer.length - 2]
            : position;

        final distance = Geolocator.distanceBetween(
          lastPosition.latitude,
          lastPosition.longitude,
          position.latitude,
          position.longitude,
        );
        _totalDistanceDuringSpeed += distance;

        // Check trip start conditions
        final duration = position.timestamp.difference(_speedStartTime!);
        if (duration.inSeconds >= 30 && // 30 seconds for walking/biking
            _totalDistanceDuringSpeed >= _minDistanceMeters) {
          debugPrint('✅ Background: Trip start detected');
          _startTrip(position);
          _resetSpeedTracking();
        }
      }
    } else {
      // Speed dropped below threshold
      if (_speedStartTime != null) {
        debugPrint('⚠️ Background: Speed dropped, resetting tracking');
        _resetSpeedTracking();
      }
    }
  }

  /// Process motion for trip detection - OPTIMIZED APPROACH
  void _processMotionForTripDetection(dynamic event) {
    // Calculate motion magnitude
    final magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    // Remove gravity (approximately 9.81 m/s²) to get net acceleration
    final netAcceleration = (magnitude - 9.81).abs();

    // Debug motion magnitude (only log occasionally to avoid spam)
    if (DateTime.now().millisecond % 1000 < 50) {
      // Log ~5% of the time
      debugPrint(
          '📱 Background net acceleration: ${netAcceleration.toStringAsFixed(3)}');
    }

    if (_isTripActive) {
      // Trip is active - check for stop
      if (netAcceleration < 0.5) {
        // Trip stop threshold for biking (very smooth motion)
        _stationaryCount++;
      } else {
        _stationaryCount = 0;
      }

      // Trip stop detection
      if (_stationaryCount >= _stationaryRequired) {
        debugPrint('🛑 Background: Trip stop detected');
        _stopTrip();
      }
    } else {
      // No active trip - check for trip start
      // Optimized for both walking and biking
      if (netAcceleration > 0.8) {
        // High threshold to filter out phone vibrations and noise
        debugPrint(
            '🚗 Background: Significant motion detected (${netAcceleration.toStringAsFixed(2)}) - starting GPS to check for trip');
        _startGpsMonitoring();

        // Set a timer to stop GPS if no trip starts
        Timer(const Duration(minutes: 2), () {
          if (!_isTripActive && _isGpsActive) {
            debugPrint('⏰ Background: No trip detected, stopping GPS');
            _stopGpsMonitoring();
          }
        });
      }
    }
  }

  /// Start a trip - WITH NOTIFICATION
  Future<void> _startTrip(Position startPosition) async {
    if (_isTripActive) return;

    try {
      _currentTrip = Trip(
        tripId: DateTime.now().millisecondsSinceEpoch,
        startTime: startPosition.timestamp,
        startLatitude: startPosition.latitude,
        startLongitude: startPosition.longitude,
        startLocation: 'Background Detected Location',
        distance: 0.0,
        duration: 0,
      );

      _isTripActive = true;

      // Send trip start notification
      await _sendTripStartNotification();

      // Save trip locally
      await _saveTripLocally(_currentTrip!);

      debugPrint('✅ Background: Trip started - ${_currentTrip!.tripId}');
    } catch (e) {
      debugPrint('❌ Background: Failed to start trip: $e');
    }
  }

  /// Stop the current trip
  Future<void> _stopTrip() async {
    if (!_isTripActive || _currentTrip == null) return;

    try {
      final endPosition =
          _locationBuffer.isNotEmpty ? _locationBuffer.last : null;

      if (endPosition != null) {
        _currentTrip = _currentTrip!.copyWith(
          endTime: endPosition.timestamp,
          endLatitude: endPosition.latitude,
          endLongitude: endPosition.longitude,
          endLocation: 'Background Detected Location',
          duration: endPosition.timestamp
              .difference(_currentTrip!.startTime!)
              .inSeconds,
        );

        // Calculate distance
        _calculateTripDistance();
      }

      _isTripActive = false;

      // Send trip end notification asking for confirmation
      await _sendTripConfirmationNotification();

      // Save completed trip
      await _saveTripLocally(_currentTrip!);

      // Stop GPS to save battery
      await _stopGpsMonitoring();

      debugPrint('✅ Background: Trip completed - ${_currentTrip!.tripId}');
      _currentTrip = null;
    } catch (e) {
      debugPrint('❌ Background: Failed to stop trip: $e');
    }
  }

  /// Calculate trip distance
  void _calculateTripDistance() {
    if (_currentTrip == null) return;

    double totalDistance = 0.0;
    for (int i = 1; i < _locationBuffer.length; i++) {
      final prev = _locationBuffer[i - 1];
      final curr = _locationBuffer[i];

      final distance = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );
      totalDistance += distance;
    }

    _currentTrip = _currentTrip!.copyWith(distance: totalDistance);
  }

  /// Reset speed tracking
  void _resetSpeedTracking() {
    _speedStartTime = null;
    _totalDistanceDuringSpeed = 0.0;
  }

  /// Send trip start notification
  Future<void> _sendTripStartNotification() async {
    try {
      // This would integrate with the notification service
      // For now, we'll use the existing notification service
      debugPrint('📱 Background: Sending trip start notification');

      // In a real implementation, you'd call the notification service here
      // await NotificationService().showTripStartNotification(...);
    } catch (e) {
      debugPrint('❌ Background: Failed to send trip start notification: $e');
    }
  }

  /// Send trip confirmation notification
  Future<void> _sendTripConfirmationNotification() async {
    try {
      debugPrint('📱 Background: Sending trip confirmation notification');

      // In a real implementation, you'd call the notification service here
      // await NotificationService().showTripConfirmationReminder(...);
    } catch (e) {
      debugPrint(
          '❌ Background: Failed to send trip confirmation notification: $e');
    }
  }

  /// Save trip to local storage
  Future<void> _saveTripLocally(Trip trip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tripsJson = prefs.getStringList('background_trips') ?? [];
      tripsJson.add(trip.toJson().toString());
      await prefs.setStringList('background_trips', tripsJson);

      debugPrint('💾 Background: Trip saved locally');
    } catch (e) {
      debugPrint('❌ Background: Failed to save trip: $e');
    }
  }

  /// Handle data from main app
  Future<void> handleData(Map<String, dynamic> data) async {
    final action = data['action'] as String?;

    switch (action) {
      case 'start_trip':
        debugPrint('📱 Background: Manual trip start requested');
        // Could implement manual trip start
        break;
      case 'stop_trip':
        debugPrint('📱 Background: Manual trip stop requested');
        if (_isTripActive) {
          await _stopTrip();
        }
        break;
      case 'confirm_trip':
        debugPrint('📱 Background: Trip confirmation requested');
        // Could implement trip confirmation sync
        break;
    }
  }

  /// Update status
  Future<void> updateStatus() async {
    // Could implement status reporting
  }

  /// Handle location errors
  void _onLocationError(dynamic error) {
    debugPrint('❌ Background: Location error: $error');
  }

  /// Dispose resources
  void dispose() {
    _stopGpsMonitoring();
    _stopMotionMonitoring();
    debugPrint('🧹 Background detector disposed');
  }

  /// Stop motion monitoring
  Future<void> _stopMotionMonitoring() async {
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _isMotionMonitoring = false;

    debugPrint('🛑 Motion monitoring stopped');
  }
}
