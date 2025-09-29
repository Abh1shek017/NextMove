import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class AuthService extends ChangeNotifier {
  static const String _tokenKey = 'auth_token';
  static const String _phoneKey = 'user_phone';

  User? _currentUser;
  bool _isLoggedIn = false;
  bool _hasCompletedProfile = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get hasCompletedProfile => _hasCompletedProfile;

  Future<void> initialize() async {
    final token = await getToken();
    final phone = await getPhone();

    if (token != null && phone != null) {
      _isLoggedIn = true;
      _currentUser = User(phoneNumber: phone);

      // Try to get user info from backend
      try {
        await _loadUserInfo();
      } catch (e) {
        // If token is invalid, clear auth
        await logout();
        return;
      }
    } else {
      _isLoggedIn = false;
      _currentUser = null;
      _hasCompletedProfile = false;
    }

    notifyListeners();
  }

  // Load user info from backend
  Future<void> _loadUserInfo() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/auth/me'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = User(
          phoneNumber: data['phone_number'] ?? _currentUser?.phoneNumber ?? '',
          fullName: data['name'],
          ageGroup: data['age_group'],
          gender: data['gender'],
          occupation: data['occupation'],
          monthlyIncome: data['income_group'],
        );
        _hasCompletedProfile = _currentUser?.fullName != null &&
            _currentUser!.fullName!.isNotEmpty;
      } else {
        throw Exception('Failed to load user info');
      }
    } catch (e) {
      throw Exception('Failed to load user info: $e');
    }
  }

  // Save token and phone
  static Future<void> saveAuth(String token, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_phoneKey, phone);
  }

  // Get token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Get phone
  static Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  // Clear auth
  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_phoneKey);
  }

  // Send OTP to phone number
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/send_otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Verify OTP and login
  Future<bool> verifyOtp(String phoneNumber, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/verify_otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
          'otp': otp,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveAuth(data['access_token'], phoneNumber);

        // Update user info from response
        final userData = data['user'] ?? {};
        _currentUser = User(
          phoneNumber: phoneNumber,
          fullName: userData['name'],
          ageGroup: userData['age_group'],
          gender: userData['gender'],
          occupation: userData['occupation'],
          monthlyIncome: userData['income_group'],
        );
        _isLoggedIn = true;
        _hasCompletedProfile = userData['has_completed_profile'] ?? false;

        notifyListeners();
        return true;
      } else if (response.statusCode == 404) {
        // New user - OTP verified but needs profile setup
        return false; // Will trigger profile setup flow
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Complete profile for new users
  Future<bool> completeProfile({
    required String phoneNumber,
    required String name,
    required String ageGroup,
    required String gender,
    required String occupation,
    required String incomeGroup,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
          'name': name,
          'age_group': ageGroup,
          'gender': gender,
          'occupation': occupation,
          'income_group': incomeGroup,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveAuth(data['access_token'], phoneNumber);

        // Update user info from response
        final userData = data['user'] ?? {};
        _currentUser = User(
          phoneNumber: phoneNumber,
          fullName: userData['name'] ?? name,
          ageGroup: userData['age_group'] ?? ageGroup,
          gender: userData['gender'] ?? gender,
          occupation: userData['occupation'] ?? occupation,
          monthlyIncome: userData['income_group'] ?? incomeGroup,
        );
        _isLoggedIn = true;
        _hasCompletedProfile = userData['has_completed_profile'] ?? true;

        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await clearAuth();

    _currentUser = null;
    _isLoggedIn = false;
    _hasCompletedProfile = false;

    notifyListeners();
  }

  // Helper method to get authorization headers for API calls
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    if (token != null) {
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    }
    return {'Content-Type': 'application/json'};
  }

  // Get past trips
  static Future<List<Map<String, dynamic>>> getPastTrips({
    int limit = 50,
    int offset = 0,
  }) async {
    final headers = await getAuthHeaders();

    if (!headers.containsKey('Authorization')) {
      throw Exception("Not authenticated");
    }

    final response = await http.get(
      Uri.parse(
          '${AppConstants.baseUrl}/trip/past_trips?limit=$limit&offset=$offset'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['trips'] ?? []);
    } else {
      throw Exception(
        'Failed to fetch trips: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Start a new trip
  static Future<Map<String, dynamic>> startTrip({
    double? startLatitude,
    double? startLongitude,
    String? startLocation,
  }) async {
    final headers = await getAuthHeaders();

    if (!headers.containsKey('Authorization')) {
      throw Exception("Not authenticated");
    }

    final body = <String, dynamic>{};
    if (startLatitude != null) body['start_latitude'] = startLatitude;
    if (startLongitude != null) body['start_longitude'] = startLongitude;
    if (startLocation != null) body['start_location'] = startLocation;

    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/trip/start'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to start trip: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Stop the current trip
  static Future<Map<String, dynamic>> stopTrip({
    required int tripId,
    double? endLatitude,
    double? endLongitude,
    String? endLocation,
    String? purpose,
    int? companions,
    double? cost,
    String? comment,
  }) async {
    final headers = await getAuthHeaders();

    if (!headers.containsKey('Authorization')) {
      throw Exception("Not authenticated");
    }

    final body = <String, dynamic>{};
    if (endLatitude != null) body['end_latitude'] = endLatitude;
    if (endLongitude != null) body['end_longitude'] = endLongitude;
    if (endLocation != null) body['end_location'] = endLocation;
    if (purpose != null) body['purpose'] = purpose;
    if (companions != null) body['companions'] = companions;
    if (cost != null) body['cost'] = cost;
    if (comment != null) body['comment'] = comment;

    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/trip/stop/$tripId'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to stop trip: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Confirm trip mode
  static Future<void> confirmTrip({
    required int tripId,
    required String confirmedMode,
    String? purpose,
    String? comment,
  }) async {
    final headers = await getAuthHeaders();

    if (!headers.containsKey('Authorization')) {
      throw Exception("Not authenticated");
    }

    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/trip/confirm/$tripId'),
      headers: headers,
      body: jsonEncode({
        'confirmed_mode': confirmedMode,
        'purpose': purpose,
        'comment': comment,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Confirmation failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Edit trip details
  static Future<void> editTrip({
    required int tripId,
    String? purpose,
    String? confirmedMode,
    String? startLocation,
    String? endLocation,
    double? cost,
    int? companions,
    String? comment,
  }) async {
    final headers = await getAuthHeaders();

    if (!headers.containsKey('Authorization')) {
      throw Exception("Not authenticated");
    }

    final body = <String, dynamic>{};
    if (purpose != null) body['purpose'] = purpose;
    if (confirmedMode != null) body['confirmed_mode'] = confirmedMode;
    if (startLocation != null) body['start_location'] = startLocation;
    if (endLocation != null) body['end_location'] = endLocation;
    if (cost != null) body['cost'] = cost;
    if (companions != null) body['companions'] = companions;
    if (comment != null) body['comment'] = comment;

    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/trip/edit/$tripId'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to edit trip: ${response.statusCode} - ${response.body}',
      );
    }
  }
}
