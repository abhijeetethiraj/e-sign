import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/main.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App renders login screen when unauthenticated', (WidgetTester tester) async {
    // Provide empty mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    final authProvider = AuthProvider();
    await authProvider.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const ESignApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify eSign branding text
    expect(find.text('Continue with SSO'), findsOneWidget);
  });
}
