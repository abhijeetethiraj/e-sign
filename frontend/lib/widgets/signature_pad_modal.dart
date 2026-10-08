import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../core/theme/app_theme.dart';

/// Modal bottom sheet providing a digital drawing pad for electronic signatures.
class SignaturePadModal extends StatefulWidget {
  const SignaturePadModal({super.key});

  @override
  State<SignaturePadModal> createState() => _SignaturePadModalState();
}

class _SignaturePadModalState extends State<SignaturePadModal> {
  late final SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: const Color(0xFF1E293B), // Deep navy / charcoal ink
      exportBackgroundColor: Colors.transparent,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Exports the drawn canvas as transparent PNG bytes
  Future<void> _adoptSignature() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw your signature first.')),
      );
      return;
    }

    final Uint8List? pngBytes = await _controller.toPngBytes();

    if (!mounted || pngBytes == null) return;
    Navigator.of(context).pop(pngBytes);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Row with Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Draw Signature',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Sign directly on screen with your finger or stylus',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted),
                onPressed: () => Navigator.of(context).pop(null),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Digital Signature Canvas
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Signature(
                    controller: _controller,
                    backgroundColor: Colors.transparent,
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 40,
                    child: Container(height: 1, color: Colors.grey.shade300),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 16,
                    child: Text(
                      'Sign above the line',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons: Clear + Adopt Signature
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => _controller.clear(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.borderLight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Clear', style: TextStyle(color: AppTheme.textDark)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _adoptSignature,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Adopt Signature'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
