// lib/models/user_profile.dart
class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? requestedRole;
  final String? departmentUnit;
  final bool isActive;
  final String approvalStatus;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? createdAt;

  // REMOVED const — DateTime fields can't be const
  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.requestedRole,
    this.departmentUnit,
    this.isActive = false,
    this.approvalStatus = 'pending',
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id:             json['id'] as String,
      fullName:       json['full_name'] as String? ?? '',
      email:          json['email'] as String? ?? '',
      role:           json['role'] as String? ?? 'Lecturer',
      requestedRole:  json['requested_role'] as String?,
      departmentUnit: json['department_unit'] as String?,
      isActive:       json['is_active'] as bool? ?? false,
      approvalStatus: json['approval_status'] as String? ?? 'pending',
      approvedBy:     json['approved_by'] as String?,
      approvedAt:     json['approved_at'] != null
                        ? DateTime.parse(json['approved_at'] as String)
                        : null,
      createdAt:      json['created_at'] != null
                        ? DateTime.parse(json['created_at'] as String)
                        : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':              id,
    'full_name':       fullName,
    'email':           email,
    'role':            role,
    'requested_role':  requestedRole,
    'department_unit': departmentUnit,
    'is_active':       isActive,
    'approval_status': approvalStatus,
    'approved_by':     approvedBy,
    'approved_at':     approvedAt?.toIso8601String(),
    'created_at':      createdAt?.toIso8601String(),
  };

  // ── Convenience getters ──────────────────────────────────────────────────
  bool get isPending  => approvalStatus == 'pending';
  bool get isApproved => approvalStatus == 'approved';
  bool get isRejected => approvalStatus == 'rejected';
  bool get isAdmin    => role == 'Admin';

  // ── Hierarchy helper ─────────────────────────────────────────────────────
  /// Returns true if THIS user has authority to approve [applicant].
  /// Rules:
  /// - Admin can approve anyone except other Admins (only existing Admin can approve Admin)
  /// - TPA can approve KJ, KP, Lecturer
  /// - KJ  can approve KP, Lecturer
  /// - KP  can approve Lecturer only
  /// - Lecturer cannot approve anyone
  bool canApprove(UserProfile applicant) {
    final target = applicant.requestedRole ?? applicant.role;
    switch (role) {
      case 'Admin':
        // Admin approves all non-Admin, AND can approve other Admin requests
        return true;
      case 'Timbalan Pengarah Akademik':
        return const ['Ketua Jabatan', 'Ketua Program', 'Lecturer']
            .contains(target);
      case 'Ketua Jabatan':
        return const ['Ketua Program', 'Lecturer'].contains(target);
      case 'Ketua Program':
        return target == 'Lecturer';
      default:
        return false;
    }
  }
}