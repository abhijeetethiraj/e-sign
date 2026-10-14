import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

/// Represents an extracted paragraph from a Word document
class _DocxParagraph {
  final String text;
  final bool isHeading;
  final bool isBold;

  _DocxParagraph({
    required this.text,
    this.isHeading = false,
    this.isBold = false,
  });
}

/// Service that parses Word documents (.docx / .doc) and converts them
/// directly on-device into high-quality PDFs for previewing and e-signing.
class DocxConverterService {
  /// Converts Word document bytes (.docx or .doc) into PDF bytes.
  static Future<Uint8List> convertToPdf(
    Uint8List docBytes, {
    String? originalFileName,
  }) async {
    // 1. Try parsing as modern .docx (OpenXML ZIP archive)
    try {
      final List<_DocxParagraph> paragraphs = _parseDocx(docBytes);
      if (paragraphs.isNotEmpty) {
        return await _generatePdfFromParagraphs(
          paragraphs,
          title: originalFileName ?? 'Word Document',
        );
      }
    } catch (e) {
      debugPrint('[DocxConverter] Standard docx parse error: $e');
    }

    // 2. Fallback for legacy .doc or raw text Word files
    final String extractedText = _extractTextFallback(docBytes);
    final List<_DocxParagraph> fallbackParagraphs = extractedText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => _DocxParagraph(text: line))
        .toList();

    if (fallbackParagraphs.isEmpty) {
      fallbackParagraphs.add(
        _DocxParagraph(
          text: 'Uploaded Document: ${originalFileName ?? "Word Document"}',
          isHeading: true,
        ),
      );
      fallbackParagraphs.add(
        _DocxParagraph(
          text: 'This Word document has been imported for electronic signature placement.',
        ),
      );
    }

    return await _generatePdfFromParagraphs(
      fallbackParagraphs,
      title: originalFileName ?? 'Word Document',
    );
  }

  /// Parses modern .docx ZIP container and extracts paragraphs from word/document.xml
  static List<_DocxParagraph> _parseDocx(Uint8List docxBytes) {
    final Archive archive = ZipDecoder().decodeBytes(docxBytes);
    final ArchiveFile? documentFile = archive.findFile('word/document.xml');

    if (documentFile == null) {
      throw Exception('word/document.xml not found in archive');
    }

    final String xmlContent = utf8.decode(documentFile.content as List<int>);
    final XmlDocument xmlDoc = XmlDocument.parse(xmlContent);

    final List<_DocxParagraph> paragraphs = [];

    // Find all paragraph elements (<w:p>)
    final pElements = xmlDoc.findAllElements('w:p');
    for (final p in pElements) {
      // Check paragraph style for headings
      final pStyle = p.findAllElements('w:pStyle').firstOrNull;
      final String? styleVal = pStyle?.getAttribute('w:val');
      final bool isHeading = styleVal != null &&
          (styleVal.toLowerCase().contains('heading') ||
              styleVal.toLowerCase().contains('title'));

      // Check bold tags in run properties
      final hasBold = p.findAllElements('w:b').isNotEmpty;

      // Extract text from all text tags (<w:t>)
      final StringBuffer pText = StringBuffer();
      for (final t in p.findAllElements('w:t')) {
        pText.write(t.innerText);
      }

      final String fullText = pText.toString().trim();
      if (fullText.isNotEmpty) {
        paragraphs.add(
          _DocxParagraph(
            text: fullText,
            isHeading: isHeading,
            isBold: hasBold,
          ),
        );
      }
    }

    return paragraphs;
  }

  /// Fallback extractor for legacy binary .doc or plain text
  static String _extractTextFallback(Uint8List bytes) {
    final StringBuffer sb = StringBuffer();
    // Scan ASCII printable characters and spaces
    for (final b in bytes) {
      if ((b >= 32 && b <= 126) || b == 10 || b == 13 || b == 9) {
        sb.writeCharCode(b);
      }
    }
    return sb.toString();
  }

  /// Renders extracted Word paragraphs into a multi-page PDF document
  static Future<Uint8List> _generatePdfFromParagraphs(
    List<_DocxParagraph> paragraphs, {
    required String title,
  }) async {
    final PdfDocument pdfDoc = PdfDocument();
    pdfDoc.pageSettings.margins.all = 40;

    PdfPage page = pdfDoc.pages.add();
    final double pageWidth = page.getClientSize().width;
    final double pageHeight = page.getClientSize().height;

    final PdfFont titleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont headingFont =
        PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    final PdfFont boldFont =
        PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);

    double currentY = 0;

    // Draw Document Title Banner
    final String cleanTitle =
        title.replaceAll(RegExp(r'\.(docx|doc)$', caseSensitive: false), '');
    page.graphics.drawString(
      cleanTitle,
      titleFont,
      bounds: Rect.fromLTWH(0, currentY, pageWidth, 28),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      brush: PdfSolidBrush(PdfColor(15, 23, 42)),
    );
    currentY += 34;

    // Divider bar
    page.graphics.drawLine(
      PdfPen(PdfColor(203, 213, 225), width: 1),
      Offset(0, currentY),
      Offset(pageWidth, currentY),
    );
    currentY += 16;

    // Layout each paragraph sequentially
    for (final p in paragraphs) {
      final PdfFont font = p.isHeading
          ? headingFont
          : (p.isBold ? boldFont : bodyFont);

      final PdfColor textColor = p.isHeading
          ? PdfColor(30, 41, 59)
          : PdfColor(51, 65, 85);

      final PdfTextElement element = PdfTextElement(
        text: p.text,
        font: font,
        brush: PdfSolidBrush(textColor),
      );

      element.stringFormat = PdfStringFormat(
        lineSpacing: 3,
        wordWrap: PdfWordWrapType.word,
      );

      // Check if current page is nearly full before drawing
      if (currentY > pageHeight - 50) {
        page = pdfDoc.pages.add();
        currentY = 10;
      }

      final PdfLayoutResult? result = element.draw(
        page: page,
        bounds: Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
        format: PdfLayoutFormat(
          layoutType: PdfLayoutType.paginate,
          breakType: PdfLayoutBreakType.fitPage,
        ),
      );

      if (result != null) {
        page = result.page;
        currentY = result.bounds.bottom + (p.isHeading ? 14 : 8);
      } else {
        currentY += 20;
      }
    }

    // Add signature placement guide area on the last page
    if (currentY + 90 > pageHeight) {
      page = pdfDoc.pages.add();
      currentY = 20;
    } else {
      currentY += 30;
    }

    page.graphics.drawString(
      'AUTHORIZED SIGNATURE',
      PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(148, 163, 184)),
      bounds: Rect.fromLTWH(pageWidth - 200, currentY, 200, 14),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    page.graphics.drawLine(
      PdfPen(PdfColor(203, 213, 225), width: 1),
      Offset(pageWidth - 200, currentY + 18),
      Offset(pageWidth, currentY + 18),
    );

    final List<int> pdfBytes = await pdfDoc.save();
    pdfDoc.dispose();

    return Uint8List.fromList(pdfBytes);
  }
}
