import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../core/theme/app_theme.dart';
import '../models/document_item.dart';
import '../models/signing_event.dart';
import '../models/user_session.dart';
import '../services/audit_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/local_document_service.dart';
import '../services/pdf_stamping_service.dart';
import 'signed_result_screen.dart';

/// Represents an interactive signature box placement on the document
class SignaturePlacement {
  final String id;
  int pageIndex; // 0-based page index (e.g. 0 = Page 1)
  double x; // Position X on the page viewport
  double y; // Position Y on the page viewport
  double get docY => y; // Backward-compatibility helper for tests
  set docY(double val) => y = val;
  bool isLocked; // When true, fixed in place so it cannot accidentally move

  SignaturePlacement({
    required this.id,
    this.pageIndex = 0,
    required this.x,
    double? y,
    double? docY,
    this.isLocked = false,
  }) : y = y ?? docY ?? 0.0;
}

/// Screen allowing the user to tap-to-place and drag signatures directly onto the PDF
class PdfPlacementScreen extends StatefulWidget {
  final String title;
  final Uint8List pdfBytes;
  final Uint8List signatureBytes;
  final UserSession? userSession;

  const PdfPlacementScreen({
    super.key,
    required this.title,
    required this.pdfBytes,
    required this.signatureBytes,
    this.userSession,
  });

  @override
  State<PdfPlacementScreen> createState() => _PdfPlacementScreenState();
}

class _PdfPlacementScreenState extends State<PdfPlacementScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();

  // List of placed signature boxes on the document
  final List<SignaturePlacement> _placements = [];
  bool _initializedPosition = false;

  // Signature box dimensions on screen
  final double _signatureWidth = 150.0;
  final double _signatureHeight = 64.0;

  bool _isStamping = false;
  int _currentPage = 1;
  int _totalPages = 1;

  /// Returns the placement furthest down the document (highest page, lowest Y)
  /// This is the true "Authorized Signature" block where the DSC seal belongs.
  SignaturePlacement? get _authorizedFinalPlacement {
    if (_placements.isEmpty) return null;
    SignaturePlacement best = _placements.first;
    for (final p in _placements) {
      if (p.pageIndex > best.pageIndex || (p.pageIndex == best.pageIndex && p.y > best.y)) {
        best = p;
      }
    }
    return best;
  }

  final Map<int, Size> _pageSizes = {};
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    try {
      final doc = PdfDocument(inputBytes: widget.pdfBytes);
      _totalPages = doc.pages.count;
      _currentPage = _totalPages; // Start directly on the final signature page
      for (int i = 0; i < doc.pages.count; i++) {
        _pageSizes[i] = doc.pages[i].size;
      }
      doc.dispose();
    } catch (_) {
      _totalPages = 1;
      _currentPage = 1;
      _pageSizes[0] = const Size(595.28, 841.89);
    }
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  /// Calculates the exact screen bounding rectangle of the rendered PDF page inside SfPdfViewer.
  /// Eliminates the vertical letterbox top margin so stamped signatures match on-screen placement 1:1.
  Rect _calculateRenderedPageBounds(int pageIndex, Size viewportSize) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) {
      return Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height);
    }
    final pdfPageSize = _pageSizes[pageIndex] ?? const Size(595.28, 841.89);
    final double scaleW = viewportSize.width / pdfPageSize.width;

    // Single-page mode in SfPdfViewer fits width on mobile portrait
    if (pdfPageSize.height * scaleW <= viewportSize.height) {
      final double renderedHeight = pdfPageSize.height * scaleW;
      final double topOffset = (viewportSize.height - renderedHeight) / 2.0;
      return Rect.fromLTWH(0.0, topOffset, viewportSize.width, renderedHeight);
    } else {
      final double scaleH = viewportSize.height / pdfPageSize.height;
      final double renderedWidth = pdfPageSize.width * scaleH;
      final double leftOffset = (viewportSize.width - renderedWidth) / 2.0;
      return Rect.fromLTWH(leftOffset, 0.0, renderedWidth, viewportSize.height);
    }
  }

  /// Initializes the primary signature box at the bottom of the last page
  void _initFirstSignaturePlacement() {
    if (_initializedPosition || !mounted) return;
    final Size effectiveViewport = _viewportSize.width > 0 ? _viewportSize : MediaQuery.of(context).size;
    final int targetPage = _totalPages - 1;
    final bounds = _calculateRenderedPageBounds(targetPage, effectiveViewport);

    final double initialX = (bounds.right - _signatureWidth - 20.0).clamp(bounds.left, bounds.right - _signatureWidth);
    // Positioned neatly inside the white PDF page bottom
    final double initialY = (bounds.bottom - _signatureHeight - 32.0).clamp(bounds.top, bounds.bottom - _signatureHeight);

    setState(() {
      _placements.add(
        SignaturePlacement(
          id: '1',
          pageIndex: targetPage, // Place on final signature page
          x: initialX,
          y: initialY,
          isLocked: false,
        ),
      );
      _initializedPosition = true;
    });
  }

  /// Tap-to-Place handler: Snaps active signature directly under the user's tap
  void _handleTapToPlace(PdfGestureDetails details) {
    if (_isStamping || details.pageNumber == -1) return;

    final int tappedPageIndex = details.pageNumber - 1;
    final Size effectiveViewport = _viewportSize.width > 0 ? _viewportSize : MediaQuery.of(context).size;
    final bounds = _calculateRenderedPageBounds(tappedPageIndex, effectiveViewport);

    // Center the signature box on the tap coordinate strictly clamped within the PDF page
    final double targetX = (details.position.dx - (_signatureWidth / 2)).clamp(bounds.left, bounds.right - _signatureWidth);
    final double targetY = (details.position.dy - (_signatureHeight / 2)).clamp(bounds.top, bounds.bottom - _signatureHeight);

    setState(() {
      // Find an active (unlocked) signature placement on this page
      final activeIndex = _placements.indexWhere(
        (p) => p.pageIndex == tappedPageIndex && !p.isLocked,
      );

      if (activeIndex != -1) {
        // Snap the active signature directly to the tapped position!
        _placements[activeIndex].x = targetX;
        _placements[activeIndex].y = targetY;
      } else {
        // If all existing spots on this page are locked, add a new spot here
        for (final p in _placements) {
          p.isLocked = true;
        }
        _placements.add(
          SignaturePlacement(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            pageIndex: tappedPageIndex,
            x: targetX,
            y: targetY,
            isLocked: false,
          ),
        );
      }
    });
  }

  /// Adds a new signature box onto the visible page
  void _addSignaturePlacement() {
    final Size effectiveViewport = _viewportSize.width > 0 ? _viewportSize : MediaQuery.of(context).size;
    final bounds = _calculateRenderedPageBounds(_currentPage - 1, effectiveViewport);
    final double nextX = (bounds.left + 24.0 + (_placements.length * 16.0)).clamp(bounds.left, bounds.right - _signatureWidth);
    final double nextY = (bounds.top + (bounds.height * 0.45) + ((_placements.length * 30.0) % 100.0)).clamp(bounds.top, bounds.bottom - _signatureHeight);

    setState(() {
      // Auto-lock all previously placed signatures so they remain pinned and never shift!
      for (final p in _placements) {
        p.isLocked = true;
      }
      _placements.add(
        SignaturePlacement(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          pageIndex: _currentPage - 1,
          x: nextX,
          y: nextY,
          isLocked: false,
        ),
      );
    });
  }

  /// Removes a signature box
  void _removeSignaturePlacement(String id) {
    if (_placements.length <= 1) return; // Always keep at least one
    setState(() {
      _placements.removeWhere((p) => p.id == id);
    });
  }

  /// Authenticates with device fingerprint and stamps all placed signatures
  Future<void> _confirmAndStamp() async {
    if (!mounted || _placements.isEmpty) return;

    // 1. Mobile Biometric Fingerprint verification
    final bioResult = await BiometricAuthService.authenticateSigner();
    if (!bioResult.authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signing cancelled: ${bioResult.method}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isStamping = true);

    try {
      // 2. Open PDF and calculate exact page coordinate mappings
      final PdfDocument doc = PdfDocument(inputBytes: widget.pdfBytes);
      final int totalDocPages = doc.pages.count;
      final double screenWidth = MediaQuery.of(context).size.width;
      final Size effectiveViewport = _viewportSize.width > 0 ? _viewportSize : Size(screenWidth, MediaQuery.of(context).size.height);

      // 3. Compute PDF point locations for ALL placed signature boxes
      // Subtracts the page bounds top offset so there is NO extra top margin!
      final List<SignatureLocation> locations = [];
      for (final p in _placements) {
        final int targetPageIndex = p.pageIndex.clamp(0, totalDocPages - 1);
        final Size pdfPageSize = doc.pages[targetPageIndex].size;
        final bounds = _calculateRenderedPageBounds(targetPageIndex, effectiveViewport);

        final double scale = bounds.width / pdfPageSize.width;
        final double localX = (p.x - bounds.left).clamp(0.0, bounds.width - _signatureWidth);
        final double localY = (p.y - bounds.top).clamp(0.0, bounds.height - _signatureHeight);

        locations.add(
          SignatureLocation(
            pageIndex: targetPageIndex,
            x: localX / scale,
            y: localY / scale,
            width: _signatureWidth / scale,
            height: _signatureHeight / scale,
          ),
        );
      }
      doc.dispose();

      // Sort locations in document reading order: pageIndex ascending, then Y ascending
      // Guarantees the true final authorized signature receives the primary legal evidence
      locations.sort((a, b) {
        final int pageCmp = a.pageIndex.compareTo(b.pageIndex);
        if (pageCmp != 0) return pageCmp;
        return a.y.compareTo(b.y);
      });

      final primaryLoc = locations.last;

      // 4. Capture Signer IP Address and Document Cryptographic Hash
      final String signerIp = await AuditService.getSignerIpAddress();
      final String documentHash = AuditService.computeDocumentHash(widget.pdfBytes);

      // 5. Create formal SigningEvent record with legal evidence & biometric verification
      final SigningEvent signingEvent = SigningEvent(
        signingEventId: 'evt_${DateTime.now().millisecondsSinceEpoch}',
        userId: widget.userSession?.userId ?? 'usr_demo',
        userEmail: widget.userSession?.email ?? 'signer@example.com',
        documentTitle: widget.title,
        signatureId: 'sig_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        signedAt: DateTime.now().toUtc(),
        authenticationMethod: widget.userSession?.authMethod ?? 'Keycloak SSO (Google OAuth2 + PKCE)',
        biometricVerification: bioResult.method,
        ipAddress: signerIp,
        documentHash: documentHash,
        pageIndex: primaryLoc.pageIndex,
        x: primaryLoc.x,
        y: primaryLoc.y,
        width: primaryLoc.width,
        height: primaryLoc.height,
        status: 'COMPLETED',
      );

      // 6. Stamp ALL signature locations onto the document (Verification seal on LAST spot)
      final Uint8List signedPdfBytes = await PdfStampingService.stampSignatureWithAudit(
        pdfBytes: widget.pdfBytes,
        signatureBytes: widget.signatureBytes,
        signingEvent: signingEvent,
        locations: locations,
        attachCertificatePage: false,
      );

      // 7. Compute the cryptographic SHA-256 hash of the FINAL STAMPED PDF!
      final String signedPdfHash = AuditService.computeDocumentHash(signedPdfBytes);

      // 8. Save the signed document and update the existing draft in the list
      final DateTime now = DateTime.now();
      String rawName = widget.title;
      if (rawName.toLowerCase().endsWith('.pdf')) {
        rawName = rawName.substring(0, rawName.length - 4);
      }
      if (rawName.startsWith('Signed_')) {
        rawName = rawName.substring(7);
      }
      final String timeSuffix = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final String finalSignedTitle = 'Signed_${rawName}_$timeSuffix.pdf';
      final int hour12 = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final String ampm = now.hour >= 12 ? 'PM' : 'AM';
      final String minStr = now.minute.toString().padLeft(2, '0');

      await LocalDocumentService.saveDocument(
        title: finalSignedTitle,
        bytes: signedPdfBytes,
        status: DocumentStatus.signed,
        subtitle: locations.length > 1
            ? 'Signed with Fingerprint (${locations.length} spots) • $hour12:$minStr $ampm'
            : 'Signed with Fingerprint • $hour12:$minStr $ampm',
        replacesOriginalTitle: widget.title,
      );

      // 9. Sync audit trail record & trigger automated email with signed PDF attachment
      AuditService.recordSigningEvent(
        signingEvent,
        signedDocumentHash: signedPdfHash,
        signedPdfBytes: signedPdfBytes,
      );

      if (!mounted) return;

      // 10. Navigate to the Result Screen to view/save/share!
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SignedResultScreen(
            title: finalSignedTitle,
            signedPdfBytes: signedPdfBytes,
            signingEvent: signingEvent,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating signed PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isStamping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter placements that belong to the currently visible page
    final currentPagePlacements = _placements.where((p) => p.pageIndex == _currentPage - 1).toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          'Place Signature',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context),
          ),
        ),
        actions: [
          // "Add Spot" button with clean styling
          OutlinedButton.icon(
            onPressed: _isStamping ? null : _addSignaturePlacement,
            icon: const Icon(Icons.add, size: 16, color: AppTheme.primaryBlue),
            label: const Text(
              'Add Spot',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryBlue,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primaryBlue, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),

          // Confirm Placement button
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton.icon(
              onPressed: _isStamping ? null : _confirmAndStamp,
              icon: const Icon(Icons.check, size: 16),
              label: Text(_placements.length > 1 ? 'Confirm (${_placements.length})' : 'Confirm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              // Layer 1: Single-Page Static PDF View (Wrapped in Positioned.fill for tight constraints!)
              Positioned.fill(
                child: SfPdfViewer.memory(
                  widget.pdfBytes,
                  key: const ValueKey('pdf_viewer_widget'),
                  controller: _pdfViewerController,
                  pageLayoutMode: PdfPageLayoutMode.single,
                  scrollDirection: PdfScrollDirection.horizontal,
                  initialPageNumber: _currentPage,
                  canShowScrollHead: false,
                  canShowScrollStatus: false,
                  canShowPaginationDialog: false,
                  enableDoubleTapZooming: false,
                  onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _initFirstSignaturePlacement();
                      }
                    });
                  },
                  onPageChanged: (PdfPageChangedDetails details) {
                    if (mounted) {
                      setState(() {
                        _currentPage = details.newPageNumber;
                      });
                    }
                  },
                  onTap: _handleTapToPlace,
                ),
              ),

              // Layer 2: Stationed, Draggable & Tap-Placed Signatures on Current Page
              ...currentPagePlacements.map((p) {
                final int globalIndex = _placements.indexOf(p);
                final bool isLocked = p.isLocked;
                final bool isAuthorized = (p == _authorizedFinalPlacement);

                return Positioned(
                  left: p.x,
                  top: p.y,
                  child: Container(
                    width: _signatureWidth,
                    height: _signatureHeight,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isLocked ? Colors.green.shade600 : AppTheme.primaryBlue,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      color: AppTheme.cardBg(context).withValues(alpha: isLocked ? 0.90 : 0.96),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Draggable target: smooth 120 FPS drag bounded cleanly to the PDF page!
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: isLocked ? () => setState(() => p.isLocked = false) : null,
                          onPanStart: isLocked ? null : (_) {},
                          onPanUpdate: isLocked
                              ? null
                              : (DragUpdateDetails details) {
                                  final bounds = _calculateRenderedPageBounds(p.pageIndex, _viewportSize);
                                  setState(() {
                                    p.x = (p.x + details.delta.dx).clamp(bounds.left, bounds.right - _signatureWidth);
                                    p.y = (p.y + details.delta.dy).clamp(bounds.top, bounds.bottom - _signatureHeight);
                                  });
                                },
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
                        child: Center(
                          child: Image.memory(
                            widget.signatureBytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    // Status badge in top-left
                    Positioned(
                      left: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => p.isLocked = !p.isLocked),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isLocked ? Colors.green.shade700 : AppTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLocked ? Icons.lock : (isAuthorized ? Icons.verified : Icons.drag_indicator),
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isLocked
                                    ? (isAuthorized ? '#${globalIndex + 1} Authorized ✓' : '#${globalIndex + 1} Placed')
                                    : (isAuthorized ? '#${globalIndex + 1} • Authorized Sign + Verify' : '#${globalIndex + 1} • Initial / Sign'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Actions in top-right: Lock toggle & Delete button
                    Positioned(
                      top: 3,
                      right: 3,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Lock / Pin button
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => p.isLocked = !p.isLocked),
                            child: Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isLocked ? Colors.green.shade100 : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isLocked ? Icons.lock : Icons.lock_open,
                                size: 12,
                                color: isLocked ? Colors.green.shade800 : Colors.black54,
                              ),
                            ),
                          ),
                          if (_placements.length > 1) ...[
                            const SizedBox(width: 4),
                            // Delete (X) button
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _removeSignaturePlacement(p.id),
                              child: Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Drag handle icon in bottom right (only visible when moveable)
                    if (!isLocked)
                      Positioned(
                        right: 3,
                        bottom: 3,
                        child: IgnorePointer(
                          child: Icon(
                            Icons.open_with,
                            size: 13,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),

          // Layer 3: Top helper tip banner
          Positioned(
            top: 10,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _placements.length > 1
                            ? 'Tap line to place • Drag to fine-tune'
                            : 'Tap signature line to snap • Drag to adjust',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Layer 4: Multi-page navigation pill (lifted safely above Android/iOS system gesture bars)
          if (_totalPages > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 22,
              left: 24,
              right: 24,
              child: Center(
                child: Material(
                  elevation: 6,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.borderColor(context).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                          onPressed: _currentPage > 1
                              ? () => _pdfViewerController.previousPage()
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Page $_currentPage of $_totalPages',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                          onPressed: _currentPage < _totalPages
                              ? () => _pdfViewerController.nextPage()
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Layer 5: Loading indicator while stamping
          if (_isStamping)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    },
  ),
);
  }
}
