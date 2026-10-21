import 'package:flutter/material.dart';
import '../../widgets/auth/onesso_button.dart';
import '../../widgets/auth/onesso_text_field.dart';

/// Screen 2: Native Password Entry (Zero browser redirect)
class PasswordView extends StatelessWidget {
  final String identifier;
  final TextEditingController passwordController;
  final ValueChanged<String> onSignIn;
  final VoidCallback onSendSmsCodeInstead;
  final VoidCallback onForgotPassword;
  final VoidCallback onBackToPhone;
  final bool isLoading;

  const PasswordView({
    super.key,
    required this.identifier,
    required this.passwordController,
    required this.onSignIn,
    required this.onSendSmsCodeInstead,
    required this.onForgotPassword,
    required this.onBackToPhone,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final chipBg = isDark ? const Color(0xFF1F1F24) : const Color(0xFFF1F5F9);
    final chipBorder = isDark ? const Color(0xFF2C2C32) : const Color(0xFFE2E8F0);
    final chipText = isDark ? Colors.white : const Color(0xFF0F172A);
    final chipIcon = isDark ? Colors.white70 : const Color(0xFF64748B);
    final linkColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter password',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: titleColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),

        // Identifier chip with edit button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: chipBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_circle_outlined, size: 16, color: chipIcon),
              const SizedBox(width: 8),
              Text(
                identifier,
                style: TextStyle(color: chipText, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onBackToPhone,
                child: const Text(
                  'Change',
                  style: TextStyle(color: Color(0xFFE52535), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Password input field
        OneSsoTextField(
          label: 'Password',
          hintText: 'Enter your account password',
          controller: passwordController,
          isPassword: true,
          autofocus: true,
          prefixIcon: Icon(Icons.lock_outline, color: chipIcon, size: 20),
          onSubmitted: (val) {
            if (val.isNotEmpty) onSignIn(val);
          },
        ),
        const SizedBox(height: 12),

        // Forgot password link
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: onForgotPassword,
            child: Text(
              'Forgot password?',
              style: TextStyle(fontSize: 12, color: linkColor, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Sign In Button
        OneSsoButton(
          label: 'Sign In',
          trailing: const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
          isLoading: isLoading,
          onPressed: () {
            final pass = passwordController.text;
            if (pass.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter your password')),
              );
              return;
            }
            onSignIn(pass);
          },
        ),
        const SizedBox(height: 14),

        // Alternative: Send SMS Code instead
        OneSsoButton(
          label: 'Login with SMS Code instead',
          isSecondary: true,
          isLoading: isLoading,
          onPressed: onSendSmsCodeInstead,
        ),
      ],
    );
  }
}
