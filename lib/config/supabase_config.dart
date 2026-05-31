// lib/config/supabase_config.dart
//
// Konfigurasi Supabase. Gantikan nilai placeholder dengan kredensial
// projek anda sebelum pembinaan akhir.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mxeijsslcwpeexflabmj.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_7FuKnLwybm0e_wmAL_IFnQ_ll146CF6',
  );

  /// `true` jika kredensial Supabase belum ditetapkan.
  /// Apabila `true`, lapisan perkhidmatan akan menggunakan data palsu (mock).
  static bool get isPlaceholder =>
      url.contains('YOUR-PROJECT') || anonKey.contains('YOUR-ANON-KEY');
}
