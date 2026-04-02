class AppConfig {
  const AppConfig._();

  static const _defaultSupabaseUrl = 'https://msziutqvkrbwwohcdoou.supabase.co';
  static const _defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zeml1dHF2a3Jid3dvaGNkb291Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE2ODUxOTEsImV4cCI6MjA4NzI2MTE5MX0.zsjHAtY2OAR1CwXWMep45qeU3YyHbw7-RX-aPyChC5Y';
  static const _envSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _envSupabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _envInvoiceRenderServiceUrl =
      String.fromEnvironment('INVOICE_RENDER_SERVICE_URL');

  // Empty --dart-define values should not disable the built-in fallback config.
  static String get supabaseUrl {
    final value = _envSupabaseUrl.trim();
    return value.isNotEmpty ? value : _defaultSupabaseUrl;
  }

  static String get supabaseAnonKey {
    final value = _envSupabaseAnonKey.trim();
    return value.isNotEmpty ? value : _defaultSupabaseAnonKey;
  }

  static bool get hasSupabase =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static String get invoiceRenderServiceUrl =>
      _envInvoiceRenderServiceUrl.trim();

  static bool get hasInvoiceRenderService =>
      invoiceRenderServiceUrl.isNotEmpty;
}
