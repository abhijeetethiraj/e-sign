import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/theme_provider.dart';
import 'package:frontend/views/documents_screen.dart';
import 'package:frontend/views/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
      ],
      child: const ESignApp(),
    ),
  );
}

class ESignApp extends StatelessWidget {
  const ESignApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeMode mode = ThemeMode.light;
    try {
      mode = context.watch<ThemeProvider>().themeMode;
    } catch (_) {
      // Graceful fallback if ThemeProvider is not provided in a test harness
    }

    return MaterialApp(
      title: 'eSign',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
          home: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              // While restoring persisted session from SharedPreferences
              if (!auth.isInitialized) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // If valid session exists in SharedPreferences, open DocumentsScreen
              if (auth.isAuthenticated) {
                return DocumentsScreen(userSession: auth.userSession);
              }

              // Otherwise prompt user to Login
              return const LoginScreen();
            },
          ),
        );
  }
}
