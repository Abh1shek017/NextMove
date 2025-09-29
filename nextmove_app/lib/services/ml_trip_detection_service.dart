import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

/// ML-based trip detection service
class MLTripDetectionService {
  static final MLTripDetectionService _instance =
      MLTripDetectionService._internal();
  factory MLTripDetectionService() => _instance;
  MLTripDetectionService._internal();

  // Buffer for sensor data
  final List<Map<String, dynamic>> _sensorBuffer = [];
  static const int _bufferSize = 50; // Keep last 50 sensor readings

  // ML prediction settings
  static const double _mlConfidenceThreshold = 0.7;
  static const Duration _predictionInterval =
      Duration(seconds: 2); // Predict every 2 seconds
  DateTime? _lastPredictionTime;

  /// Add sensor data to buffer
  void addSensorData({
    required double accelerationX,
    required double accelerationY,
    required double accelerationZ,
    required double gyroscopeX,
    required double gyroscopeY,
    required double gyroscopeZ,
    double? speed,
    DateTime? timestamp,
  }) {
    final sensorData = {
      'acceleration_x': accelerationX,
      'acceleration_y': accelerationY,
      'acceleration_z': accelerationZ,
      'gyroscope_x': gyroscopeX,
      'gyroscope_y': gyroscopeY,
      'gyroscope_z': gyroscopeZ,
      'speed': speed,
      'timestamp': timestamp ?? DateTime.now(),
    };

    _sensorBuffer.add(sensorData);

    // Keep buffer size manageable
    if (_sensorBuffer.length > _bufferSize) {
      _sensorBuffer.removeAt(0);
    }

    // Check if it's time to make a prediction (every 2 seconds)
    final now = DateTime.now();
    if (_lastPredictionTime == null ||
        now.difference(_lastPredictionTime!) >= _predictionInterval) {
      _lastPredictionTime = now;
      // Temporarily disabled due to 404 error - ML endpoints not available
      // _makeMLPrediction();
      debugPrint(
          '⚠️ ML predictions disabled - using rule-based detection only');
    }
  }

  /// Make ML prediction for trip start/end
  Future<void> _makeMLPrediction() async {
    if (_sensorBuffer.length < 10) return; // Need minimum data

    try {
      // Extract features from sensor data
      final features = _extractFeatures(_sensorBuffer);

      // Send to backend for ML prediction
      final prediction = await _predictTripDetection(features);

      if (prediction != null) {
        final isTripStarting = prediction['trip_start'] as bool;
        final isTripEnding = prediction['trip_end'] as bool;
        final startConfidence = prediction['start_confidence'] as double;
        final endConfidence = prediction['end_confidence'] as double;

        // Log predictions for debugging
        if (isTripStarting && startConfidence > _mlConfidenceThreshold) {
          debugPrint(
              '🧠 ML: Trip start predicted with confidence ${startConfidence.toStringAsFixed(2)}');
          // Trigger trip start logic here
          _onMLTripStartDetected();
        }

        if (isTripEnding && endConfidence > _mlConfidenceThreshold) {
          debugPrint(
              '🧠 ML: Trip end predicted with confidence ${endConfidence.toStringAsFixed(2)}');
          // Trigger trip end logic here
          _onMLTripEndDetected();
        }
      }
    } catch (e) {
      debugPrint('❌ ML prediction error: $e');
    }
  }

  /// Extract features from sensor data buffer
  Map<String, dynamic> _extractFeatures(List<Map<String, dynamic>> sensorData) {
    if (sensorData.isEmpty) return {};

    // Extract arrays for calculations
    final accelX =
        sensorData.map((d) => d['acceleration_x'] as double).toList();
    final accelY =
        sensorData.map((d) => d['acceleration_y'] as double).toList();
    final accelZ =
        sensorData.map((d) => d['acceleration_z'] as double).toList();
    final gyroX = sensorData.map((d) => d['gyroscope_x'] as double).toList();
    final gyroY = sensorData.map((d) => d['gyroscope_y'] as double).toList();
    final gyroZ = sensorData.map((d) => d['gyroscope_z'] as double).toList();
    final speeds = sensorData
        .where((d) => d['speed'] != null)
        .map((d) => d['speed'] as double)
        .toList();

    // Calculate acceleration magnitude
    final accelMagnitude = <double>[];
    for (int i = 0; i < sensorData.length; i++) {
      final mag = sqrt(accelX[i] * accelX[i] +
          accelY[i] * accelY[i] +
          accelZ[i] * accelZ[i]);
      accelMagnitude.add(mag);
    }

    // Remove gravity (approximately 9.81 m/s²)
    final netAcceleration =
        accelMagnitude.map((mag) => (mag - 9.81).abs()).toList();

    // Calculate gyroscope magnitude
    final gyroMagnitude = <double>[];
    for (int i = 0; i < sensorData.length; i++) {
      final mag =
          sqrt(gyroX[i] * gyroX[i] + gyroY[i] * gyroY[i] + gyroZ[i] * gyroZ[i]);
      gyroMagnitude.add(mag);
    }

    // Statistical features
    final features = <String, dynamic>{
      // Acceleration features
      'accel_mean': _mean(netAcceleration),
      'accel_std': _std(netAcceleration),
      'accel_max': netAcceleration.reduce(max),
      'accel_min': netAcceleration.reduce(min),
      'accel_median': _median(netAcceleration),
      'accel_q75': _percentile(netAcceleration, 75),
      'accel_q25': _percentile(netAcceleration, 25),

      // Gyroscope features
      'gyro_mean': _mean(gyroMagnitude),
      'gyro_std': _std(gyroMagnitude),
      'gyro_max': gyroMagnitude.reduce(max),

      // Motion pattern features
      'accel_variance': _variance(netAcceleration),
      'accel_skewness': _skewness(netAcceleration),
      'accel_kurtosis': _kurtosis(netAcceleration),

      // Speed features
      'speed_mean': speeds.isNotEmpty ? _mean(speeds) : 0.0,
      'speed_std': speeds.isNotEmpty ? _std(speeds) : 0.0,
      'speed_max': speeds.isNotEmpty ? speeds.reduce(max) : 0.0,

      // Temporal features
      'data_points': sensorData.length,
      'time_span': _calculateTimeSpan(sensorData),

      // Motion intensity features
      'high_motion_ratio':
          netAcceleration.where((a) => a > 2.0).length / netAcceleration.length,
      'low_motion_ratio':
          netAcceleration.where((a) => a < 0.5).length / netAcceleration.length,
      'motion_consistency': _calculateMotionConsistency(netAcceleration),
    };

    return features;
  }

  /// Send features to backend for ML prediction
  Future<Map<String, dynamic>?> _predictTripDetection(
      Map<String, dynamic> features) async {
    try {
      final headers = await AuthService.getAuthHeaders();

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/ml/predict_trip_detection'),
        headers: headers,
        body: jsonEncode({'features': features}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('❌ ML prediction failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ ML prediction request failed: $e');
      return null;
    }
  }

  /// Handle ML-detected trip start
  void _onMLTripStartDetected() {
    debugPrint('🚀 ML Trip Start Detected!');
    // This would integrate with your existing trip start logic
    // For example, call MotionDetectionService()._startTrip()
  }

  /// Handle ML-detected trip end
  void _onMLTripEndDetected() {
    debugPrint('🛑 ML Trip End Detected!');
    // This would integrate with your existing trip end logic
    // For example, call MotionDetectionService()._stopTrip()
  }

  /// Submit training data to backend
  static Future<bool> submitTrainingData({
    required Map<String, dynamic> features,
    required bool tripStartLabel,
    required bool tripEndLabel,
    String? context,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();

      final trainingData = {
        'features': features,
        'trip_start_label': tripStartLabel,
        'trip_end_label': tripEndLabel,
        'context': context,
      };

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/ml/submit_training_data'),
        headers: headers,
        body: jsonEncode(trainingData),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Failed to submit training data: $e');
      return false;
    }
  }

  /// Clear sensor buffer
  void clearBuffer() {
    _sensorBuffer.clear();
    _lastPredictionTime = null;
  }

  /// Get current buffer size
  int get bufferSize => _sensorBuffer.length;

  // Helper methods for statistical calculations
  double _mean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _std(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = _mean(values);
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
            values.length;
    return sqrt(variance);
  }

  double _median(List<double> values) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length % 2 == 1
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  double _percentile(List<double> values, int percentile) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final index = (percentile / 100) * (sorted.length - 1);
    final lower = sorted[index.floor()];
    final upper = sorted[index.ceil()];
    return lower + (upper - lower) * (index - index.floor());
  }

  double _variance(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = _mean(values);
    return values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
        values.length;
  }

  double _skewness(List<double> values) {
    if (values.length < 3) return 0.0;
    final mean = _mean(values);
    final std = _std(values);
    if (std == 0) return 0.0;
    final skew =
        values.map((v) => pow((v - mean) / std, 3)).reduce((a, b) => a + b) /
            values.length;
    return skew;
  }

  double _kurtosis(List<double> values) {
    if (values.length < 4) return 0.0;
    final mean = _mean(values);
    final std = _std(values);
    if (std == 0) return 0.0;
    final kurt =
        values.map((v) => pow((v - mean) / std, 4)).reduce((a, b) => a + b) /
            values.length;
    return kurt - 3; // Excess kurtosis
  }

  double _calculateTimeSpan(List<Map<String, dynamic>> sensorData) {
    if (sensorData.length < 2) return 0.0;
    final first = sensorData.first['timestamp'] as DateTime;
    final last = sensorData.last['timestamp'] as DateTime;
    return last.difference(first).inSeconds.toDouble();
  }

  double _calculateMotionConsistency(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = _mean(values);
    final std = _std(values);
    if (mean == 0) return 0.0;
    final consistency = 1.0 - (std / (mean + 1e-6));
    return consistency.clamp(0.0, 1.0);
  }
}
