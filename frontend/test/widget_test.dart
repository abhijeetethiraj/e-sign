import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/main.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Widget> createTestWidget() async {
    SharedPreferences.setMockInitialValues({});
    final authProvider = AuthProvider();
    await authProvider.init();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const ESignApp(),
    );
  }

  testWidgets('App renders StartWell reference welcome screen when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(await createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });

  testWidgets('Transitions to Register view on Sign Up tap', (WidgetTester tester) async {
    await tester.pumpWidget(await createTestWidget());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sign Up'));
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    // Expect Register View
    expect(find.text('Join eSign'), findsOneWidget);
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Last name'), findsOneWidget);
  });

  testWidgets('Empty identifier shows validation snackbar on continue', (WidgetTester tester) async {
    await tester.pumpWidget(await createTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Please enter your mobile number or email'), findsOneWidget);
  });
}
