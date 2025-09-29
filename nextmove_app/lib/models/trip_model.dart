class Trip {
  final int? tripId;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? predictedMode;
  final String? confirmedMode;
  final String? purpose;
  final int? companions;
  final double? cost;
  final double? distance;
  final int? duration;
  final String? startLocation;
  final String? endLocation;
  final String? comment;
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;
  final Map<String, dynamic>? features;
  final List<GpsLog>? gpsLogs;

  Trip({
    this.tripId,
    this.startTime,
    this.endTime,
    this.predictedMode,
    this.confirmedMode,
    this.purpose,
    this.companions,
    this.cost,
    this.distance,
    this.duration,
    this.startLocation,
    this.endLocation,
    this.comment,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    this.features,
    this.gpsLogs,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      tripId: json['trip_id'],
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'])
          : null,
      endTime:
          json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      predictedMode: json['predicted_mode'],
      confirmedMode: json['confirmed_mode'],
      purpose: json['purpose'],
      companions: json['companions'],
      cost: json['cost']?.toDouble(),
      distance:
          json['distance_km']?.toDouble(), // Updated to match backend field
      duration: json['duration_min']?.toInt(), // Updated to match backend field
      startLocation: json['start_location'],
      endLocation: json['end_location'],
      comment: json['comment'],
      startLatitude: json['start_latitude']?.toDouble(),
      startLongitude: json['start_longitude']?.toDouble(),
      endLatitude: json['end_latitude']?.toDouble(),
      endLongitude: json['end_longitude']?.toDouble(),
      features: json['features'],
      gpsLogs: json['gps_logs'] != null
          ? (json['gps_logs'] as List)
              .map((log) => GpsLog.fromJson(log))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (tripId != null) 'trip_id': tripId,
      if (startTime != null) 'start_time': startTime!.toIso8601String(),
      if (endTime != null) 'end_time': endTime!.toIso8601String(),
      if (predictedMode != null) 'predicted_mode': predictedMode,
      if (confirmedMode != null) 'confirmed_mode': confirmedMode,
      if (purpose != null) 'purpose': purpose,
      if (companions != null) 'companions': companions,
      if (cost != null) 'cost': cost,
      if (distance != null) 'distance': distance,
      if (duration != null) 'duration': duration,
      if (startLocation != null) 'start_location': startLocation,
      if (endLocation != null) 'end_location': endLocation,
      if (comment != null) 'comment': comment,
      if (startLatitude != null) 'start_latitude': startLatitude,
      if (startLongitude != null) 'start_longitude': startLongitude,
      if (endLatitude != null) 'end_latitude': endLatitude,
      if (endLongitude != null) 'end_longitude': endLongitude,
      if (features != null) 'features': features,
    };
  }

  String get durationFormatted {
    if (duration == null) return 'Unknown';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get distanceFormatted {
    if (distance == null) return 'Unknown';
    if (distance! < 1000) {
      return '${distance!.toStringAsFixed(0)}m';
    } else {
      return '${(distance! / 1000).toStringAsFixed(1)}km';
    }
  }

  Trip copyWith({
    int? tripId,
    DateTime? startTime,
    DateTime? endTime,
    String? predictedMode,
    String? confirmedMode,
    String? purpose,
    int? companions,
    double? cost,
    double? distance,
    int? duration,
    String? startLocation,
    String? endLocation,
    String? comment,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    Map<String, dynamic>? features,
    List<GpsLog>? gpsLogs,
  }) {
    return Trip(
      tripId: tripId ?? this.tripId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      predictedMode: predictedMode ?? this.predictedMode,
      confirmedMode: confirmedMode ?? this.confirmedMode,
      purpose: purpose ?? this.purpose,
      companions: companions ?? this.companions,
      cost: cost ?? this.cost,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      comment: comment ?? this.comment,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      features: features ?? this.features,
      gpsLogs: gpsLogs ?? this.gpsLogs,
    );
  }
}

class GpsLog {
  final double latitude;
  final double longitude;
  final double? speed;
  final DateTime timestamp;

  GpsLog({
    required this.latitude,
    required this.longitude,
    this.speed,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory GpsLog.fromJson(Map<String, dynamic> json) {
    return GpsLog(
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      speed: json['speed']?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed ?? 0.0,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
