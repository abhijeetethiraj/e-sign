import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'docx_converter_service.dart';

/// Service responsible for picking documents from the user's device.
/// Keeps file-system logic isolated from the UI widgets.
class PdfPickerService {
  /// Opens the native OS file picker filtered strictly to Word documents (.docx, .doc).
  /// Automatically converts the Word document on-device into a PDF ready for signing.
  static Future<({String name, Uint8List bytes, String originalName})?> pickWordDocument() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['docx', 'doc'], // Strictly Word documents only
      );

      if (file == null) {
        return null;
      }

      final Uint8List docBytes = await file.readAsBytes();

      // Convert Word document to PDF directly on device
      final Uint8List pdfBytes = await DocxConverterService.convertToPdf(
        docBytes,
        originalFileName: file.name,
      );

      final String baseName = file.name.replaceAll(RegExp(r'\.(docx|doc)$', caseSensitive: false), '');
      final String pdfFileName = '$baseName.pdf';

      return (name: pdfFileName, bytes: pdfBytes, originalName: file.name);
    } catch (e) {
      return null;
    }
  }

  /// Opens the native OS file picker filtered to PDF files (used for verifying signed documents).
  static Future<({String name, Uint8List bytes})?> pickPdf() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (file == null) {
        return null;
      }

      final Uint8List bytes = await file.readAsBytes();
      return (name: file.name, bytes: bytes);
    } catch (e) {
      return null;
    }
  }
}
