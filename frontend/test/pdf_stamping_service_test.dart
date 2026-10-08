import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:frontend/models/signing_event.dart';
import 'package:frontend/services/pdf_stamping_service.dart';

void main() {
  // A minimal valid 1x1 PNG image in raw bytes (RGBA)
  final Uint8List samplePngBytes = Uint8List.fromList([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
    0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84,
    120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78,
    68, 174, 66, 96, 130
  ]);

  // Helper function to create an in-memory 1-page PDF
  Uint8List createSamplePdf({int pageCount = 1}) {
    final doc = PdfDocument();
    for (int i = 0; i < pageCount; i++) {
      final page = doc.pages.add();
      page.graphics.drawString(
        'Contract Page ${i + 1}',
        PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(50, 50, 200, 20),
      );
    }
    final bytes = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return bytes;
  }

  // Sample legal signing event
  final sampleEvent = SigningEvent(
    signingEventId: 'EVT-TEST-12345',
    userId: 'usr_abc_999',
    userEmail: 'qa.engineer@company.test',
    documentTitle: 'Non-Disclosure Agreement',
    signatureId: 'sig_marker_888',
    signedAt: DateTime.utc(2026, 10, 8, 10, 30),
    ipAddress: '192.168.1.42',
    documentHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    pageIndex: 0,
    x: 100,
    y: 200,
    width: 120,
    height: 45,
  );

  group('PdfStampingService QA Test Suite', () {
    test('1. [Happy Path] Stamps signature on a single-page PDF without altering page count', () async {
      // ARRANGE
      final originalPdf = createSamplePdf(pageCount: 1);

      // ACT
      final stampedPdf = await PdfStampingService.stampSignatureWithAudit(
        pdfBytes: originalPdf,
        signatureBytes: samplePngBytes,
        signingEvent: sampleEvent,
        attachCertificatePage: false,
      );

      // ASSERT
      expect(stampedPdf, isNotNull);
      // Valid PDF magic header check '%PDF'
      final header = utf8.decode(stampedPdf.sublist(0, 4));
      expect(header, equals('%PDF'));

      // Verify the page count remains exactly 1
      final doc = PdfDocument(inputBytes: stampedPdf);
      expect(doc.pages.count, equals(1));
      doc.dispose();
    });

    test('2. [Audit Trail] Appends Certificate of Completion page when requested', () async {
      // ARRANGE
      final originalPdf = createSamplePdf(pageCount: 1);

      // ACT: Stamp with attachCertificatePage = true
      final stampedPdf = await PdfStampingService.stampSignatureWithAudit(
        pdfBytes: originalPdf,
        signatureBytes: samplePngBytes,
        signingEvent: sampleEvent,
        attachCertificatePage: true,
      );

      // ASSERT: Page count should increment from 1 to 2
      final doc = PdfDocument(inputBytes: stampedPdf);
      expect(doc.pages.count, equals(2));
      doc.dispose();
    });

    test('3. [Multi-Spot] Supports placing multiple signature spots across pages', () async {
      // ARRANGE: A 2-page document
      final originalPdf = createSamplePdf(pageCount: 2);
      final multipleSpots = [
        const SignatureLocation(pageIndex: 0, x: 50, y: 100, width: 100, height: 40),
        const SignatureLocation(pageIndex: 1, x: 50, y: 150, width: 100, height: 40),
      ];

      // ACT
      final stampedPdf = await PdfStampingService.stampSignatureWithAudit(
        pdfBytes: originalPdf,
        signatureBytes: samplePngBytes,
        signingEvent: sampleEvent,
        locations: multipleSpots,
        attachCertificatePage: false,
      );

      // ASSERT
      expect(stampedPdf, isNotNull);
      final doc = PdfDocument(inputBytes: stampedPdf);
      expect(doc.pages.count, equals(2));
      doc.dispose();
    });

    test('4. [Edge Case / Boundary] Clamps out-of-bounds page index gracefully', () async {
      // ARRANGE: 1-page document, but location points to invalid page index 99
      final originalPdf = createSamplePdf(pageCount: 1);
      final outOfBoundsSpot = [
        const SignatureLocation(pageIndex: 99, x: 50, y: 100, width: 100, height: 40),
      ];

      // ACT & ASSERT: Must not throw IndexOutOfBoundsException, should clamp safely to page 0
      final stampedPdf = await PdfStampingService.stampSignatureWithAudit(
        pdfBytes: originalPdf,
        signatureBytes: samplePngBytes,
        signingEvent: sampleEvent,
        locations: outOfBoundsSpot,
      );

      expect(stampedPdf, isNotNull);
      final doc = PdfDocument(inputBytes: stampedPdf);
      expect(doc.pages.count, equals(1));
      doc.dispose();
    });
  });
}
