import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document_item.dart';
import 'sample_pdf_service.dart';

/// Service responsible for managing permanent local document storage on the device.
/// Stores physical PDF files in the app's documents directory and persists
/// metadata in a JSON catalog (similar to WhatsApp media / Adobe Acrobat).
class LocalDocumentService {
  static const String _keyManifest = 'local_documents_manifest';
  static const String _keySeeded = 'has_seeded_sample_v1';
  static const String _folderName = 'eSign_Documents';

  /// Returns the dedicated directory for storing eSign PDFs on the device
  static Future<Directory> _getStorageDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final signDir = Directory('${baseDir.path}/$_folderName');
    if (!await signDir.exists()) {
      await signDir.create(recursive: true);
    }
    return signDir;
  }

  /// Formats current date and time for display (e.g. "Oct 7, 1:28 PM")
  static String _formatCurrentDate() {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final int hour12 = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final String ampm = now.hour >= 12 ? 'PM' : 'AM';
    final String minute = now.minute.toString().padLeft(2, '0');
    return '${months[now.month - 1]} ${now.day}, $hour12:$minute $ampm';
  }

  /// Exports a PDF file directly to the device's public Downloads directory
  /// so it can be found in Android's Files / Downloads app!
  static Future<String?> exportToDownloads({
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        final publicDownload = Directory('/storage/emulated/0/Download');
        if (await publicDownload.exists()) {
          downloadsDir = publicDownload;
        } else {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir != null) {
        String cleanName = fileName.trim();
        if (!cleanName.toLowerCase().endsWith('.pdf')) {
          cleanName = '$cleanName.pdf';
        }

        final File target = File('${downloadsDir.path}/$cleanName');
        await target.writeAsBytes(bytes, flush: true);
        debugPrint('[Export] Saved directly to Downloads: ${target.path}');
        return target.path;
      }
    } catch (e) {
      debugPrint('[Export] Error saving to downloads: $e');
    }
    return null;
  }

  /// Opens the native operating system share sheet (WhatsApp, Gmail, Drive, AirDrop, etc.)
  /// for a document's byte data.
  static Future<void> shareDocument({
    required String title,
    required Uint8List bytes,
  }) async {
    final Directory tempDir = await getTemporaryDirectory();
    String cleanName = title.trim();
    if (!cleanName.toLowerCase().endsWith('.pdf')) {
      cleanName = '$cleanName.pdf';
    }

    final File tempFile = File('${tempDir.path}/$cleanName');
    await tempFile.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(tempFile.path)],
        subject: cleanName,
        text: 'Sharing signed document: $cleanName',
      ),
    );
  }

  /// Private helper to read manifest JSON directly without triggering any recursion
  static List<DocumentItem> _readManifestFromPrefs(SharedPreferences prefs) {
    final String? manifestJson = prefs.getString(_keyManifest);
    if (manifestJson == null || manifestJson.isEmpty) return [];

    try {
      final List<dynamic> decoded = jsonDecode(manifestJson) as List<dynamic>;
      return decoded.map((item) => DocumentItem.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[LocalStorage] Error parsing manifest: $e');
      return [];
    }
  }

  /// Private helper to write manifest JSON directly
  static Future<void> _writeManifestToPrefs(
    SharedPreferences prefs,
    List<DocumentItem> items,
  ) async {
    final List<Map<String, dynamic>> jsonList = items.map((d) => d.toJson()).toList();
    await prefs.setString(_keyManifest, jsonEncode(jsonList));
  }

  /// Saves a PDF document to physical device storage and updates the local catalog.
  /// If [replacesOriginalTitle] is provided, removes the unsigned draft so the user only has 1 updated document.
  static Future<DocumentItem> saveDocument({
    required String title,
    required Uint8List bytes,
    required DocumentStatus status,
    String? subtitle,
    String? replacesOriginalTitle,
  }) async {
    final dir = await _getStorageDirectory();
    final String docId = 'doc_${DateTime.now().millisecondsSinceEpoch}';

    // Ensure clean filename
    String safeTitle = title.trim();
    if (!safeTitle.toLowerCase().endsWith('.pdf')) {
      safeTitle = '$safeTitle.pdf';
    }

    final String filePath = '${dir.path}/${docId}_$safeTitle';
    final File file = File(filePath);

    // 1. Write bytes to physical storage on the device
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('[LocalStorage] Saved ${bytes.length} bytes to $filePath');

    final String autoSubtitle = subtitle ??
        (status == DocumentStatus.signed ? 'Signed & Verified' : 'Ready to sign');

    final newItem = DocumentItem(
      id: docId,
      title: safeTitle,
      subtitle: autoSubtitle,
      date: _formatCurrentDate(),
      status: status,
      filePath: filePath,
      pdfBytes: bytes,
    );

    // 2. Update metadata manifest directly in SharedPreferences (NO recursion)
    final prefs = await SharedPreferences.getInstance();
    final List<DocumentItem> existing = _readManifestFromPrefs(prefs);

    // If replacing an existing unsigned draft, remove the old draft from manifest
    if (replacesOriginalTitle != null && replacesOriginalTitle.isNotEmpty) {
      existing.removeWhere((d) {
        final String orig = replacesOriginalTitle.trim().toLowerCase();
        final String current = d.title.trim().toLowerCase();
        return current == orig ||
            current == 'signed_$orig' ||
            orig == 'signed_$current';
      });
    }

    // Remove any duplicate with the exact same ID or file path
    existing.removeWhere((d) => d.filePath == filePath);
    existing.insert(0, newItem);

    await _writeManifestToPrefs(prefs, existing);
    return newItem;
  }

  /// Retrieves all saved documents from device storage.
  /// If the user has no documents yet, seeds the initial preloaded sample NDA ONCE.
  static Future<List<DocumentItem>> getAllDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final List<DocumentItem> manifestItems = _readManifestFromPrefs(prefs);

    final List<DocumentItem> verifiedDocs = [];

    // Verify files on disk and load bytes
    for (final doc in manifestItems) {
      if (doc.filePath != null) {
        final file = File(doc.filePath!);
        if (await file.exists()) {
          doc.pdfBytes = await file.readAsBytes();
          verifiedDocs.add(doc);
        }
      }
    }

    // If documents exist, return them immediately
    if (verifiedDocs.isNotEmpty) {
      return verifiedDocs;
    }

    // Check if we already seeded previously
    final bool alreadySeeded = prefs.getBool(_keySeeded) ?? false;
    if (alreadySeeded) {
      return [];
    }

    // Seed the sample NDA document ONCE on fresh installation
    await prefs.setBool(_keySeeded, true);
    try {
      final sampleBytes = await SamplePdfService.generateSampleNda();
      final sampleDoc = await saveDocument(
        title: 'Sample_NDA_Agreement.pdf',
        bytes: sampleBytes,
        status: DocumentStatus.readyToSign,
        subtitle: 'Sample contract ready to sign',
      );
      return [sampleDoc];
    } catch (e) {
      debugPrint('[LocalStorage] Could not seed sample document: $e');
      return [];
    }
  }

  /// Deletes a document from physical device storage and removes it from the catalog
  static Future<void> deleteDocument(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<DocumentItem> existing = _readManifestFromPrefs(prefs);

    DocumentItem? toRemove;
    for (final doc in existing) {
      if (doc.id == id) {
        toRemove = doc;
        break;
      }
    }

    if (toRemove != null) {
      // 1. Delete physical file from disk
      if (toRemove.filePath != null) {
        try {
          final file = File(toRemove.filePath!);
          if (await file.exists()) {
            await file.delete();
            debugPrint('[LocalStorage] Deleted file: ${toRemove.filePath}');
          }
        } catch (e) {
          debugPrint('[LocalStorage] Error deleting physical file: $e');
        }
      }

      // 2. Update manifest
      existing.removeWhere((d) => d.id == id);
      await _writeManifestToPrefs(prefs, existing);
    }
  }

  /// Cleans up any accidental duplicates in the storage folder
  static Future<void> cleanupDuplicates() async {
    final prefs = await SharedPreferences.getInstance();
    final List<DocumentItem> existing = _readManifestFromPrefs(prefs);

    final Set<String> seenTitles = {};
    final List<DocumentItem> uniqueDocs = [];

    for (final doc in existing) {
      if (!seenTitles.contains(doc.title)) {
        seenTitles.add(doc.title);
        uniqueDocs.add(doc);
      } else {
        // Delete redundant duplicate file
        if (doc.filePath != null) {
          try {
            final f = File(doc.filePath!);
            if (await f.exists()) await f.delete();
          } catch (_) {}
        }
      }
    }

    await _writeManifestToPrefs(prefs, uniqueDocs);
  }

  /// Deletes all locally saved documents, physical PDF files, and clears the manifest.
  /// Used when an account is deleted to ensure zero lingering data.
  static Future<void> clearAllDocuments() async {
    try {
      final signDir = await _getStorageDirectory();
      if (await signDir.exists()) {
        await signDir.delete(recursive: true);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyManifest);
      await prefs.remove(_keySeeded);
    } catch (e) {
      debugPrint('[LocalDocumentService] Error clearing all documents: $e');
    }
  }
}
