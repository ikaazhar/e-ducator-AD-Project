// lib/services/auth_service.dart
//
// Perkhidmatan pengesahan (authentication). Lapisan ini ASING dari UI.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/user_profile.dart';

/// Pengecualian khas apabila akaun dinyahaktifkan.
class AccountDeactivatedException implements Exception {
  final String message;
  AccountDeactivatedException([
    this.message = 'Akaun anda telah dinyahaktifkan. Sila hubungi Admin.',
  ]);

  @override
  String toString() => message;
}

class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Log masuk pengguna. Selepas berjaya, ambil profil dan SAH guard `is_active`.
  ///
  /// GUARD KRITIKAL: jika `is_active == false`, panggil signOut() serta-merta
  /// dan lemparkan [AccountDeactivatedException].
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    if (SupabaseConfig.isPlaceholder) {
      // Mode mock untuk pembangunan tempatan tanpa kredensial.
      return _mockSignIn(email);
    }

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

    if (!profile.isActive) {
      await _client.auth.signOut();
      throw AccountDeactivatedException();
    }

    return profile;
  }

  /// Daftar pengguna baru, kemudian masukkan rekod profil.
  Future<UserProfile> signUp({
  required String fullName,
  required String email,
  required String password,
  required String role,
  required String departmentUnit,
}) async {
  if (SupabaseConfig.isPlaceholder) {
    return UserProfile(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      email: email,
      role: role,
      departmentUnit: departmentUnit,
    );
  }

  final response = await _client.auth.signUp(
    email: email,
    password: password,
    data: {
      'full_name': fullName,
      'role': role,
      'department_unit': departmentUnit,
    },
  );
  final user = response.user;
  if (user == null) {
    throw Exception('Pendaftaran gagal. Sila cuba semula.');
  }

  // Trigger sudah mencipta baris profil daripada metadata.
  // Hanya baca semula untuk dikembalikan.
  final row = await _client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .single();
  return UserProfile.fromJson(row);
}

  /// Log keluar dan kosongkan sesi.
  Future<void> signOut() async {
    if (SupabaseConfig.isPlaceholder) return;
    await _client.auth.signOut();
  }

  // ---------------- Mock fallback ----------------
  UserProfile _mockSignIn(String email) {
    final lower = email.toLowerCase();
    String role = 'Lecturer';
    if (lower.contains('admin')) {
      role = 'Admin';
    } else if (lower.contains('tpa')) {
      role = 'Timbalan Pengarah Akademik';
    } else if (lower.contains('kj')) {
      role = 'Ketua Jabatan';
    } else if (lower.contains('kp')) {
      role = 'Ketua Program';
    }
    return UserProfile(
      id: 'mock-user-id',
      fullName: 'Pengguna Demo',
      email: email,
      role: role,
      departmentUnit: 'DGS',
    );
  }
}
