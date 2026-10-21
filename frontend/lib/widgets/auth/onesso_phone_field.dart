import 'package:flutter/material.dart';

/// OneSSO split phone input field with country code prefix and mobile text input.
class OneSsoPhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final String selectedCountryCode;
  final ValueChanged<String>? onCountryCodeChanged;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const OneSsoPhoneField({
    super.key,
    required this.controller,
    this.label = 'Mobile number',
    this.hintText = 'Enter mobile number',
    this.selectedCountryCode = '+91',
    this.onCountryCodeChanged,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<OneSsoPhoneField> createState() => _OneSsoPhoneFieldState();
}

class _OneSsoPhoneFieldState extends State<OneSsoPhoneField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF2C2C32) : const Color(0xFFE2E8F0);
    const focusBorderColor = Color(0xFFE52535);
    final labelColor = isDark ? Colors.white70 : const Color(0xFF334155);
    final boxColor = isDark ? const Color(0xFF1A1A1E) : const Color(0xFFF8FAFC);
    final pillColor = isDark ? const Color(0xFF222228) : const Color(0xFFF1F5F9);
    final pillTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final inputTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);
    final iconColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? focusBorderColor : borderColor,
              width: _isFocused ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Country Code Prefix Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    bottomLeft: Radius.circular(11),
                  ),
                  border: Border(right: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language, size: 16, color: iconColor),
                    const SizedBox(width: 6),
                    Text(
                      widget.selectedCountryCode,
                      style: TextStyle(
                        color: pillTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: iconColor),
                  ],
                ),
              ),

              // Phone Number Input
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: inputTextColor, fontSize: 14),
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(color: hintColor, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
