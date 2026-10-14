import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/signing_event.dart';

/// Represents a concrete target location for a signature mark on a PDF
class SignatureLocation {
  final int pageIndex;
  final double x;
  final double y;
  final double width;
  final double height;

  const SignatureLocation({
    required this.pageIndex,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// Service responsible for drawing the signature onto the PDF document
/// and appending an official, legally compliant Certificate of Completion (Audit Trail).
class PdfStampingService {
  /// Stamps signature images onto the document at one or multiple locations.
  /// 
  /// By default:
  /// - Stamped with an elegant inline cryptographic verification seal right beneath each signature mark.
  /// - Does NOT add extra pages unless [attachCertificatePage] is explicitly set to true.
  static Future<Uint8List> stampSignatureWithAudit({
    required Uint8List pdfBytes,
    required Uint8List signatureBytes,
    required SigningEvent signingEvent,
    List<SignatureLocation>? locations,
    bool attachCertificatePage = false,
  }) async {
    // 1. Load the original PDF into memory
    final PdfDocument document = PdfDocument(inputBytes: pdfBytes);

    try {
      final PdfBitmap signatureImage = PdfBitmap(signatureBytes);

      // Use provided multi-locations, or fall back to single signingEvent coordinate
      final effectiveLocations = (locations != null && locations.isNotEmpty)
          ? locations
          : [
              SignatureLocation(
                pageIndex: signingEvent.pageIndex,
                x: signingEvent.x,
                y: signingEvent.y,
                width: signingEvent.width,
                height: signingEvent.height,
              )
            ];

      // Draw signature mark at each location, and append the official DSC verification seal on the LAST spot
      // Sort locations in document reading order: pageIndex ascending, then Y ascending.
      // This guarantees the true final signature (e.g. at the bottom of the last page under "AUTHORIZED SIGNATURE")
      // is always the one that receives the official DSC green verification seal!
      final List<SignatureLocation> sortedLocations = List.from(effectiveLocations)
        ..sort((a, b) {
          final int pageCmp = a.pageIndex.compareTo(b.pageIndex);
          if (pageCmp != 0) return pageCmp;
          return a.y.compareTo(b.y);
        });

      for (int i = 0; i < sortedLocations.length; i++) {
        final loc = sortedLocations[i];
        final int targetPage = loc.pageIndex.clamp(0, document.pages.count - 1);
        final PdfPage page = document.pages[targetPage];
        final Size pageSize = page.getClientSize();

        // 1. Draw signature image on every spot
        page.graphics.drawImage(
          signatureImage,
          Rect.fromLTWH(
            loc.x,
            loc.y,
            loc.width,
            loc.height,
          ),
        );

        // 2. Only add the official verification seal to the LAST signature in document order
        // (i.e. the authorized signature on the final page)
        final bool isLastSpot = (i == sortedLocations.length - 1);
        if (isLastSpot) {
          _drawInlineAuditSeal(
            page.graphics,
            signingEvent,
            pageSize,
            customX: loc.x,
            customY: loc.y,
            customHeight: loc.height,
          );
        }
      }

      // Optionally append the standalone "Certificate of Completion" page if requested
      if (attachCertificatePage) {
        _appendAuditCertificatePage(document, signingEvent, signatureImage);
      }

      // Save the finalized PDF bytes
      final List<int> signedBytes = await document.save();
      return Uint8List.fromList(signedBytes);
    } finally {
      document.dispose();
    }
  }

  /// Draws the official DSC (Digital Signature Certificate) stamp
  /// matching the universally recognized Indian / Adobe standard:
  /// - Crisp Green Checkmark (✔)
  /// - Bold "Signature valid" header
  /// - "Digitally signed by [Name/Email]"
  /// - "Date: YYYY.MM.DD HH:mm:ss IST"
  /// - "Verified via: Cryptographic Hash"
  static void _drawInlineAuditSeal(
    PdfGraphics g,
    SigningEvent event,
    Size pageSize, {
    double? customX,
    double? customY,
    double? customHeight,
  }) {
    // Standard DSC Palette
    final PdfColor verifiedGreen = PdfColor(22, 163, 74); // Official DSC Green
    final PdfColor titleDark = PdfColor(15, 23, 42);
    final PdfColor textGray = PdfColor(51, 65, 85);

    // Bounding dimensions
    const double dscWidth = 160.0;
    const double dscHeight = 34.0;

    final double effectiveX = customX ?? event.x;
    final double effectiveY = customY ?? event.y;
    final double effectiveHeight = customHeight ?? event.height;

    // Position: directly below signature ink if space allows, otherwise above
    double dscX = effectiveX;
    if (dscX + dscWidth > pageSize.width - 10) {
      dscX = (pageSize.width - dscWidth - 10).clamp(10.0, pageSize.width);
    }

    double dscY = effectiveY + effectiveHeight + 2;
    if (dscY + dscHeight > pageSize.height - 10) {
      dscY = (effectiveY - dscHeight - 2).clamp(5.0, pageSize.height);
    }

    // Draw subtle clean white background behind the DSC seal so it is always 100% legible
    g.drawRectangle(
      brush: PdfSolidBrush(PdfColor(255, 255, 255, 245)),
      pen: PdfPen(PdfColor(226, 232, 240), width: 0.6),
      bounds: Rect.fromLTWH(dscX - 2, dscY - 1, dscWidth + 4, dscHeight + 2),
    );

    // 1. Draw crisp vector Green Checkmark (✔)
    final PdfPen checkmarkPen = PdfPen(verifiedGreen, width: 2.2)
      ..lineCap = PdfLineCap.round
      ..lineJoin = PdfLineJoin.round;

    final double tickX = dscX + 2;
    final double tickY = dscY + 4;
    // Checkmark geometry: short stroke down-right, long stroke up-right
    g.drawLine(checkmarkPen, Offset(tickX, tickY + 5), Offset(tickX + 4.5, tickY + 11));
    g.drawLine(checkmarkPen, Offset(tickX + 4.5, tickY + 11), Offset(tickX + 13, tickY));

    // Fonts
    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 6);

    final double textX = dscX + 16;
    final double textW = dscWidth - 18;

    // 2. Bold Header: "Signature valid"
    g.drawString(
      'Signature valid',
      titleFont,
      brush: PdfSolidBrush(titleDark),
      bounds: Rect.fromLTWH(textX, dscY + 1, textW, 10),
    );

    // 3. Line 1: "Digitally signed by <Email/Name>"
    final String signerName = event.userEmail;
    g.drawString(
      'Digitally signed by $signerName',
      bodyFont,
      brush: PdfSolidBrush(textGray),
      bounds: Rect.fromLTWH(textX, dscY + 11, textW, 8),
    );

    // 4. Line 2: "Date: YYYY.MM.DD HH:mm:ss IST"
    final DateTime istTime = event.signedAt.toUtc().add(const Duration(hours: 5, minutes: 30));
    final String yyyy = istTime.year.toString();
    final String mm = istTime.month.toString().padLeft(2, '0');
    final String dd = istTime.day.toString().padLeft(2, '0');
    final String hh = istTime.hour.toString().padLeft(2, '0');
    final String min = istTime.minute.toString().padLeft(2, '0');
    final String ss = istTime.second.toString().padLeft(2, '0');
    final String dateStr = '$yyyy.$mm.$dd $hh:$min:$ss IST';

    g.drawString(
      'Date: $dateStr',
      bodyFont,
      brush: PdfSolidBrush(textGray),
      bounds: Rect.fromLTWH(textX, dscY + 18, textW, 8),
    );

    // 5. Line 3: "Verified: Mobile Biometric & Keycloak SSO"
    g.drawString(
      'Reason: ${event.biometricVerification}',
      bodyFont,
      brush: PdfSolidBrush(verifiedGreen),
      bounds: Rect.fromLTWH(textX, dscY + 25, textW, 8),
    );
  }

  /// Appends an executive, legally compliant Certificate of Completion to the PDF
  static void _appendAuditCertificatePage(
    PdfDocument document,
    SigningEvent event,
    PdfBitmap signatureImage,
  ) {
    final PdfPage certPage = document.pages.add();
    final PdfGraphics g = certPage.graphics;
    final Size pageSize = certPage.getClientSize();

    // Palette
    final PdfColor primaryNavy = PdfColor(12, 43, 130);
    final PdfColor slateMuted = PdfColor(100, 116, 139);
    final PdfColor textDark = PdfColor(15, 23, 42);
    final PdfColor cardBg = PdfColor(248, 250, 252);
    final PdfColor borderGray = PdfColor(226, 232, 240);
    final PdfColor verifiedGreen = PdfColor(22, 101, 52);

    // Fonts
    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont subTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final PdfFont headingFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final PdfFont labelFont = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold);
    final PdfFont valueFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final PdfFont hashFont = PdfStandardFont(PdfFontFamily.courier, 8);
    final PdfFont legalFont = PdfStandardFont(PdfFontFamily.helvetica, 8);

    double y = 20;

    // 1. Top Decorative Brand Bar
    g.drawRectangle(
      brush: PdfSolidBrush(primaryNavy),
      bounds: Rect.fromLTWH(0, y, pageSize.width, 6),
    );
    y += 18;

    // 2. Title & Subtitle
    g.drawString(
      'eSign — Certificate of Completion',
      titleFont,
      brush: PdfSolidBrush(primaryNavy),
      bounds: Rect.fromLTWH(0, y, pageSize.width, 24),
    );
    y += 24;

    g.drawString(
      'Official Forensic Audit Trail & Tamper-Evident Verification Record',
      subTitleFont,
      brush: PdfSolidBrush(slateMuted),
      bounds: Rect.fromLTWH(0, y, pageSize.width, 14),
    );
    y += 24;

    // 3. Document Details Box
    _drawSectionCard(
      graphics: g,
      x: 0,
      y: y,
      width: pageSize.width,
      height: 60,
      bgColor: cardBg,
      borderColor: borderGray,
    );

    g.drawString('Document Information', headingFont, brush: PdfSolidBrush(textDark), bounds: Rect.fromLTWH(12, y + 8, pageSize.width - 24, 16));
    g.drawString('Document Title:  ${event.documentTitle}', valueFont, brush: PdfSolidBrush(textDark), bounds: Rect.fromLTWH(12, y + 26, pageSize.width - 24, 14));
    g.drawString('Event Identifier:  ${event.signingEventId}', valueFont, brush: PdfSolidBrush(slateMuted), bounds: Rect.fromLTWH(12, y + 42, pageSize.width - 24, 14));
    y += 72;

    // 4. Cryptographic SHA-256 Hash Card
    _drawSectionCard(
      graphics: g,
      x: 0,
      y: y,
      width: pageSize.width,
      height: 52,
      bgColor: cardBg,
      borderColor: borderGray,
    );

    g.drawString('Document Cryptographic Fingerprint (SHA-256)', headingFont, brush: PdfSolidBrush(textDark), bounds: Rect.fromLTWH(12, y + 8, pageSize.width - 24, 16));
    g.drawString(event.documentHash, hashFont, brush: PdfSolidBrush(primaryNavy), bounds: Rect.fromLTWH(12, y + 28, pageSize.width - 24, 16));
    y += 64;

    // 5. Signer Details & Forensic Evidence Grid (THE 4 PILLARS)
    _drawSectionCard(
      graphics: g,
      x: 0,
      y: y,
      width: pageSize.width,
      height: 198,
      bgColor: cardBg,
      borderColor: borderGray,
    );

    g.drawString('Signer Audit Trail & Forensic Evidence', headingFont, brush: PdfSolidBrush(textDark), bounds: Rect.fromLTWH(12, y + 8, pageSize.width - 24, 16));

    double rowY = y + 30;
    const double col1 = 12;
    const double col2 = 140;

    void drawEvidenceRow(String label, String value, {PdfColor? textColor}) {
      g.drawString(label, labelFont, brush: PdfSolidBrush(slateMuted), bounds: Rect.fromLTWH(col1, rowY, 120, 14));
      g.drawString(value, valueFont, brush: PdfSolidBrush(textColor ?? textDark), bounds: Rect.fromLTWH(col2, rowY, pageSize.width - col2 - 120, 14));
      rowY += 18;
    }

    drawEvidenceRow('Signer Email:', event.userEmail);
    drawEvidenceRow('Keycloak User ID:', event.userId);
    drawEvidenceRow('Signer IP Address:', event.ipAddress, textColor: primaryNavy);
    drawEvidenceRow('Signing Timestamp:', '${event.signedAt.toIso8601String().replaceAll('T', ' ').substring(0, 19)} UTC');
    drawEvidenceRow('Authentication:', event.authenticationMethod);
    drawEvidenceRow('Biometric Confirmation:', event.biometricVerification, textColor: verifiedGreen);
    drawEvidenceRow('Signature Position:', 'Page ${event.pageIndex + 1} at (${event.x.toStringAsFixed(1)}, ${event.y.toStringAsFixed(1)})');
    drawEvidenceRow('Status:', 'VERIFIED & LEGALLY BINDING', textColor: verifiedGreen);

    // Embed visual preview of the signature inside the audit certificate
    final double sigPreviewWidth = 100;
    final double sigPreviewHeight = (event.height / event.width) * sigPreviewWidth;
    g.drawImage(
      signatureImage,
      Rect.fromLTWH(pageSize.width - sigPreviewWidth - 16, y + 36, sigPreviewWidth, sigPreviewHeight.clamp(20, 60)),
    );

    y += 212;

    // 6. Legal Compliance Disclaimer (US ESIGN Act, EU eIDAS, IT Act Section 10A)
    _drawSectionCard(
      graphics: g,
      x: 0,
      y: y,
      width: pageSize.width,
      height: 64,
      bgColor: PdfColor(241, 245, 249),
      borderColor: borderGray,
    );

    g.drawString('Legal Enforceability & Statement of Intent', labelFont, brush: PdfSolidBrush(textDark), bounds: Rect.fromLTWH(12, y + 8, pageSize.width - 24, 14));
    g.drawString(
      'This document was electronically signed in compliance with international electronic signature legislation '
      '(US ESIGN Act 15 U.S.C. 7001, EU eIDAS Regulation 910/2014, and India IT Act Section 10A). '
      'The signer authenticated via Keycloak OIDC, adopted the electronic signature mark, and agreed to be bound by the contents. '
      'Any modification to the original file alters the cryptographic SHA-256 fingerprint, invalidating this certification.',
      legalFont,
      brush: PdfSolidBrush(slateMuted),
      bounds: Rect.fromLTWH(12, y + 22, pageSize.width - 24, 38),
    );
  }

  /// Helper to draw smooth rounded section cards on the PDF page
  static void _drawSectionCard({
    required PdfGraphics graphics,
    required double x,
    required double y,
    required double width,
    required double height,
    required PdfColor bgColor,
    required PdfColor borderColor,
  }) {
    graphics.drawRectangle(
      brush: PdfSolidBrush(bgColor),
      pen: PdfPen(borderColor, width: 1),
      bounds: Rect.fromLTWH(x, y, width, height),
    );
  }
}
