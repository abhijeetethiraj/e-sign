import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/document_item.dart';
import '../models/user_session.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/audit_service.dart';
import '../services/local_document_service.dart';
import '../services/pdf_picker_service.dart';
import '../widgets/document_card.dart';
import 'login_screen.dart';
import 'pdf_viewer_screen.dart';

/// The main dashboard screen displaying saved, persistent documents.
/// Documents are saved permanently to the device's storage (WhatsApp / Adobe style).
class DocumentsScreen extends StatefulWidget {
  final UserSession? userSession;

  const DocumentsScreen({
    super.key,
    this.userSession,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  int _selectedFilterIndex = 0; // 0 = All, 1 = Ready to Sign, 2 = Signed
  bool _isLoading = false;

  // Real, persistent documents loaded from device storage
  List<DocumentItem> _documents = [];

  @override
  void initState() {
    super.initState();
    _loadSavedDocuments();
  }

  /// Loads all persistent documents saved on the device's physical storage
  Future<void> _loadSavedDocuments() async {
    setState(() => _isLoading = true);
    try {
      await LocalDocumentService.cleanupDuplicates();
      final docs = await LocalDocumentService.getAllDocuments();
      if (mounted) {
        setState(() {
          _documents = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DocumentsScreen] Error loading documents: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Handles picking a Word document (.docx, .doc), converting it to PDF, and opening it
  Future<void> _uploadWordDocFromDevice() async {
    setState(() => _isLoading = true);

    try {
      final picked = await PdfPickerService.pickWordDocument();
      if (!mounted) return;

      if (picked != null) {
        // Save permanently to device storage as converted PDF
        final savedDoc = await LocalDocumentService.saveDocument(
          title: picked.name,
          bytes: picked.bytes,
          status: DocumentStatus.readyToSign,
          subtitle: 'Word doc: ${picked.originalName}',
        );

        await _loadSavedDocuments();

        if (!mounted) return;

        // Open the newly saved document in the viewer
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              title: savedDoc.title,
              pdfBytes: savedDoc.pdfBytes!,
              userSession: widget.userSession,
              isSigned: false,
            ),
          ),
        );

        // Reload list upon return (in case user signed it!)
        _loadSavedDocuments();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing Word document: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Handles tapping any document in the list
  Future<void> _openDocument(DocumentItem item) async {
    if (item.pdfBytes == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          title: item.title,
          pdfBytes: item.pdfBytes!,
          userSession: widget.userSession,
          isSigned: item.status == DocumentStatus.signed,
        ),
      ),
    );

    // Refresh upon return to reflect any new signatures
    _loadSavedDocuments();
  }

  /// Triggers the native share sheet directly for any document
  Future<void> _shareDocument(DocumentItem item) async {
    if (item.pdfBytes == null) return;
    try {
      await LocalDocumentService.shareDocument(
        title: item.title,
        bytes: item.pdfBytes!,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share document: $e')),
      );
    }
  }

  /// Removes a document from the app and refreshes the catalog
  Future<void> _deleteDocument(DocumentItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Document'),
        content: Text('Remove "${item.title}" from eSign? Your original file on your phone remains safe.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await LocalDocumentService.deleteDocument(item.id);
      _loadSavedDocuments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "${item.title}" from eSign')),
      );
    }
  }

  /// Allows the user to select any PDF and instantly verify its authenticity against the audit ledger
  Future<void> _verifyDocumentFromPicker() async {
    final picked = await PdfPickerService.pickPdf();
    if (picked == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await AuditService.verifyDocument(picked.bytes);

    if (!mounted) return;
    Navigator.of(context).pop(); // Dismiss loading spinner

    _showVerificationModal(picked.name, result);
  }

  void _showVerificationModal(
    String fileName,
    ({bool verified, String status, Map<String, dynamic>? event, String message}) result,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: result.verified ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      result.verified ? Icons.verified : Icons.gpp_bad_outlined,
                      color: result.verified ? Colors.green.shade700 : Colors.red.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.verified ? 'Signature Verified & Authentic' : 'Verification Failed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: result.verified ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                        Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              if (result.verified && result.event != null) ...[
                _buildVerifyRow('Signer Email', result.event!['userEmail']?.toString() ?? 'N/A'),
                _buildVerifyRow('Biometric Proof', result.event!['biometricVerification']?.toString() ?? 'N/A', isGreen: true),
                _buildVerifyRow('Signer IP', result.event!['ipAddress']?.toString() ?? 'N/A'),
                _buildVerifyRow('Signed At', result.event!['signedAt']?.toString() ?? 'N/A'),
                _buildVerifyRow('Status', 'VALID & UNTAMPERED', isBold: true),
                _buildVerifyRow('Document SHA-256', result.event!['documentHash']?.toString() ?? 'N/A', isMonospace: true),
              ] else ...[
                Text(
                  result.message,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Warning: This document either was not recorded in the eSign audit registry or its bytes were modified after signature.',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: result.verified ? AppTheme.primaryBlue : Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyRow(String label, String value, {bool isBold = false, bool isGreen = false, bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
                color: isGreen ? Colors.green.shade700 : (isBold ? AppTheme.primaryBlue : AppTheme.textDark),
                fontFamily: isMonospace ? 'Courier' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DocumentItem> get _filteredDocuments {
    if (_selectedFilterIndex == 1) {
      return _documents.where((d) => d.status == DocumentStatus.readyToSign).toList();
    } else if (_selectedFilterIndex == 2) {
      return _documents.where((d) => d.status == DocumentStatus.signed).toList();
    }
    return _documents;
  }

  @override
  Widget build(BuildContext context) {
    final int signedCount = _documents.where((d) => d.status == DocumentStatus.signed).length;
    final int readyCount = _documents.where((d) => d.status == DocumentStatus.readyToSign).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.draw_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'eSign',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary(context),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          // Theme Switcher Toggle (Light Mode ↔ Dark Mode)
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              final bool isDark = themeProvider.isDarkMode;
              return IconButton(
                tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: AppTheme.textPrimary(context),
                ),
                onPressed: () => themeProvider.toggleTheme(),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh documents',
            icon: Icon(Icons.refresh, color: AppTheme.textPrimary(context)),
            onPressed: _loadSavedDocuments,
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: CircleAvatar(
              radius: 17,
              backgroundColor: AppTheme.primaryBlue,
              child: Text(
                (widget.userSession?.displayName ?? 'U')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            onSelected: (value) async {
              if (value == 'toggle_theme') {
                context.read<ThemeProvider>().toggleTheme();
              } else if (value == 'logout') {
                final authProvider = context.read<AuthProvider>();
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userSession?.displayName ?? 'Authenticated User',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
                    ),
                    Text(
                      widget.userSession?.email ?? '',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'toggle_theme',
                child: Row(
                  children: [
                    Icon(
                      context.read<ThemeProvider>().isDarkMode
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      size: 18,
                      color: AppTheme.textPrimary(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.read<ThemeProvider>().isDarkMode ? 'Light Mode' : 'Dark Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadSavedDocuments,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Documents count & STORAGE tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Documents ',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            TextSpan(
                              text: '(${_documents.length})',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.badgeReadyBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ON-DEVICE STORAGE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons: Upload Doc & Verify PDF
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _uploadWordDocFromDevice,
                          icon: const Icon(Icons.description_outlined, size: 18),
                          label: const Text(
                            'Upload Doc',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _verifyDocumentFromPicker,
                          icon: const Icon(Icons.verified_user_outlined, size: 18, color: AppTheme.primaryBlue),
                          label: const Text(
                            'Verify PDF',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Filter Chips: All, Ready to Sign, Signed
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(0, 'All (${_documents.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip(1, 'Ready to Sign ($readyCount)'),
                        const SizedBox(width: 8),
                        _buildFilterChip(2, 'Signed ($signedCount)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Empty State or Document List
                  if (_filteredDocuments.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderColor(context)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryBg(context),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.folder_open_outlined,
                              size: 36,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No documents found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap "Upload Doc" above to pick a Word document (.docx/.doc) and sign it electronically.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context)),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ..._filteredDocuments.map(
                      (doc) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Dismissible(
                          key: Key(doc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.delete_outline, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          confirmDismiss: (dir) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Document'),
                                content: Text('Delete "${doc.title}" from device storage?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (_) async {
                            await LocalDocumentService.deleteDocument(doc.id);
                            _loadSavedDocuments();
                          },
                          child: GestureDetector(
                            onLongPress: () => _deleteDocument(doc),
                            child: DocumentCard(
                              item: doc,
                              onTap: () => _openDocument(doc),
                              onShare: () => _shareDocument(doc),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Information Hint Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor(context)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone_android, size: 16, color: AppTheme.textSecondary(context)),
                          const SizedBox(width: 8),
                          Text(
                            'Documents saved locally on your device',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final bool isSelected = _selectedFilterIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilterIndex = index),
      selectedColor: AppTheme.primaryBlue,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppTheme.textPrimary(context),
      ),
      backgroundColor: AppTheme.cardBg(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.borderColor(context),
        ),
      ),
      showCheckmark: false,
    );
  }
}
