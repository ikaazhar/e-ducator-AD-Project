import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/approval_request.dart';
import '../models/user_profile.dart';

class UserManagementService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Returns roles that [approverRole] is allowed to approve/manage.
  List<String> getAllowedRoles(String approverRole) {
    switch (approverRole) {
      case 'Admin':
        return [
          'Timbalan Pengarah Akademik',
          'Ketua Jabatan',
          'Ketua Program',
          'Lecturer',
        ];
      case 'Timbalan Pengarah Akademik':
        return ['Ketua Jabatan', 'Ketua Program', 'Lecturer'];
      case 'Ketua Jabatan':
        return ['Ketua Program', 'Lecturer'];
      case 'Ketua Program':
        return ['Lecturer'];
      default:
        return [];
    }
  }

  /// Fetch all pending users whose [requested_role] the approver can handle.
  Future<List<ApprovalRequest>> getPendingUsers(String approverRole) async {
    final allowed = getAllowedRoles(approverRole);
    if (allowed.isEmpty) return [];

    final rows = await _client
        .from('profiles')
        .select()
        .eq('approval_status', 'pending')
        .inFilter('requested_role', allowed)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((r) => ApprovalRequest.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Fetch all active users whose role the approver can manage.
  Future<List<UserProfile>> getActiveUsers(String approverRole) async {
    final allowed = getAllowedRoles(approverRole);
    if (allowed.isEmpty) return [];

    final rows = await _client
        .from('profiles')
        .select()
        .eq('is_active', true)
        .inFilter('role', allowed)
        .order('full_name', ascending: true);

    return (rows as List)
        .map((r) => UserProfile.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Approve a pending user — sets is_active, role, approval_status.
  Future<void> approveUser({
    required String userId,
    required String requestedRole,
    required String approverId,
  }) async {
    await _client.from('profiles').update({
      'is_active':       true,
      'role':            requestedRole,
      'approval_status': 'approved',
      'approved_by':     approverId,
      'approved_at':     DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Reject a pending user.
  Future<void> rejectUser({
    required String userId,
    required String approverId,
  }) async {
    await _client.from('profiles').update({
      'is_active':       false,
      'approval_status': 'rejected',
      'approved_by':     approverId,
      'approved_at':     DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Deactivate an already-active user.
  Future<void> deactivateUser(String userId) async {
    await _client.from('profiles').update({
      'is_active': false,
    }).eq('id', userId);
  }

  /// Reassign role of an active user (only if within approver's allowed roles).
  Future<void> reassignRole({
    required String userId,
    required String newRole,
    required String approverId,
  }) async {
    await _client.from('profiles').update({
      'role':        newRole,
      'approved_by': approverId,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }
}