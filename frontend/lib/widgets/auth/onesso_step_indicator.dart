import 'package:flutter/material.dart';

/// 1 ─ 2 ─ 3 Step progress indicator matching the OneSSO registration flow.
class OneSsoStepIndicator extends StatelessWidget {
  final int currentStep; // 1, 2, or 3
  final int totalSteps;

  const OneSsoStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = Color(0xFFE52535);
    final inactiveColor = isDark ? const Color(0xFF222228) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF33333C) : const Color(0xFFE2E8F0);
    final inactiveTextColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);

    return Row(
      children: List.generate(totalSteps * 2 - 1, (index) {
        if (index.isOdd) {
          // Connecting line between steps
          final stepBefore = (index ~/ 2) + 1;
          final isCompleted = currentStep > stepBefore;
          return Expanded(
            child: Container(
              height: 1.5,
              color: isCompleted ? activeColor : borderColor,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
          );
        }

        // Step Circle
        final stepNumber = (index ~/ 2) + 1;
        final isActive = currentStep == stepNumber;
        final isPassed = currentStep > stepNumber;

        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isActive || isPassed) ? activeColor : inactiveColor,
            border: Border.all(
              color: (isActive || isPassed) ? activeColor : borderColor,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isPassed
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: (isActive || isPassed) ? Colors.white : inactiveTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        );
      }),
    );
  }
}
