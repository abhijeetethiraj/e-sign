import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

/// Reusable OneSSO header with logo, optional back button, and theme icon.
class OneSsoHeader extends StatelessWidget {
  final VoidCallback? onBack;
  final bool showBack;

  const OneSsoHeader({
    super.key,
    this.onBack,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final backIconColor = isDark ? Colors.white70 : const Color(0xFF334155);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Optional Back Button
          if (showBack)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, size: 18, color: backIconColor),
                onPressed: onBack,
                tooltip: 'Back',
              ),
            ),

          // OneSSO Centered Logo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE52535),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'one',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const TextSpan(
                      text: 'sso',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE52535),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Theme toggle icon on right
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              onPressed: () {
                try {
                  context.read<ThemeProvider>().toggleTheme();
                } catch (_) {}
              },
            ),
          ),
        ],
      ),
    );
  }
}
