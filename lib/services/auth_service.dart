import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_profile.dart';
import 'notification_service.dart';

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

/// Ralat semasa proses set semula kata laluan.
class PasswordResetException implements Exception {
  final String message;
  PasswordResetException(this.message);
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

    // NEW: check for booking reminders (fire-and-forget, non-blocking)
    NotificationService().checkAndCreateBookingReminders(user.id);

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

  /// Hantar kod pengesahan ke e-mel pengguna untuk set semula kata laluan.
  Future<void> sendPasswordResetCode(String email) async {
    if (SupabaseConfig.isPlaceholder) return;
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw PasswordResetException(_mapResetError(e));
    }
  }

  /// Sahkan kod OTP, tetapkan kata laluan baru, kemudian log keluar.
  Future<void> verifyResetCodeAndUpdatePassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (SupabaseConfig.isPlaceholder) return;
    try {
      await _client.auth.verifyOTP(
        type: OtpType.recovery,
        email: email,
        token: code,
      );
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw PasswordResetException(_mapResetError(e));
    } finally {
      // Buang sesi pemulihan walau apa pun berlaku supaya pengguna
      // log masuk semula dengan kata laluan baru.
      if (_client.auth.currentSession != null) {
        await _client.auth.signOut();
      }
    }
  }

  String _mapResetError(AuthException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (code == 'otp_expired' || msg.contains('expired')) {
      return 'Kod telah tamat tempoh atau tidak sah. Sila minta kod baru.';
    }
    if (code == 'over_email_send_rate_limit' ||
        e.statusCode == '429' ||
        msg.contains('rate limit')) {
      return 'Terlalu banyak percubaan. Sila tunggu beberapa minit sebelum cuba lagi.';
    }
    if (code == 'same_password') {
      return 'Kata laluan baru mestilah berbeza daripada kata laluan lama.';
    }
    if (code == 'weak_password' || msg.contains('password')) {
      return 'Kata laluan terlalu lemah. Gunakan sekurang-kurangnya 6 aksara.';
    }
    if (msg.contains('token') || msg.contains('invalid')) {
      return 'Kod tidak sah. Sila semak semula kod dari e-mel anda.';
    }
    return 'Ralat: ${e.message}';
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