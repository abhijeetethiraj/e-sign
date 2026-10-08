import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../core/theme/app_theme.dart';
import '../models/signing_event.dart';
import '../services/local_document_service.dart';

/// Screen displaying the finalized, stamped PDF with sharing capabilities
class SignedResultScreen extends StatefulWidget {
  final String title;
  final Uint8List signedPdfBytes;
  final SigningEvent? signingEvent;

  const SignedResultScreen({
    super.key,
    required this.title,
    required this.signedPdfBytes,
    this.signingEvent,
  });

  @override
  State<SignedResultScreen> createState() => _SignedResultScreenState();
}

class _SignedResultScreenState extends State<SignedResultScreen> {
  bool _isSharing = false;

  /// Opens the native share sheet
  Future<void> _sharePdf() async {
    setState(() => _isSharing = true);
    try {
      await LocalDocumentService.shareDocument(
        title: widget.title,
        bytes: widget.signedPdfBytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to share file: $e')));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  bool _isSaving = false;

  /// Saves the stamped PDF directly to device public Downloads folder
  Future<void> _saveToDownloads() async {
    setState(() => _isSaving = true);
    try {
      final String? path = await LocalDocumentService.exportToDownloads(
        fileName: widget.title,
        bytes: widget.signedPdfBytes,
      );

      if (!mounted) return;
      if (path != null) {
        final String fileName = path.split('/').last;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Saved to Downloads: $fileName\n(Visible in your Files app!)'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save to public Downloads. Use Share instead.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Displays the official legal audit certificate details modal
  void _showAuditSheet() {
    final event = widget.signingEvent;
    if (event == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.badgeReadyBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified, color: AppTheme.primaryBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Legal Audit Certificate',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        Text(
                          'Compliant with US ESIGN, EU eIDAS & IT Act',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              _buildAuditRow('Signer Email', event.userEmail),
              _buildAuditRow('Signer IP Address', event.ipAddress, isBold: true),
              _buildAuditRow('Keycloak User ID', event.userId),
              _buildAuditRow('Timestamp', '${event.signedAt.toIso8601String().replaceAll('T', ' ').substring(0, 19)} UTC'),
              _buildAuditRow('Auth Method', event.authenticationMethod),
              _buildAuditRow('Biometric Proof', event.biometricVerification, isBold: true),
              _buildAuditRow('Document SHA-256', event.documentHash, isMonospace: true),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuditRow(String label, String value, {bool isBold = false, bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontFamily: isMonospace ? 'Courier' : null,
                color: isBold ? AppTheme.primaryBlue : AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Signed Document',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary(context),
          ),
        ),
        actions: [
          // Audit Trail Details button
          IconButton(
            tooltip: 'View Audit Certificate',
            icon: const Icon(Icons.verified_outlined, color: AppTheme.primaryBlue),
            onPressed: _showAuditSheet,
          ),
          // Save to public Downloads button
          IconButton(
            tooltip: 'Save to Downloads folder (visible in Files app)',
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, color: AppTheme.primaryBlue),
            onPressed: _isSaving ? null : _saveToDownloads,
          ),
          // Share Button
          IconButton(
            tooltip: 'Share signed PDF',
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined, color: AppTheme.primaryBlue),
            onPressed: _isSharing ? null : _sharePdf,
          ),
          // Done button to return to Dashboard
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text(
              'Done',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // Displays the finalized signed PDF with guaranteed bounded constraints
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedWidth ||
              !constraints.hasBoundedHeight ||
              constraints.maxWidth <= 0 ||
              constraints.maxHeight <= 0) {
            return const Center(child: CircularProgressIndicator());
          }

          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: SfPdfViewer.memory(
              widget.signedPdfBytes,
              canShowScrollHead: true,
              canShowScrollStatus: true,
            ),
          );
        },
      ),
      // Bottom banner indicating success
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            border: Border(top: BorderSide(color: AppTheme.borderColor(context))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryBg(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Signed & Verified',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
              // Save to Downloads button
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _saveToDownloads,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Save'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  side: const BorderSide(color: AppTheme.primaryBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              // Share button
              ElevatedButton.icon(
                onPressed: _isSharing ? null : _sharePdf,
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Alias for convenience
typedef SignedResult = SignedResultScreen;
