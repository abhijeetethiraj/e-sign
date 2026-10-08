import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class SamplePdfService {
  /// Generates a clean 1-page sample agreement in memory
  static Future<Uint8List> generateSampleNda() async {
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();

    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont headingFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);

    // Document Title
    page.graphics.drawString(
      'MUTUAL NON-DISCLOSURE AGREEMENT',
      titleFont,
      bounds: const Rect.fromLTWH(0, 30, 500, 30),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    // Divider
    page.graphics.drawLine(
      PdfPen(PdfColor(200, 200, 200), width: 1),
      const Offset(0, 70),
      const Offset(500, 70),
    );

    // Terms
    page.graphics.drawString(
      '1. CONFIDENTIAL INFORMATION',
      headingFont,
      bounds: const Rect.fromLTWH(0, 90, 500, 20),
    );
    page.graphics.drawString(
      'The parties agree that any technical, commercial, or financial information '
      'disclosed under this Agreement shall remain strictly confidential.',
      bodyFont,
      bounds: const Rect.fromLTWH(0, 115, 500, 40),
    );

    // Signature Box
    page.graphics.drawString(
      'SIGNATURE AREA',
      headingFont,
      bounds: const Rect.fromLTWH(0, 200, 500, 20),
    );
    page.graphics.drawRectangle(
      pen: PdfPen(PdfColor(180, 180, 180), width: 1),
      bounds: const Rect.fromLTWH(0, 230, 300, 90),
    );
    page.graphics.drawString(
      'Place Signature Here',
      PdfStandardFont(PdfFontFamily.helvetica, 9),
      brush: PdfSolidBrush(PdfColor(150, 150, 150)),
      bounds: const Rect.fromLTWH(10, 240, 280, 20),
    );

    final List<int> bytes = await document.save();
    document.dispose();
    return Uint8List.fromList(bytes);
  }
}
