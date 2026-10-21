import 'package:flutter/material.dart';
import 'package:sms_autofill/sms_autofill.dart';
import '../../services/native_sms_service.dart';
import '../../widgets/auth/onesso_button.dart';
import '../../widgets/auth/onesso_text_field.dart';

/// Screen 2: Unified Authentication Screen (Matches StartWell Reference Screenshots 1 & 4)
/// Provides toggle between [ Use OTP ] and [ Use Password ], with prefilled identifier and edit pencil.
class AuthTabsView extends StatefulWidget {
  final String identifier;
  final bool isLoading;
  final ValueChanged<String> onVerifyOtp;
  final ValueChanged<String> onPasswordSignIn;
  final VoidCallback onResendOtp;
  final VoidCallback onEditIdentifier;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoToRegister;

  const AuthTabsView({
    super.key,
    required this.identifier,
    this.isLoading = false,
    required this.onVerifyOtp,
    required this.onPasswordSignIn,
    required this.onResendOtp,
    required this.onEditIdentifier,
    required this.onForgotPassword,
    required this.onGoToRegister,
  });

  @override
  State<AuthTabsView> createState() => _AuthTabsViewState();
}

class _AuthTabsViewState extends State<AuthTabsView> with CodeAutoFill {
  bool _useOtp = true;
  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 4 OTP Box controllers - intentionally kept empty so user enters or auto-fills real SMS OTP
    _otpControllers = List.generate(4, (_) => TextEditingController());
    _otpFocusNodes = List.generate(4, (_) => FocusNode());

    // 1. Native Android BroadcastReceiver listener (reads SMS in real-time without app hash)
    NativeSmsService.initialize(
      onCodeReceived: (otp) {
        if (mounted) {
          debugPrint('[AuthTabsView] Native SMS received: $otp');
          for (int i = 0; i < 4 && i < otp.length; i++) {
            _otpControllers[i].text = otp[i];
          }
          _submitOtp();
        }
      },
    );

    // 2. Google SMS Retriever fallback
    listenForCode();
  }

  /// Automatically triggered by sms_autofill when an incoming SMS with OTP arrives
  @override
  void codeUpdated() {
    if (code != null && code!.isNotEmpty) {
      final digits = code!.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 4) {
        for (int i = 0; i < 4; i++) {
          _otpControllers[i].text = digits[i];
        }
        _submitOtp();
      }
    }
  }

  @override
  void dispose() {
    NativeSmsService.stopListening();
    cancel(); // Cancel SMS Retriever listener when leaving screen
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _passwordController.dispose();
    super.dispose();
  }

  String get _currentEnteredOtp =>
      _otpControllers.map((c) => c.text.trim()).join();

  void _submitOtp() {
    final otp = _currentEnteredOtp;
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 4-digit OTP')),
      );
      return;
    }
    widget.onVerifyOtp(otp);
  }

  void _submitPassword() {
    final pass = _passwordController.text;
    if (pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }
    widget.onPasswordSignIn(pass);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFE52535); // Existing OneSSO / eSign brand color
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Toggle Tabs: [ Use OTP ] [ Use Password ] (Screenshot 1 & 4)
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              // Use OTP Tab
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _useOtp = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _useOtp ? primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'Use OTP',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _useOtp ? Colors.white : subtitleColor,
                      ),
                    ),
                  ),
                ),
              ),
              // Use Password Tab
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _useOtp = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: !_useOtp ? primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'Use Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: !_useOtp ? Colors.white : subtitleColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 2. Prefilled Identifier Container with Pencil Edit Icon (Screenshot 1 & 4)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252538) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.person_outline, color: primaryColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mobile / Email',
                      style: TextStyle(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.identifier,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Pencil edit button
              IconButton(
                icon: Icon(Icons.edit_outlined, color: primaryColor, size: 20),
                tooltip: 'Change number',
                onPressed: widget.onEditIdentifier,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. Tab Body: OTP or Password
        if (_useOtp) ...[
          // Header with green "OTP sent! Expires in 5m" status (Screenshot 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Enter OTP',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: titleColor),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'OTP sent! Expires in 5m',
                    style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4-Digit Box Input (Screenshot 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) {
              return SizedBox(
                width: 64,
                height: 64,
                child: TextField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF252538) : Colors.white,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: _boxDecorationBorder(primaryColor.withValues(alpha: 0.3)),
                    focusedBorder: _boxDecorationBorder(primaryColor, width: 2),
                  ),
                  onChanged: (val) {
                    final cleanVal = val.trim();
                    if (cleanVal.length > 1) {
                      // Handled multi-digit paste or SMS autofill
                      for (int i = 0; i < 4 && i < cleanVal.length; i++) {
                        _otpControllers[i].text = cleanVal[i];
                      }
                      _otpFocusNodes[3].requestFocus();
                      if (_currentEnteredOtp.length == 4) {
                        _submitOtp();
                      }
                      return;
                    }
                    if (cleanVal.isNotEmpty && index < 3) {
                      _otpFocusNodes[index + 1].requestFocus();
                    } else if (cleanVal.isEmpty && index > 0) {
                      _otpFocusNodes[index - 1].requestFocus();
                    }
                    if (_currentEnteredOtp.length == 4) {
                      _submitOtp();
                    }
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Resend OTP ? link (Screenshot 1)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                for (final c in _otpControllers) {
                  c.clear();
                }
                listenForCode();
                NativeSmsService.startListening();
                widget.onResendOtp();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('A fresh OTP has been sent via SMS.')),
                );
              },
              child: Text(
                'Resend OTP ?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Verify OTP Button
          OneSsoButton(
            label: 'Verify OTP',
            isLoading: widget.isLoading,
            onPressed: _submitOtp,
          ),
        ] else ...[
          // Password Input Field (Screenshot 4)
          OneSsoTextField(
            label: 'Password',
            hintText: 'Enter your password',
            controller: _passwordController,
            isPassword: true,
            prefixIcon: Icon(Icons.lock_outline, color: primaryColor, size: 20),
            onSubmitted: (_) => _submitPassword(),
          ),
          const SizedBox(height: 10),

          // Forgot Password? link (Screenshot 4)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onForgotPassword,
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Login Button
          OneSsoButton(
            label: 'Login',
            isLoading: widget.isLoading,
            onPressed: _submitPassword,
          ),
        ],

        const SizedBox(height: 24),

        // Don't have an account? Sign Up
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: TextStyle(fontSize: 13, color: subtitleColor),
            ),
            GestureDetector(
              onTap: widget.onGoToRegister,
              child: Text(
                'Sign Up',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputBorder _boxDecorationBorder(Color color, {double width = 1.2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
