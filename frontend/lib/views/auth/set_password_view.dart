import 'package:flutter/material.dart';
import '../../widgets/auth/onesso_button.dart';
import '../../widgets/auth/onesso_text_field.dart';

/// Screen 4.5: Set New Password (shown after forgot-password OTP verification)
///
/// The user has already proven their identity via OTP. This screen lets them
/// choose a new password before being logged into the app.
class SetPasswordView extends StatefulWidget {
  final String identifier;
  final ValueChanged<String> onSetPassword;
  final VoidCallback onBackToLogin;
  final bool isLoading;

  const SetPasswordView({
    super.key,
    required this.identifier,
    required this.onSetPassword,
    required this.onBackToLogin,
    this.isLoading = false,
  });

  @override
  State<SetPasswordView> createState() => _SetPasswordViewState();
}

class _SetPasswordViewState extends State<SetPasswordView> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.isEmpty) {
      _showError('Please enter a new password.');
      return;
    }
    if (newPass.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    if (newPass != confirmPass) {
      _showError('Passwords do not match. Please re-enter.');
      return;
    }

    widget.onSetPassword(newPass);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final iconColor = isDark ? Colors.white38 : const Color(0xFF64748B);
    final successBg = isDark ? const Color(0xFF1B3A1B) : const Color(0xFFE8F5E9);
    final successIcon = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success verification badge
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: successBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified_user_rounded, color: successIcon, size: 28),
          ),
        ),
        const SizedBox(height: 16),

        Center(
          child: Text(
            'Identity verified',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: successIcon,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Set new password',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: titleColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create a strong new password for ${widget.identifier}',
          style: TextStyle(fontSize: 14, color: subtitleColor),
        ),
        const SizedBox(height: 28),

        // New Password field
        OneSsoTextField(
          label: 'New Password',
          hintText: 'Minimum 6 characters',
          controller: _newPasswordController,
          isPassword: true,
          autofocus: true,
          prefixIcon: Icon(Icons.lock_outline, color: iconColor, size: 20),
        ),
        const SizedBox(height: 18),

        // Confirm Password field
        OneSsoTextField(
          label: 'Confirm Password',
          hintText: 'Re-enter your new password',
          controller: _confirmPasswordController,
          isPassword: true,
          prefixIcon: Icon(Icons.lock_outline, color: iconColor, size: 20),
          onSubmitted: (_) => _onSubmit(),
        ),
        const SizedBox(height: 28),

        // Update Password button
        OneSsoButton(
          label: 'Update Password',
          trailing: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
          isLoading: widget.isLoading,
          onPressed: _onSubmit,
        ),
        const SizedBox(height: 14),

        // Back to login
        OneSsoButton(
          label: 'Back to Login',
          isSecondary: true,
          isLoading: widget.isLoading,
          onPressed: widget.onBackToLogin,
        ),
      ],
    );
  }
}
