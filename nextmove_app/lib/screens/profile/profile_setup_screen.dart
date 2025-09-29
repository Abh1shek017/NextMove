import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../services/auth_service.dart';
import '../auth/permissions_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String phoneNumber;

  const ProfileSetupScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _selectedAgeGroup;
  String? _selectedGender;
  String? _selectedOccupation;
  String? _selectedIncome;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAgeGroup == null ||
        _selectedGender == null ||
        _selectedOccupation == null ||
        _selectedIncome == null) {
      setState(() {
        _errorMessage = 'Please fill in all the required fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Complete profile setup with backend
      final success = await authService.completeProfile(
        phoneNumber: widget.phoneNumber,
        name: _nameController.text.trim(),
        ageGroup: _selectedAgeGroup!,
        gender: _selectedGender!,
        occupation: _selectedOccupation!,
        incomeGroup: _selectedIncome!,
      );

      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PermissionsScreen(),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Failed to save profile. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save profile: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding * 0.5,
                vertical: AppConstants.defaultPadding,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'Just a few details to get started',
                      style: AppTheme.headingLarge,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'This information helps NATPAC understand travel patterns better. Your data is completely anonymous.',
                      style:
                          AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Age Group
                    DropdownButtonFormField<String>(
                      value: _selectedAgeGroup,
                      decoration: const InputDecoration(
                        labelText: 'Age Group',
                        prefixIcon: Icon(Icons.cake_outlined),
                      ),
                      items: AppConstants.ageGroups.map((String ageGroup) {
                        return DropdownMenuItem<String>(
                          value: ageGroup,
                          child: Text(ageGroup),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedAgeGroup = newValue;
                          _errorMessage = null;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select your age group';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Gender
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: AppConstants.genders.map((String gender) {
                        return DropdownMenuItem<String>(
                          value: gender,
                          child: Text(gender),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedGender = newValue;
                          _errorMessage = null;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select your gender';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Occupation
                    DropdownButtonFormField<String>(
                      value: _selectedOccupation,
                      decoration: const InputDecoration(
                        labelText: 'Occupation',
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                      items: AppConstants.occupations.map((String occupation) {
                        return DropdownMenuItem<String>(
                          value: occupation,
                          child: Text(occupation),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedOccupation = newValue;
                          _errorMessage = null;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select your occupation';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Monthly Income
                    DropdownButtonFormField<String>(
                      value: _selectedIncome,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Household Income',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      items: AppConstants.monthlyIncomes.map((String income) {
                        return DropdownMenuItem<String>(
                          value: income,
                          child: Text(income),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedIncome = newValue;
                          _errorMessage = null;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select your income range';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

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
                                style:
                                    const TextStyle(color: AppTheme.errorRed),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Save & Continue button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSaveAndContinue,
                        child: _isLoading
                            ? const SpinKitThreeBounce(
                                color: Colors.white,
                                size: 20,
                              )
                            : const Text('Save & Continue'),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Privacy note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius:
                            BorderRadius.circular(AppConstants.borderRadius),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.security,
                            color: AppTheme.successGreen,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your Privacy Matters',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'All data is anonymized and used only for research purposes by NATPAC. Your personal information is never shared.',
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
          ),
        ));
  }
}
