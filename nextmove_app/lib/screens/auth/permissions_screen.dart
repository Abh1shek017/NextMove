import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';
import '../home/main_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  int _currentStep = 0;
  bool _isProcessing = false;

  final List<PermissionStep> _permissionSteps = [
    PermissionStep(
      title: 'Terms & Conditions',
      description:
          'Welcome! To get started, please review our Terms of Service and Privacy Policy.',
      buttonText: 'I Understand & Agree',
      icon: Icons.description,
      isTerms: true,
    ),
    PermissionStep(
      title: 'Location Access',
      description:
          'To detect trips automatically, please set location access to "Allow all the time".',
      buttonText: 'Grant Permission',
      icon: Icons.location_on,
      permission: Permission.location,
    ),
    PermissionStep(
      title: 'Background Location',
      description:
          'To track trips even when the app is in background, please enable background location.',
      buttonText: 'Grant Permission',
      icon: Icons.location_searching,
      permission: Permission.locationAlways,
    ),
    PermissionStep(
      title: 'Motion & Fitness Activity',
      description:
          'To help guess your travel mode, please allow Motion & Fitness Activity access.',
      buttonText: 'Grant Permission',
      icon: Icons.directions_run,
      permission: Permission.activityRecognition,
    ),
    PermissionStep(
      title: 'Notifications',
      description:
          'We\'ll send you reminders to confirm your trips. Please allow notifications.',
      buttonText: 'Grant Permission',
      icon: Icons.notifications,
      permission: Permission.notification,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryBlue, AppTheme.successGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.directions_car_rounded,
              color: Colors.white,
              size: 28,
            ),
            SizedBox(width: 8),
            Text("NextMove",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue[50]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _currentStep < _permissionSteps.length
              ? _buildPermissionStep(_permissionSteps[_currentStep])
              : _buildCompletionScreen(),
        ),
      ),
    );
  }

  Widget _buildPermissionStep(PermissionStep step) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding * 2),
      child: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentStep + 1) / _permissionSteps.length,
            backgroundColor: Colors.grey[300],
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
          ),

          const SizedBox(height: 20),

          Text(
            'Step ${_currentStep + 1} of ${_permissionSteps.length}',
            style: AppTheme.caption,
          ),

          const Spacer(),

          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              step.icon,
              size: 60,
              color: AppTheme.primaryBlue,
            ),
          ),

          const SizedBox(height: 32),

          // Title
          Text(
            step.title,
            style: AppTheme.headingLarge,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            step.description,
            style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),

          const Spacer(),

          // Action button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed:
                  _isProcessing ? null : () => _handlePermissionStep(step),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(step.buttonText),
            ),
          ),

          const SizedBox(height: 16),

          // Skip button (only for permission steps, not terms)
          if (!step.isTerms)
            TextButton(
              onPressed: _isProcessing ? null : _skipCurrentStep,
              child: Text(
                'Skip for now',
                style: AppTheme.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding * 2),
      child: Column(
        children: [
          const Spacer(),

          // Success icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 60,
              color: AppTheme.successGreen,
            ),
          ),

          const SizedBox(height: 32),

          // Title
          const Text(
            'All Set!',
            style: AppTheme.headingLarge,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            'NextMove is ready to start tracking your trips automatically. You can always change these permissions later in Settings.',
            style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),

          const Spacer(),

          // Continue button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _navigateToMainScreen,
              child: const Text('Start Using NextMove'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePermissionStep(PermissionStep step) async {
    setState(() {
      _isProcessing = true;
    });

    if (step.isTerms) {
      // Just move to next step for terms
      await Future.delayed(const Duration(milliseconds: 500));
      _nextStep();
    } else if (step.permission != null) {
      // Request permission
      final status = await step.permission!.request();

      if (status.isGranted) {
        _showSuccessMessage('Permission granted successfully!');
      } else if (status.isDenied) {
        _showWarningMessage(
            'Permission denied. You can enable it later in Settings.');
      } else if (status.isPermanentlyDenied) {
        _showWarningMessage(
            'Permission permanently denied. Please enable it in Settings.');
      }

      await Future.delayed(const Duration(seconds: 1));
      _nextStep();
    }

    setState(() {
      _isProcessing = false;
    });
  }

  void _skipCurrentStep() {
    _showWarningMessage('You can enable this permission later in Settings.');
    _nextStep();
  }

  void _nextStep() {
    setState(() {
      _currentStep++;
    });
  }

  Future<void> _navigateToMainScreen() async {
    // Mark permissions as completed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyHasGrantedPermissions, true);

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (route) => false,
      );
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showWarningMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.warningOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class PermissionStep {
  final String title;
  final String description;
  final String buttonText;
  final IconData icon;
  final Permission? permission;
  final bool isTerms;

  PermissionStep({
    required this.title,
    required this.description,
    required this.buttonText,
    required this.icon,
    this.permission,
    this.isTerms = false,
  });
}
