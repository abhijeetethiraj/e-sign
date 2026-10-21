import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth/onesso_header.dart';
import 'auth/auth_tabs_view.dart';
import 'auth/register_otp_view.dart';
import 'auth/register_view.dart';
import 'auth/set_password_view.dart';
import 'auth/welcome_back_view.dart';

/// Available states in the native authentication flow (Matches StartWell Reference Flow)
enum AuthStep { welcomeBack, authTabs, register, setPassword, registerOtp }

/// Main Screen coordinating the 100% native in-app authentication experience.
/// Checks user registration first, then presents tabbed OTP & Password auth.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  AuthStep _currentStep = AuthStep.welcomeBack;
  String _activeIdentifier = '';
  bool _isUnregistered = false;
  bool _isForgotPasswordMode = false;
  String _lastAutoCheckedIdentifier = '';
  Timer? _debounceTimer;

  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _phoneController.addListener(_onPhoneInputChanged);
  }

  void _onPhoneInputChanged() {
    // Only auto-check when on the WelcomeBack screen
    if (_currentStep != AuthStep.welcomeBack) return;

    final text = _phoneController.text.trim();
    final digits = text.replaceAll(RegExp(r'\D'), '');

    // Reset unregistered status if user altered the input
    if (_isUnregistered && digits != _lastAutoCheckedIdentifier && text != _lastAutoCheckedIdentifier) {
      setState(() => _isUnregistered = false);
    }

    // 1. Mobile Number: As soon as exactly 10 digits are typed on the spot, trigger check!
    if (digits.length == 10) {
      if (digits != _lastAutoCheckedIdentifier && !context.read<AuthProvider>().isLoading) {
        _lastAutoCheckedIdentifier = digits;
        _onIdentifierContinue(digits);
      }
      return;
    }

    // 2. Email Address: If valid email format typed, debounce 600ms and check!
    if (text.contains('@') && text.contains('.') && text.length >= 6) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted &&
            _currentStep == AuthStep.welcomeBack &&
            _phoneController.text.trim() == text &&
            text != _lastAutoCheckedIdentifier &&
            !context.read<AuthProvider>().isLoading) {
          _lastAutoCheckedIdentifier = text;
          _onIdentifierContinue(text);
        }
      });
      return;
    }

    // If input is less than 10 digits and not email, clear last checked
    if (digits.length < 10 && !text.contains('@')) {
      _lastAutoCheckedIdentifier = '';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          final auth = context.read<AuthProvider>();
          if (auth.isLoading && !auth.isAuthenticated) {
            auth.cancelLoading();
          }
        }
      });
    }
  }

  /// Step 1: Identifier Entry -> Check if already registered
  Future<void> _onIdentifierContinue(String identifier) async {
    final cleanId = identifier.trim();
    if (cleanId.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final check = await auth.checkUserExists(cleanId);
    if (!mounted) return;

    if (check['exists'] == true) {
      // 1. User IS REGISTERED: Proceed to Auth Tabs and dispatch SMS OTP
      setState(() {
        _activeIdentifier = cleanId;
        _isUnregistered = false;
        _isForgotPasswordMode = false;
        _currentStep = AuthStep.authTabs;
      });

      // Send SMS OTP and announce success
      final res = await auth.sendSmsOtp(cleanId);
      if (mounted && res != null && res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to $cleanId successfully!'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else {
      // 2. User is NOT REGISTERED: Update button to 'Register' (Screenshot 3)
      setState(() {
        _activeIdentifier = cleanId;
        _isUnregistered = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account not found. Tap Register to create your account.'),
          backgroundColor: Color(0xFFE52535),
        ),
      );
    }
  }

  /// Triggered from AuthTabsView -> Verify OTP
  Future<void> _onVerifyOtp(String otp) async {
    final auth = context.read<AuthProvider>();

    if (_isForgotPasswordMode) {
      final verified = await auth.verifyForgotPasswordOtp(
        phoneNumber: _activeIdentifier,
        otp: otp,
      );

      if (verified && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identity verified! Please set your new password.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        setState(() => _currentStep = AuthStep.setPassword);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Invalid verification code. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else {
      final success = await auth.verifySmsOtp(
        phoneNumber: _activeIdentifier,
        otp: otp,
        isForgotPassword: false,
      );

      if (success && mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Invalid verification code. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Triggered from AuthTabsView -> Password Sign In
  Future<void> _onPasswordSignIn(String password) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithCredentials(
      username: _activeIdentifier,
      password: password,
    );

    if (success && mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Invalid credentials. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Triggered from Forgot Password
  Future<void> _onForgotPassword() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      _isForgotPasswordMode = true;
    });

    final res = await auth.sendSmsOtp(_activeIdentifier, isForgotPassword: true);
    if (mounted && res != null && res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password recovery code sent to $_activeIdentifier.'),
          backgroundColor: const Color(0xFFE52535),
        ),
      );
    }
  }

  /// Triggered from SetPasswordView
  Future<void> _onSetNewPassword(String newPassword) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(newPassword: newPassword);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully! Logging you in...'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );

      final loginSuccess = await auth.loginWithCredentials(
        username: _activeIdentifier,
        password: newPassword,
      );

      if (loginSuccess && mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Failed to update password.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Triggered from RegisterView -> Complete Registration
  /// Flow: Create Account -> Send SMS OTP -> Show OTP Verification -> Auto-Login on OTP Verify
  Future<void> _onCompleteRegistration({
    required String firstName,
    required String lastName,
    required String email,
    required String mobile,
    required String password,
  }) async {
    final auth = context.read<AuthProvider>();
    final cleanMobile = mobile.trim();

    // 1. Create account in CubeOne / ChsOne database
    final created = await auth.createAccountOnly(
      firstName: firstName,
      lastName: lastName,
      email: email,
      mobile: cleanMobile,
      password: password,
    );

    if (created && mounted) {
      // 2. Move to dedicated Registration OTP verification view with the registered mobile number
      setState(() {
        _activeIdentifier = cleanMobile;
        _isUnregistered = false;
        _isForgotPasswordMode = false;
        _currentStep = AuthStep.registerOtp;
      });

      // 3. Dispatch real SMS OTP to user's phone
      await auth.sendSmsOtp(cleanMobile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created! Verification OTP sent to $cleanMobile.'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Registration failed. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF141416) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              // 1. OneSSO Header with Logo & Back button
              OneSsoHeader(
                showBack: _currentStep != AuthStep.welcomeBack,
                onBack: () {
                  context.read<AuthProvider>().cancelLoading();
                  setState(() {
                    if (_currentStep == AuthStep.registerOtp) {
                      _currentStep = AuthStep.register;
                    } else {
                      _isForgotPasswordMode = false;
                      _currentStep = AuthStep.welcomeBack;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),

              // 2. Animated Flow Views (Zero Browser Redirect)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<AuthStep>(_currentStep),
                  child: _buildCurrentView(auth.isLoading),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView(bool isLoading) {
    switch (_currentStep) {
      case AuthStep.welcomeBack:
        return WelcomeBackView(
          phoneController: _phoneController,
          isLoading: isLoading,
          isUnregistered: _isUnregistered,
          onContinue: _onIdentifierContinue,
          onGoToRegister: () {
            context.read<AuthProvider>().cancelLoading();
            setState(() {
              _activeIdentifier = _phoneController.text.trim();
              _currentStep = AuthStep.register;
            });
          },
        );

      case AuthStep.authTabs:
        return AuthTabsView(
          identifier: _activeIdentifier,
          isLoading: isLoading,
          onVerifyOtp: _onVerifyOtp,
          onPasswordSignIn: _onPasswordSignIn,
          onResendOtp: () => context.read<AuthProvider>().sendSmsOtp(_activeIdentifier),
          onEditIdentifier: () {
            context.read<AuthProvider>().cancelLoading();
            setState(() {
              _lastAutoCheckedIdentifier = _activeIdentifier;
              _currentStep = AuthStep.welcomeBack;
            });
          },
          onForgotPassword: _onForgotPassword,
          onGoToRegister: () {
            context.read<AuthProvider>().cancelLoading();
            setState(() => _currentStep = AuthStep.register);
          },
        );

      case AuthStep.setPassword:
        return SetPasswordView(
          identifier: _activeIdentifier,
          isLoading: isLoading,
          onSetPassword: _onSetNewPassword,
          onBackToLogin: () {
            context.read<AuthProvider>().cancelLoading();
            setState(() {
              _isForgotPasswordMode = false;
              _currentStep = AuthStep.welcomeBack;
            });
          },
        );

      case AuthStep.register:
        return RegisterView(
          initialMobile: _activeIdentifier,
          isLoading: isLoading,
          onGoToLogin: () {
            context.read<AuthProvider>().cancelLoading();
            setState(() => _currentStep = AuthStep.welcomeBack);
          },
          onCompleteRegistration: _onCompleteRegistration,
        );

      case AuthStep.registerOtp:
        return RegisterOtpView(
          mobileNumber: _activeIdentifier,
          isLoading: isLoading,
          onVerifyOtp: _onVerifyOtp,
          onResendOtp: () => context.read<AuthProvider>().sendSmsOtp(_activeIdentifier),
          onEditMobile: () {
            context.read<AuthProvider>().cancelLoading();
            setState(() => _currentStep = AuthStep.register);
          },
        );
    }
  }
}
