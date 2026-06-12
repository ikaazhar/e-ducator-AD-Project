import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_profile.dart';

/// Akaun telah dinyahaktifkan oleh admin.
class AccountDeactivatedException implements Exception {
  final String message;
  AccountDeactivatedException([
    this.message = 'Akaun anda telah dinyahaktifkan. Sila hubungi Admin.',
  ]);
  @override
  String toString() => message;
}

/// Akaun baru, masih menunggu kelulusan.
class AccountPendingException implements Exception {
  final String message;
  AccountPendingException([
    this.message = 'Akaun anda sedang menunggu kelulusan. Sila tunggu.',
  ]);
  @override
  String toString() => message;
}

class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Log masuk pengguna.
  /// - Jika [approval_status] == 'pending'  → lempar [AccountPendingException]
  /// - Jika [is_active]       == false       → lempar [AccountDeactivatedException]
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    if (SupabaseConfig.isPlaceholder) return _mockSignIn(email);

    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Log masuk gagal. Sila semak kelayakan anda.');
    }

    final profileRow = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (profileRow == null) {
      await _client.auth.signOut();
      throw Exception('Profil pengguna tidak dijumpai.');
    }

    final profile = UserProfile.fromJson(profileRow);

    // Pending: registered but not yet approved
    if (profile.approvalStatus == 'pending') {
      await _client.auth.signOut();
      throw AccountPendingException();
    }

    // Rejected: was rejected by approver
    if (profile.approvalStatus == 'rejected') {
      await _client.auth.signOut();
      throw AccountDeactivatedException(
        'Permohonan akaun anda telah ditolak. Sila hubungi Admin.',
      );
    }

    // Approved but later deactivated by admin
    if (!profile.isActive) {
      await _client.auth.signOut();
      throw AccountDeactivatedException();
    }

    return profile;
  }

  /// Daftar pengguna baru.
  /// Trigger `handle_new_user` akan mencipta profil dengan
  /// [is_active=false] dan [approval_status='pending'].
  Future<UserProfile> signUp({
    required String fullName,
    required String email,
    required String password,
    required String requestedRole,
    required String departmentUnit,
  }) async {
    if (SupabaseConfig.isPlaceholder) {
      return UserProfile(
        id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
        fullName: fullName,
        email: email,
        role: 'Lecturer',           // placeholder until approved
        requestedRole: requestedRole,
        departmentUnit: departmentUnit,
        isActive: false,
        approvalStatus: 'pending',
      );
    }

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': requestedRole,          // used by handle_new_user trigger
        'requested_role': requestedRole,
        'department_unit': departmentUnit,
      },
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Pendaftaran gagal. Sila cuba semula.');
    }

    // Read back the profile row created by the trigger
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    return UserProfile.fromJson(row);
  }

  /// Log keluar.
  Future<void> signOut() async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client.auth.signOut();
  }

  // ─── Mock fallback ───────────────────────────────────────────────────────
  UserProfile _mockSignIn(String email) {
    final lower = email.toLowerCase();
    String role = 'Lecturer';
    if (lower.contains('admin'))      role = 'Admin';
    else if (lower.contains('tpa'))   role = 'Timbalan Pengarah Akademik';
    else if (lower.contains('kj'))    role = 'Ketua Jabatan';
    else if (lower.contains('kp'))    role = 'Ketua Program';

    return UserProfile(
      id: 'mock-user-id',
      fullName: 'Pengguna Demo',
      email: email,
      role: role,
      requestedRole: role,
      departmentUnit: 'DGS',
      isActive: true,
      approvalStatus: 'approved',
    );
  }
}