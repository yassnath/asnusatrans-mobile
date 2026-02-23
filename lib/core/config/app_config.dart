class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://msziutqvkrbwwohcdoou.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zeml1dHF2a3Jid3dvaGNkb291Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE2ODUxOTEsImV4cCI6MjA4NzI2MTE5MX0.zsjHAtY2OAR1CwXWMep45qeU3YyHbw7-RX-aPyChC5Y',
  );

  static bool get hasSupabase =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}
