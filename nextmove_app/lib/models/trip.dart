// lib/models/trip.dart
class Trip {
  final int id;
  final double distance;
  final int duration;
  final String predictedMode;
  final String startTime;

  Trip({
    required this.id,
    required this.distance,
    required this.duration,
    required this.predictedMode,
    required this.startTime,
  });
}