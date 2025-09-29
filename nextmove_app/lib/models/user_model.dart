class User {
  final String phoneNumber;
  final String? userId;
  final String? fullName;
  final String? ageGroup;
  final String? gender;
  final String? occupation;
  final String? monthlyIncome;

  User({
    required this.phoneNumber,
    this.userId,
    this.fullName,
    this.ageGroup,
    this.gender,
    this.occupation,
    this.monthlyIncome,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      phoneNumber: json['phone_number'] ?? '',
      userId: json['user_id']?.toString(),
      fullName: json['full_name'],
      ageGroup: json['age_group'],
      gender: json['gender'],
      occupation: json['occupation'],
      monthlyIncome: json['monthly_income'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone_number': phoneNumber,
      if (userId != null) 'user_id': userId,
      if (fullName != null) 'full_name': fullName,
      if (ageGroup != null) 'age_group': ageGroup,
      if (gender != null) 'gender': gender,
      if (occupation != null) 'occupation': occupation,
      if (monthlyIncome != null) 'monthly_income': monthlyIncome,
    };
  }

  User copyWith({
    String? phoneNumber,
    String? userId,
    String? fullName,
    String? ageGroup,
    String? gender,
    String? occupation,
    String? monthlyIncome,
  }) {
    return User(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      ageGroup: ageGroup ?? this.ageGroup,
      gender: gender ?? this.gender,
      occupation: occupation ?? this.occupation,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
    );
  }
}
