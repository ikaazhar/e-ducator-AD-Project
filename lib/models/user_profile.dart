// lib/models/user_profile.dart
//
// Model profil pengguna E-ducator. Memetakan jadual `public.profiles`.
class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? departmentUnit;
  final bool isActive;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.departmentUnit,
    this.isActive = true,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: (json['full_name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      role: (json['role'] ?? 'Lecturer') as String,
      departmentUnit: json['department_unit'] as String?,
      isActive: (json['is_active'] ?? true) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'role': role,
        'department_unit': departmentUnit,
        'is_active': isActive,
      };

  UserProfile copyWith({
    String? fullName,
    String? role,
    String? departmentUnit,
    bool? isActive,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      role: role ?? this.role,
      departmentUnit: departmentUnit ?? this.departmentUnit,
      isActive: isActive ?? this.isActive,
    );
  }
}
