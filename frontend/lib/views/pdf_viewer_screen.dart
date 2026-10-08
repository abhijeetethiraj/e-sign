import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:frontend/models/user_session.dart';
import 'package:frontend/services/local_document_service.dart';
import 'package:frontend/views/pdf_placement_screen.dart';
import 'package:frontend/widgets/signature_pad_modal.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../core/theme/app_theme.dart';

/// Screen that displays the selected PDF document clearly.
/// For unsigned documents: allows zoom and navigating to "Sign Document".
/// For signed documents: provides instant "Share PDF" and "Save to Device".
class PdfViewerScreen extends StatefulWidget {
  final String title;
  final Uint8List pdfBytes;
  final UserSession? userSession;
  final bool isSigned;

  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfBytes,
    this.userSession,
    this.isSigned = false,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // Key and controller to reliably manage SfPdfViewer lifecycle
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey<SfPdfViewerState>();
  final PdfViewerController _pdfViewerController = PdfViewerController();

  bool _isSharing = false;
  bool _isSaving = false;
  bool _isDocumentLoaded = false;

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  bool get _isDocumentSigned =>
      widget.isSigned || widget.title.toLowerCase().startsWith('signed_');

  Future<void> _sharePdf() async {
    setState(() => _isSharing = true);
    try {
      await LocalDocumentService.shareDocument(
        title: widget.title,
        bytes: widget.pdfBytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share document: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _saveToDownloads() async {
    setState(() => _isSaving = true);
    try {
      final String? path = await LocalDocumentService.exportToDownloads(
        fileName: widget.title,
        bytes: widget.pdfBytes,
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
          const SnackBar(content: Text('Could not save to public Downloads.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _onSignTapped() async {
    final Uint8List? signatureBytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SignaturePadModal(),
    );

    // If the user signed and tapped "Adopt Signature", transition to Placement Screen cleanly
    // Using pushReplacement releases the unneeded viewer and native PDFium handles from memory
    if (signatureBytes != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PdfPlacementScreen(
            title: widget.title,
            pdfBytes: widget.pdfBytes,
            signatureBytes: signatureBytes,
            userSession: widget.userSession,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context),
          ),
        ),
        actions: [
          // If document is signed, expose direct Share & Download in the app bar
          if (_isDocumentSigned) ...[
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, color: AppTheme.primaryBlue),
              tooltip: 'Save to Downloads',
              onPressed: _isSaving ? null : _saveToDownloads,
            ),
            IconButton(
              icon: _isSharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined, color: AppTheme.primaryBlue),
              tooltip: 'Share Document',
              onPressed: _isSharing ? null : _sharePdf,
            ),
          ],
          // Zoom in button (guarded until PDF document is safely loaded in memory)
          IconButton(
            icon: Icon(
              Icons.zoom_in,
              color: _isDocumentLoaded ? AppTheme.textPrimary(context) : AppTheme.textMuted,
            ),
            onPressed: _isDocumentLoaded
                ? () {
                    _pdfViewerController.zoomLevel =
                        (_pdfViewerController.zoomLevel + 0.25).clamp(1.0, 3.0);
                  }
                : null,
          ),
          // Zoom out button (guarded until PDF document is safely loaded in memory)
          IconButton(
            icon: Icon(
              Icons.zoom_out,
              color: _isDocumentLoaded ? AppTheme.textPrimary(context) : AppTheme.textMuted,
            ),
            onPressed: _isDocumentLoaded
                ? () {
                    _pdfViewerController.zoomLevel =
                        (_pdfViewerController.zoomLevel - 0.25).clamp(1.0, 3.0);
                  }
                : null,
          ),
        ],
      ),
      // PDF Viewer rendering with guaranteed tight bounded layout constraints
      body: LayoutBuilder(
        builder: (context, constraints) {
          // If screen layout constraints are not yet ready during route transition, show spinner
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
              widget.pdfBytes,
              key: _pdfViewerKey,
              controller: _pdfViewerController,
              canShowScrollHead: false,
              canShowScrollStatus: false,
              canShowPaginationDialog: false,
              enableDoubleTapZooming: false,
              onDocumentLoaded: (details) {
                if (mounted) {
                  setState(() => _isDocumentLoaded = true);
                }
              },
            ),
          );
        },
      ),
      // Bottom Action Bar: Dynamic based on signed status
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            border: Border(top: BorderSide(color: AppTheme.borderColor(context))),
          ),
          child: _isDocumentSigned
              ? Row(
                  children: [
                    // Save to Downloads button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _saveToDownloads,
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Save to Device'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          side: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Share PDF button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSharing ? null : _sharePdf,
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Share PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : ElevatedButton.icon(
                  onPressed: _onSignTapped,
                  icon: const Icon(Icons.draw, size: 20),
                  label: const Text('Sign Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
