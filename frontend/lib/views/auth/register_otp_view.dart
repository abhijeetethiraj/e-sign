import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sms_autofill/sms_autofill.dart';
import '../../services/native_sms_service.dart';
import '../../widgets/auth/onesso_button.dart';

/// Screen: Dedicated Registration OTP Verification Screen
/// Purpose: Shown immediately after user signs up.
/// - NO "Use Password" tab (avoids false/invalid password attempts on unverified accounts)
/// - NO "Sign Up" toggle (user is already in registration flow)
/// - Pure focus on 4-digit SMS OTP verification and account activation
class RegisterOtpView extends StatefulWidget {
  final String mobileNumber;
  final bool isLoading;
  final ValueChanged<String> onVerifyOtp;
  final VoidCallback onResendOtp;
  final VoidCallback onEditMobile;

  const RegisterOtpView({
    super.key,
    required this.mobileNumber,
    this.isLoading = false,
    required this.onVerifyOtp,
    required this.onResendOtp,
    required this.onEditMobile,
  });

  @override
  State<RegisterOtpView> createState() => _RegisterOtpViewState();
}

class _RegisterOtpViewState extends State<RegisterOtpView> with CodeAutoFill {
  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;
  int _secondsRemaining = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _otpControllers = List.generate(4, (_) => TextEditingController());
    _otpFocusNodes = List.generate(4, (_) => FocusNode());

    _startResendTimer();

    // 1. Native Android BroadcastReceiver listener (reads SMS in real-time)
    NativeSmsService.initialize(
      onCodeReceived: (otp) {
        if (mounted) {
          debugPrint('[RegisterOtpView] Native SMS received: $otp');
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

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

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
    _timer?.cancel();
    NativeSmsService.stopListening();
    cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentEnteredOtp =>
      _otpControllers.map((c) => c.text.trim()).join();

  void _submitOtp() {
    final otp = _currentEnteredOtp;
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 4-digit verification code')),
      );
      return;
    }
    widget.onVerifyOtp(otp);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFE52535);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final timerTextColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Subtitle
        Text(
          'Verify Mobile Number',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: titleColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter the 4-digit code sent via SMS to activate your account.',
          style: TextStyle(fontSize: 14, color: subtitleColor, height: 1.4),
        ),
        const SizedBox(height: 20),

        // Verified Mobile Identifier Card with Edit Pencil
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252538) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.phone_android_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mobile Number (Activation Pending)',
                      style: TextStyle(
                        fontSize: 11,
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.mobileNumber,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: primaryColor, size: 20),
                tooltip: 'Edit number',
                onPressed: widget.onEditMobile,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // "Enter OTP" Label + Green Status Pill
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Enter OTP',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 4),
                const Text(
                  'OTP sent! Expires in 5m',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 4-Digit Pin Input Boxes
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
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
                onChanged: (val) {
                  final cleanVal = val.trim();
                  if (cleanVal.length > 1) {
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

        // Resend Timer & Action
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _secondsRemaining > 0
                  ? 'Resend OTP in ${_secondsRemaining}s'
                  : 'Didn\'t receive code?',
              style: TextStyle(fontSize: 12, color: timerTextColor),
            ),
            if (_secondsRemaining == 0)
              GestureDetector(
                onTap: () {
                  for (final c in _otpControllers) {
                    c.clear();
                  }
                  listenForCode();
                  NativeSmsService.startListening();
                  _startResendTimer();
                  widget.onResendOtp();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('A fresh OTP has been sent via SMS.')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Resend OTP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // Primary Action Button
        OneSsoButton(
          label: 'Verify & Activate Account',
          isLoading: widget.isLoading,
          onPressed: _submitOtp,
        ),
        const SizedBox(height: 16),

        // Reassurance footer
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: subtitleColor),
              const SizedBox(width: 6),
              Text(
                'Secured by CubeOne SSO Platform',
                style: TextStyle(fontSize: 12, color: subtitleColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
