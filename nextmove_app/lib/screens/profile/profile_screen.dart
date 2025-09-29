import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_settings/app_settings.dart';
import '../../utils/constants.dart';
import '../../services/auth_service.dart';

class ProfileTabScreen extends StatefulWidget {
  const ProfileTabScreen({super.key});

  @override
  State<ProfileTabScreen> createState() => _ProfileTabScreenState();
}

class _ProfileTabScreenState extends State<ProfileTabScreen> {
  bool _notificationsEnabled = true;
  bool _wifiOnlyUpload = false;

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
        title: const Text('Profile'),
        centerTitle: true,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue[50]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            children: [
              // Profile header
              Consumer<AuthService>(
                builder: (context, authService, child) {
                  final user = authService.currentUser;
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade700, Colors.green.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      image: const DecorationImage(
                        image: AssetImage(
                            "assets/images/leaf_bg.png"), // 🌿 leafy pattern
                        fit: BoxFit.cover,
                        opacity: 0.12,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          child: Text(
                            user?.fullName?.isNotEmpty == true
                                ? user!.fullName![0].toUpperCase()
                                : user?.phoneNumber.isNotEmpty == true
                                    ? user!.phoneNumber[0]
                                    : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName ?? 'User',
                                style: AppTheme.headingMedium.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.phoneNumber ?? 'Unknown',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'NextMove User',
                                  style: AppTheme.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // User Info Section
              _buildSectionCard(
                'User Information',
                [
                  _buildMenuItem(
                    icon: Icons.edit,
                    title: 'Edit Profile',
                    subtitle: 'Update your demographic information',
                    onTap: () => _showEditProfileDialog(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // App Settings Section
              _buildSectionCard(
                'App Settings',
                [
                  _buildSwitchMenuItem(
                    icon: Icons.notifications_active,
                    title: 'Notifications',
                    subtitle: 'Receive trip confirmation reminders',
                    value: _notificationsEnabled,
                    onChanged: (value) =>
                        setState(() => _notificationsEnabled = value),
                  ),
                  _buildMenuItem(
                    icon: Icons.security,
                    title: 'Manage Permissions',
                    subtitle: 'Location, notifications, and activity access',
                    onTap: () => AppSettings.openAppSettings(),
                  ),
                  _buildSwitchMenuItem(
                    icon: Icons.wifi,
                    title: 'Upload on Wi-Fi Only',
                    subtitle: 'Save mobile data usage',
                    value: _wifiOnlyUpload,
                    onChanged: (value) =>
                        setState(() => _wifiOnlyUpload = value),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Help & Support Section
              _buildSectionCard(
                'Help & Support',
                [
                  _buildMenuItem(
                    icon: Icons.help_outline,
                    title: 'FAQ',
                    subtitle: 'Frequently asked questions',
                    onTap: () => _showFAQDialog(context),
                  ),
                  _buildMenuItem(
                    icon: Icons.feedback_outlined,
                    title: 'Send Feedback',
                    subtitle: 'Help us improve NextMove',
                    onTap: () => _showFeedbackDialog(context),
                  ),
                  _buildMenuItem(
                    icon: Icons.info_outline,
                    title: 'About NextMove',
                    subtitle: 'Version info and credits',
                    onTap: () => _showAboutDialog(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Account Section
              _buildSectionCard(
                'Account',
                [
                  _buildMenuItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of your account',
                    onTap: () => _showLogoutConfirmation(context),
                    textColor: AppTheme.warningOrange,
                  ),
                  _buildMenuItem(
                    icon: Icons.delete_forever,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account and data',
                    onTap: () => _showDeleteAccountConfirmation(context),
                    textColor: AppTheme.errorRed,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Footer
              Column(
                children: [
                  const Text(
                    'NextMove v1.0.0\nDeveloped for NATPAC',
                    style: AppTheme.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🌴 Designed with love in Kerala',
                    style: AppTheme.caption.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppTheme.successGreen,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---
  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.primaryBlue,
                )),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
        child: Icon(icon, color: textColor ?? AppTheme.primaryBlue),
      ),
      title: Text(
        title,
        style: AppTheme.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor ?? Colors.black,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSwitchMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.successGreen.withOpacity(0.1),
        child: Icon(icon, color: AppTheme.successGreen),
      ),
      title: Text(
        title,
        style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.successGreen,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  // --- Dialog Functions ---

  void _showEditProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        title: const Text('Edit Profile'),
        content: const Text('Profile editing feature will be available soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFAQDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        title: const Text('Frequently Asked Questions'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFAQItem(
                'How does NextMove detect trips?',
                'NextMove uses your phone\'s GPS and motion sensors to automatically detect when you start and stop traveling.',
              ),
              const SizedBox(height: 12),
              _buildFAQItem(
                'Is my location data secure?',
                'Yes, all location data is encrypted and stored securely. We only collect data when you confirm a trip.',
              ),
              const SizedBox(height: 12),
              _buildFAQItem(
                'Can I edit trip details?',
                'Yes, you can edit trip details like mode, purpose, and cost within 24 hours of completing a trip.',
              ),
              const SizedBox(height: 12),
              _buildFAQItem(
                'How accurate is the transport mode prediction?',
                'Our AI model is trained on real user data and achieves high accuracy. You can always correct the prediction.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          answer,
          style: AppTheme.caption,
        ),
      ],
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        title: const Text('Send Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Help us improve NextMove by sharing your feedback:'),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter your feedback here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (feedbackController.text.trim().isNotEmpty) {
                // TODO: Implement feedback submission
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for your feedback!'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'NextMove',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.directions,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        const Text(
          'NextMove is a smart transportation tracking app developed for NATPAC (National Transportation Planning and Research Centre).',
        ),
        const SizedBox(height: 16),
        const Text(
          'Features:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const Text('• Automatic trip detection'),
        const Text('• AI-powered transport mode prediction'),
        const Text('• Comprehensive trip analytics'),
        const Text('• Privacy-focused data collection'),
        const SizedBox(height: 16),
        const Text(
          'Developed with ❤️ in Kerala, India',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performLogout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        title: const Text('Delete Account'),
        content: const Text(
          'This action cannot be undone. All your trip data and account information will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performDeleteAccount(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _performLogout(BuildContext context) async {
    try {
      // TODO: Implement logout logic with AuthService
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();

      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _performDeleteAccount(BuildContext context) async {
    try {
      // TODO: Implement delete account logic
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deletion feature coming soon'),
            backgroundColor: AppTheme.warningOrange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete account failed: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }
}
