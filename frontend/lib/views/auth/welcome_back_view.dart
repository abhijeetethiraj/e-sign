import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/auth/onesso_button.dart';
import '../../widgets/auth/onesso_phone_field.dart';

/// Screen 1: Welcome / Identifier Entry (Matches StartWell UX flow with existing eSign/OneSSO theme)
class WelcomeBackView extends StatelessWidget {
  final TextEditingController phoneController;
  final ValueChanged<String> onContinue;
  final VoidCallback onGoToRegister;
  final bool isLoading;
  final bool isUnregistered;

  const WelcomeBackView({
    super.key,
    required this.phoneController,
    required this.onContinue,
    required this.onGoToRegister,
    this.isLoading = false,
    this.isUnregistered = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary; // Existing brand theme
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: titleColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Use your email or mobile number to continue.',
          style: TextStyle(fontSize: 14, color: subtitleColor),
        ),
        const SizedBox(height: 28),

        // Mobile / Email input field
        OneSsoPhoneField(
          controller: phoneController,
          label: 'Mobile / Email',
          hintText: 'Enter mobile or email',
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) onContinue(val.trim());
          },
        ),
        const SizedBox(height: 20),

        // Dynamic Action Button (Continue or Register if not registered yet, or Checking...)
        OneSsoButton(
          label: isLoading ? 'Checking...' : (isUnregistered ? 'Register' : 'Continue'),
          trailing: isLoading ? null : const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
          isLoading: isLoading,
          onPressed: () {
            final text = phoneController.text.trim();
            if (text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter your mobile number or email')),
              );
              return;
            }
            if (isUnregistered) {
              onGoToRegister();
            } else {
              onContinue(text);
            }
          },
        ),
        const SizedBox(height: 24),

        // Bottom Toggle to Register
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(fontSize: 13, color: subtitleColor),
              ),
              GestureDetector(
                onTap: onGoToRegister,
                child: Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
