class ApprovalRequest {
  final String id;
  final String fullName;
  final String email;
  final String requestedRole;
  final String? departmentUnit;
  final String approvalStatus;
  final DateTime? createdAt;

  ApprovalRequest({
    required this.id,
    required this.fullName,
    required this.email,
    required this.requestedRole,
    this.departmentUnit,
    this.approvalStatus = 'pending',
    this.createdAt,
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(
      id:             json['id'] as String,
      fullName:       json['full_name'] as String? ?? '',
      email:          json['email'] as String? ?? '',
      requestedRole:  json['requested_role'] as String? ?? '',
      departmentUnit: json['department_unit'] as String?,
      approvalStatus: json['approval_status'] as String? ?? 'pending',
      createdAt:      json['created_at'] != null
                        ? DateTime.parse(json['created_at'] as String)
                        : null,
    );
  }
}