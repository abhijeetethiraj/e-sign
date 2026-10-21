import 'package:flutter/material.dart';
import '../../widgets/auth/onesso_button.dart';
import '../../widgets/auth/onesso_text_field.dart';

/// Screen 3: Sign Up / Registration (Matches StartWell Reference Screenshot 5)
class RegisterView extends StatefulWidget {
  final String? initialMobile;
  final VoidCallback onGoToLogin;
  final Function({
    required String firstName,
    required String lastName,
    required String email,
    required String mobile,
    required String password,
  }) onCompleteRegistration;
  final bool isLoading;

  const RegisterView({
    super.key,
    this.initialMobile,
    required this.onGoToLogin,
    required this.onCompleteRegistration,
    this.isLoading = false,
  });

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  late final TextEditingController _emailController;
  late final TextEditingController _mobileController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final input = widget.initialMobile?.trim() ?? '';
    final isEmail = input.contains('@');
    _emailController = TextEditingController(text: isEmail ? input : '');
    _mobileController = TextEditingController(text: isEmail ? '' : input);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitRegistration() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final mobile = _mobileController.text.trim();
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (first.isEmpty) {
      _showMsg('Please enter your first name');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showMsg('Please enter a valid email address');
      return;
    }
    if (mobile.isEmpty) {
      _showMsg('Please enter your mobile number');
      return;
    }
    if (pass.length < 8) {
      _showMsg('Password must be at least 8 characters (simple is fine, e.g. password123)');
      return;
    }
    if (pass != confirm) {
      _showMsg('Passwords do not match');
      return;
    }

    widget.onCompleteRegistration(
      firstName: first,
      lastName: last.isNotEmpty ? last : first,
      email: email,
      mobile: mobile,
      password: pass,
    );
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFE52535); // Existing brand color
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                'Join eSign',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create an account and start signing documents securely.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: subtitleColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 1. First name (Screenshot 5)
        OneSsoTextField(
          label: "First name",
          hintText: "Enter first name",
          controller: _firstNameController,
          prefixIcon: Icon(Icons.person_outline, color: primaryColor, size: 20),
        ),
        const SizedBox(height: 14),

        // 2. Last name (Screenshot 5)
        OneSsoTextField(
          label: "Last name",
          hintText: "Enter last name",
          controller: _lastNameController,
          prefixIcon: Icon(Icons.person_outline, color: primaryColor, size: 20),
        ),
        const SizedBox(height: 14),

        // 3. Email (Screenshot 5)
        OneSsoTextField(
          label: "Email",
          hintText: "name@example.com",
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icon(Icons.email_outlined, color: primaryColor, size: 20),
        ),
        const SizedBox(height: 14),

        // 4. Mobile Number (prefilled!) (Screenshot 5)
        OneSsoTextField(
          label: "Mobile Number",
          hintText: "Enter 10-digit mobile number",
          controller: _mobileController,
          keyboardType: TextInputType.phone,
          prefixIcon: Icon(Icons.phone_outlined, color: primaryColor, size: 20),
        ),
        const SizedBox(height: 14),

        // 5. Password (Screenshot 5)
        OneSsoTextField(
          label: "Password",
          hintText: "Minimum 8 characters (e.g. password123)",
          controller: _passwordController,
          isPassword: true,
          prefixIcon: Icon(Icons.lock_outline, color: primaryColor, size: 20),
        ),
        const SizedBox(height: 14),

        // 6. Confirm Password (Screenshot 5)
        OneSsoTextField(
          label: "Confirm Password",
          hintText: "Re-enter your password",
          controller: _confirmPasswordController,
          isPassword: true,
          prefixIcon: Icon(Icons.lock_outline, color: primaryColor, size: 20),
        ),
        const SizedBox(height: 24),

        // Sign Up Button
        OneSsoButton(
          label: 'Sign Up',
          isLoading: widget.isLoading,
          onPressed: _submitRegistration,
        ),
        const SizedBox(height: 20),

        // Already have an account? Login
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Already have an account? ',
                style: TextStyle(fontSize: 13, color: subtitleColor),
              ),
              GestureDetector(
                onTap: widget.onGoToLogin,
                child: Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
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
