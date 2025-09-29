import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../utils/constants.dart';
import '../../services/auth_service.dart';
import '../profile/profile_setup_screen.dart';
import '../home/main_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  int _resendTimer = 30;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _canResend = false;
    _resendTimer = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _handleVerify() async {
    if (_otpController.text.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Verify OTP with backend
      final success = await authService.verifyOtp(
        widget.phoneNumber,
        _otpController.text,
      );

      if (success) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        }
      } else {
        // New user - go to profile setup
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ProfileSetupScreen(
                phoneNumber: widget.phoneNumber,
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid OTP. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (!_canResend) return;

    setState(() {
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Resend OTP using AuthService
      final success = await authService.sendOtp(widget.phoneNumber);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP sent successfully'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to resend OTP. Please try again.'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend OTP: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }

    _startResendTimer();
  }

  String _formatPhoneNumber(String phoneNumber) {
    // Format +919876543210 to +91 98765 43210
    if (phoneNumber.startsWith('+91')) {
      final number = phoneNumber.substring(3);
      if (number.length == 10) {
        return '+91 ${number.substring(0, 5)} ${number.substring(5)}';
      }
    }
    return phoneNumber;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // Title
              const Text(
                'Verify Your Number',
                style: AppTheme.headingLarge,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Instruction text
              Text(
                'Enter the 6-digit OTP sent to\n${_formatPhoneNumber(widget.phoneNumber)}',
                style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // OTP input
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: _otpController,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadius),
                  fieldHeight: 56,
                  fieldWidth: 48,
                  activeFillColor: Colors.white,
                  inactiveFillColor: Colors.white,
                  selectedFillColor: Colors.white,
                  activeColor: AppTheme.primaryBlue,
                  inactiveColor: Colors.grey[300]!,
                  selectedColor: AppTheme.primaryBlue,
                ),
                enableActiveFill: true,
                onCompleted: (value) {
                  // Auto-verify when 6 digits are entered
                  _handleVerify();
                },
                onChanged: (value) {
                  setState(() {
                    _errorMessage = null;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppConstants.borderRadius),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.errorRed, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.errorRed),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Verify button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerify,
                  child: _isLoading
                      ? const SpinKitThreeBounce(
                          color: Colors.white,
                          size: 20,
                        )
                      : const Text('Verify'),
                ),
              ),

              const SizedBox(height: 24),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive the code? ",
                    style: AppTheme.bodyMedium,
                  ),
                  if (_canResend)
                    GestureDetector(
                      onTap: _handleResendOtp,
                      child: Text(
                        'Resend OTP',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Text(
                      'Resend OTP in ${_resendTimer}s',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),

              const Spacer(),

              // Help text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadius),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Having trouble receiving the OTP?',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Make sure you have good network coverage and try again.',
                      style: AppTheme.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
