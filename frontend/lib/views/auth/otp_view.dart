import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/auth/onesso_button.dart';
import '../../widgets/auth/onesso_text_field.dart';

/// Screen 3: SMS OTP Verification (Zero browser redirect)
class OtpView extends StatefulWidget {
  final String mobileNumber;
  final ValueChanged<String> onVerifyOtp;
  final VoidCallback onResendOtp;
  final VoidCallback onLoginWithPasswordInstead;
  final VoidCallback onBackToPhone;
  final bool isLoading;
  final bool isForgotPassword;

  const OtpView({
    super.key,
    required this.mobileNumber,
    required this.onVerifyOtp,
    required this.onResendOtp,
    required this.onLoginWithPasswordInstead,
    required this.onBackToPhone,
    this.isLoading = false,
    this.isForgotPassword = false,
  });

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView> {
  final TextEditingController _otpController = TextEditingController();
  int _secondsRemaining = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final timerTextColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);
    final iconColor = isDark ? Colors.white38 : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isForgotPassword ? 'Password recovery' : 'Verify code',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: titleColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.isForgotPassword
              ? 'Enter the password recovery code sent to ${widget.mobileNumber}'
              : 'Enter the verification code sent to ${widget.mobileNumber}',
          style: TextStyle(fontSize: 14, color: subtitleColor),
        ),
        const SizedBox(height: 24),

        // OTP input field
        OneSsoTextField(
          label: 'SMS Verification Code',
          hintText: 'Enter OTP code',
          controller: _otpController,
          keyboardType: TextInputType.number,
          autofocus: true,
          prefixIcon: Icon(Icons.sms_outlined, color: iconColor, size: 20),
          onChanged: (val) {
            if (val.length == 4 || val.length == 6) {
              widget.onVerifyOtp(val);
            }
          },
        ),
        const SizedBox(height: 12),

        // Resend Timer Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _secondsRemaining > 0
                  ? 'Resend code in ${_secondsRemaining}s'
                  : 'Didn\'t receive code?',
              style: TextStyle(fontSize: 12, color: timerTextColor),
            ),
            if (_secondsRemaining == 0)
              GestureDetector(
                onTap: () {
                  _startTimer();
                  widget.onResendOtp();
                },
                child: const Text(
                  'Resend SMS',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFE52535),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // Verify button
        OneSsoButton(
          label: widget.isForgotPassword ? 'Verify & Recover Access' : 'Verify & Continue',
          isLoading: widget.isLoading,
          onPressed: () {
            final code = _otpController.text.trim();
            if (code.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter the verification code')),
              );
              return;
            }
            widget.onVerifyOtp(code);
          },
        ),
        const SizedBox(height: 14),

        // Password alternative
        OneSsoButton(
          label: 'Use Password Instead',
          isSecondary: true,
          isLoading: widget.isLoading,
          onPressed: widget.onLoginWithPasswordInstead,
        ),
      ],
    );
  }
}
