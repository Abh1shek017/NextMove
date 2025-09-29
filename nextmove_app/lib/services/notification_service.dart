import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'motion_detection_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permission
      await _requestPermissions();

      // Android initialization settings
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Create notification channels for better organization
      await _createNotificationChannels();

      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      debugPrint('✅ Notification service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize notifications: $e');
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      const tripChannel = AndroidNotificationChannel(
        'trip_tracking',
        'Trip Tracking',
        description: 'Notifications for trip start, stop, and reminders',
        importance: Importance.high,
        playSound: true,
      );

      const reminderChannel = AndroidNotificationChannel(
        'trip_reminders',
        'Trip Reminders',
        description: 'Reminders to confirm your trips',
        importance: Importance.defaultImportance,
        playSound: false,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(tripChannel);

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(reminderChannel);
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (status != PermissionStatus.granted) {
        debugPrint('⚠️ Notification permission denied');
      }
    }
  }

  /// Show persistent notification for active trip
  Future<void> showActiveTripNotification({
    required String startLocation,
    required DateTime startTime,
    required double currentDistance,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final duration = DateTime.now().difference(startTime);
      final durationText = _formatDuration(duration);

      const androidDetails = AndroidNotificationDetails(
        'trip_tracking',
        'Trip Tracking',
        channelDescription: 'Active trip tracking notification',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        category: AndroidNotificationCategory.status,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        999, // Persistent notification ID
        '🚗 Trip in Progress',
        'Started from $startLocation • $durationText • ${currentDistance.toStringAsFixed(1)} km',
        details,
      );

      debugPrint('✅ Active trip notification shown');
    } catch (e) {
      debugPrint('❌ Failed to show active trip notification: $e');
    }
  }

  /// Cancel persistent trip notification
  Future<void> cancelActiveTripNotification() async {
    await _notifications.cancel(999);
    debugPrint('✅ Active trip notification cancelled');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 Notification tapped: ${response.payload}');

    // Handle different notification types based on payload
    switch (response.payload) {
      case 'trip_end':
        // Navigate to trip confirmation screen
        _handleTripEndNotification();
        break;
      case 'trip_start':
        // Could navigate to trip tracking screen
        break;
      case 'trip_confirm':
        // Handle trip confirmation reminder
        _handleTripConfirmationNotification();
        break;
      default:
        break;
    }
  }

  /// Handle trip end notification tap
  void _handleTripEndNotification() {
    // Navigate to trip confirmation using motion detection service
    MotionDetectionService().handleTripConfirmationNotification();
    debugPrint('📱 Trip end notification tapped - navigating to confirmation');
  }

  /// Handle trip confirmation notification tap
  void _handleTripConfirmationNotification() {
    // Navigate to trip confirmation using motion detection service
    MotionDetectionService().handleTripConfirmationNotification();
    debugPrint('📱 Trip confirmation notification tapped');
  }

  /// Show trip start notification
  Future<void> showTripStartNotification({
    required String startLocation,
    required DateTime startTime,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'trip_notifications',
      'Trip Notifications',
      channelDescription: 'Notifications for trip start and end',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1, // Unique ID for trip start
      '🚗 Trip Started',
      'Your trip from $startLocation has started at ${_formatTime(startTime)}',
      notificationDetails,
      payload: 'trip_start',
    );

    debugPrint('📱 Trip start notification shown');
  }

  /// Show trip end notification
  Future<void> showTripEndNotification({
    required String endLocation,
    required DateTime endTime,
    required double distance,
    required int duration,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'trip_notifications',
      'Trip Notifications',
      channelDescription: 'Notifications for trip start and end',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
      actions: [
        AndroidNotificationAction(
          'confirm_trip',
          'Confirm Trip',
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        AndroidNotificationAction(
          'dismiss',
          'Dismiss',
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'trip_end',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final durationText = _formatDuration(Duration(seconds: duration));
    final distanceText = distance < 1000
        ? '${distance.toStringAsFixed(0)}m'
        : '${(distance / 1000).toStringAsFixed(1)}km';

    await _notifications.show(
      2, // Unique ID for trip end
      '🏁 Trip Completed',
      'Trip ended at $endLocation\nDistance: $distanceText • Duration: $durationText\nTap to confirm details',
      notificationDetails,
      payload: 'trip_end',
    );

    debugPrint('📱 Trip end notification shown');
  }

  /// Show trip confirmation reminder notification
  Future<void> showTripConfirmationReminder({
    required String startLocation,
    required String endLocation,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'trip_reminders',
      'Trip Reminders',
      channelDescription: 'Reminder notifications for trip confirmation',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      3, // Unique ID for reminder
      '📝 Confirm Your Trip',
      'Please confirm details for your trip from $startLocation to $endLocation',
      notificationDetails,
      payload: 'trip_confirm',
    );

    debugPrint('📱 Trip confirmation reminder shown');
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('🗑️ All notifications cancelled');
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint('🗑️ Notification $id cancelled');
  }

  /// Format time for display
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  /// Get notification permission status
  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      return status == PermissionStatus.granted;
    }
    return true; // iOS handles this automatically
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status == PermissionStatus.granted;
    }
    return true; // iOS handles this automatically
  }
}
