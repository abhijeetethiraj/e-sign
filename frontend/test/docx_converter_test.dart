import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/docx_converter_service.dart';

void main() {
  test('DocxConverterService converts a generated docx into valid PDF bytes', () async {
    // Construct a minimal in-memory docx ZIP file
    final Archive archive = Archive();
    const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
      <w:r><w:t>OFFER LETTER AGREEMENT</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>We are pleased to offer you the position of Senior Engineer.</w:t></w:r>
    </w:p>
  </w:body>
</w:document>''';

    final xmlBytes = utf8.encode(xml);
    archive.addFile(ArchiveFile('word/document.xml', xmlBytes.length, xmlBytes));
    final docxBytes = Uint8List.fromList(ZipEncoder().encode(archive));

    final Uint8List pdfBytes = await DocxConverterService.convertToPdf(
      docxBytes,
      originalFileName: 'Offer_Letter.docx',
    );

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.length, greaterThan(100));
    // Verify it is a valid PDF (starts with %PDF)
    final header = utf8.decode(pdfBytes.sublist(0, 4));
    expect(header, equals('%PDF'));
  });

  test('DocxConverterService falls back gracefully on non-zip word content', () async {
    final rawBytes = Uint8List.fromList(utf8.encode('Hello World Sample Contract Text'));
    final pdfBytes = await DocxConverterService.convertToPdf(
      rawBytes,
      originalFileName: 'Legacy_Doc.doc',
    );

    expect(pdfBytes, isNotNull);
    final header = utf8.decode(pdfBytes.sublist(0, 4));
    expect(header, equals('%PDF'));
  });
}
