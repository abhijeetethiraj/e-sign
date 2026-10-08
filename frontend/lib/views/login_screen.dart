import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'documents_screen.dart';

/// Screen initiating the Keycloak OIDC Authorization Code Flow.
/// The user is redirected to Keycloak, which owns the authentication UI.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _continueWithSso() async {
    final authProvider = context.read<AuthProvider>();
    final launched = await authProvider.initiateSsoLogin();

    if (!mounted) return;

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Could not launch Keycloak browser'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  /// Helper modal allowing developers to manually simulate/paste session callback for testing
  void _showManualSessionDialog() {
    final tokenController = TextEditingController();
    final emailController = TextEditingController(text: 'alex.morgan@company.com');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dev Callback Simulator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Once Keycloak redirects to http://13.234.29.32/auth/oidc/callback/, you can set the session here for testing:',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'User Email', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(labelText: 'Session Token / ID', hintText: 'sess_...', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              await auth.completeSsoSession(
                sessionToken: tokenController.text.trim().isEmpty ? 'mock_session_token' : tokenController.text.trim(),
                userId: 'usr_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                email: emailController.text.trim(),
              );
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => DocumentsScreen(userSession: auth.userSession)),
                );
              }
            },
            child: const Text('Set Session'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 12,
              right: 16,
              child: Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  final bool isDark = themeProvider.isDarkMode;
                  return IconButton(
                    tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    icon: Icon(
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: AppTheme.textPrimary(context),
                    ),
                    onPressed: () => themeProvider.toggleTheme(),
                  );
                },
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // eSign Brand Icon
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.draw_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title & Subtitle
                Text(
                  'eSign',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary(context),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Electronic Signature Platform',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 48),

                // Primary SSO Action Button
                ElevatedButton.icon(
                  onPressed: authProvider.isLoading ? null : _continueWithSso,
                  icon: authProvider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.lock_outline_rounded, size: 20),
                  label: const Text(
                    'Continue with SSO',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),

                const SizedBox(height: 28),

                // OIDC Architecture Information Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderColor(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 18, color: AppTheme.primaryBlue),
                          const SizedBox(width: 8),
                          Text(
                            'Single Sign-On (SSO)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You will be securely redirected to authenticate. '
                        'eSign never sees or stores your credentials.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary(context),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryBg(context),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OIDC Authorization Code + PKCE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // Dev Callback Trigger
                Center(
                  child: TextButton.icon(
                    onPressed: _showManualSessionDialog,
                    icon: Icon(Icons.developer_mode_rounded, size: 16, color: AppTheme.textSecondary(context)),
                    label: Text(
                      'Dev: Simulate Callback',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);
  }
}
