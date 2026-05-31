// lib/providers/user_provider.dart
//
// Penyedia keadaan sesi pengguna global (ChangeNotifier).
// Disediakan di puncak pokok widget supaya semua skrin boleh akses sesi semasa.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/user_profile.dart';

class UserProvider extends ChangeNotifier {
  UserProfile? _profile;
  bool _isLoading = false;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _profile != null;

  void setProfile(UserProfile? profile) {
    _profile = profile;
    notifyListeners();
  }

  /// Muat semula profil daripada Supabase berdasarkan sesi auth semasa.
  Future<void> loadProfile() async {
    if (SupabaseConfig.isPlaceholder) return;
    final auth = Supabase.instance.client.auth.currentUser;
    if (auth == null) {
      _profile = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', auth.id)
          .maybeSingle();
      if (data != null) {
        _profile = UserProfile.fromJson(data);
      }
    } catch (e) {
      debugPrint('UserProvider.loadProfile error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Kosongkan sesi tempatan. Pemanggil bertanggungjawab untuk panggil signOut().
  void clearSession() {
    _profile = null;
    notifyListeners();
  }
}
