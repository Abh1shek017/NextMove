// lib/models/user.dart
class User {
  final String phone;
  final String? name;
  final String? ageGroup;
  final String? gender;
  final String? occupation;
  final String? incomeGroup;

  User({
    required this.phone,
    this.name,
    this.ageGroup,
    this.gender,
    this.occupation,
    this.incomeGroup,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      phone: json['phone_number'],
      name: json['name'],
      ageGroup: json['age_group'],
      gender: json['gender'],
      occupation: json['occupation'],
      incomeGroup: json['income_group'],
    );
  }
}