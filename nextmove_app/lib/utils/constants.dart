import 'package:flutter/material.dart';

class AppConstants {
  // API Configuration
  static const String baseUrl = 'http://10.74.252.98:8000';
  static const String apiBaseUrl = 'http://10.74.252.98:8000';

  // GPS Configuration
  static const int gpsIntervalSeconds = 10;
  static const double minDistanceMeters = 50.0;
  static const double locationAccuracy = 10.0;

  // Trip thresholds
  static const int minTripDurationSeconds = 30;
  static const double minTripDistanceMeters = 100.0;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double borderRadius = 12.0;

  // Mode colors
  static const Map<String, int> modeColors = {
    'walk': 0xFF4CAF50, // Green
    'bike': 0xFF2196F3, // Blue
    'car': 0xFFFF9800, // Orange
    'bus': 0xFF9C27B0, // Purple
  };

  // Mode icons
  static const Map<String, String> modeIcons = {
    'walk': '🚶',
    'bike': '🚴',
    'car': '🚗',
    'bus': '🚌',
  };

  // Transport modes
  static const List<String> transportModes = [
    'Car',
    'Bus',
    'Walk',
    'Bike',
    'Auto/Taxi',
    'Train',
    'Other'
  ];

  // Trip purposes
  static const List<String> tripPurposes = [
    'Work',
    'Home',
    'Shopping',
    'Education',
    'Healthcare',
    'Recreation',
    'Social',
    'Other'
  ];

  // Age groups
  static const List<String> ageGroups = [
    '18-25',
    '26-35',
    '36-45',
    '46-55',
    '56-65',
    '65+'
  ];

  // Gender options
  static const List<String> genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say'
  ];

  // Occupation options
  static const List<String> occupations = [
    'Student',
    'Government Employee',
    'Private Employee',
    'Self-employed',
    'Business Owner',
    'Homemaker',
    'Retired',
    'Unemployed',
    'Other'
  ];

  // Monthly income options
  static const List<String> monthlyIncomes = [
    'Below ₹20,000',
    '₹20,000 - ₹40,000',
    '₹40,000 - ₹60,000',
    '₹60,000 - ₹80,000',
    '₹80,000 - ₹1,00,000',
    'Above ₹1,00,000',
    'Prefer not to say'
  ];

  // Shared preferences keys
  static const String keyUserId = 'user_id';
  static const String keyPhoneNumber = 'phone_number';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyHasCompletedProfile = 'has_completed_profile';
  static const String keyFullName = 'full_name';
  static const String keyAgeGroup = 'age_group';
  static const String keyGender = 'gender';
  static const String keyOccupation = 'occupation';
  static const String keyMonthlyIncome = 'monthly_income';
  static const String keyActiveTripId = 'active_trip_id';
  static const String keyHasGrantedPermissions = 'has_granted_permissions';
}

enum TripStatus {
  idle,
  active,
  stopping,
  predicting,
  confirming,
}

enum TransportMode {
  walk,
  bike,
  car,
  bus,
}

class AppTheme {
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFF44336);
  static const Color backgroundGrey = Color(0xFFF5F5F5);

  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: Colors.black87,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: Colors.black87,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: Colors.grey,
  );
}
