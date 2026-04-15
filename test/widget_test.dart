import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cvant_mobile/app.dart';
import 'package:cvant_mobile/core/i18n/language_controller.dart';
import 'package:cvant_mobile/core/theme/theme_controller.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
          '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV4YW1wbGUiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTUxNjIzOTAyMn0'
          '.c2lnbmF0dXJl',
    );
    await ThemeController.init();
    await LanguageController.init();
  });

  testWidgets('shows startup error screen safely when startupError is provided',
      (tester) async {
    await tester.pumpWidget(const CvantApp(startupError: 'DB timeout'));
    await tester.pumpAndSettle();

    expect(find.text('Aplikasi gagal dibuka'), findsOneWidget);
    expect(
      find.textContaining('Terjadi masalah saat inisialisasi aplikasi'),
      findsOneWidget,
    );
    expect(find.text('DB timeout'), findsOneWidget);
  });
}
