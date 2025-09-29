import 'dart:async';
import 'package:flutter/widgets.dart';
import 'background_service.dart';
import 'motion_detection_service.dart';

/// Manages app lifecycle and coordinates foreground/background services
class AppLifecycleService extends WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  bool _isInitialized = false;
  bool _isAppInForeground = true;

  /// Initialize the lifecycle service
  Future<void> initialize() async {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;

    // Start with foreground mode (app is open)
    await _handleAppForeground();

    debugPrint('✅ App lifecycle service initialized');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppForeground();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _handleAppBackground();
        break;
      case AppLifecycleState.hidden:
        // App is hidden but still running
        break;
    }
  }

  /// Handle app coming to foreground
  Future<void> _handleAppForeground() async {
    if (_isAppInForeground) return;

    _isAppInForeground = true;
    debugPrint(
        '📱 App moved to FOREGROUND - switching to foreground detection');

    try {
      // Stop background service (foreground will handle detection)
      await BackgroundService.stop();

      // Start foreground motion detection
      final motionService = MotionDetectionService();
      await motionService.startMonitoring();

      debugPrint('✅ Switched to foreground motion detection');
    } catch (e) {
      debugPrint('❌ Failed to switch to foreground detection: $e');
    }
  }

  /// Handle app going to background
  Future<void> _handleAppBackground() async {
    if (!_isAppInForeground) return;

    _isAppInForeground = false;
    debugPrint(
        '📱 App moved to BACKGROUND - switching to background detection');

    try {
      // Stop foreground motion detection
      final motionService = MotionDetectionService();
      await motionService.stopMonitoring();

      // Start background service
      await BackgroundService.start();

      debugPrint('✅ Switched to background motion detection');
    } catch (e) {
      debugPrint('❌ Failed to switch to background detection: $e');
    }
  }

  /// Get current app state
  bool get isAppInForeground => _isAppInForeground;

  /// Check if background service should be running
  Future<bool> shouldBackgroundServiceRun() async {
    return !_isAppInForeground;
  }

  /// Dispose resources
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isInitialized = false;
    debugPrint('🧹 App lifecycle service disposed');
  }
}
