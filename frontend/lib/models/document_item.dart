import 'dart:typed_data';

enum DocumentStatus {
  readyToSign,
  signed,
}

class DocumentItem {
  final String id;
  final String title;
  final String subtitle;
  final String date;
  final DocumentStatus status;
  final String? filePath;
  Uint8List? pdfBytes;

  DocumentItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.status,
    this.filePath,
    this.pdfBytes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'date': date,
    'status': status.name,
    'filePath': filePath,
  };

  factory DocumentItem.fromJson(Map<String, dynamic> json) => DocumentItem(
    id: json['id'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    date: json['date'] as String,
    status: (json['status'] as String) == 'signed'
        ? DocumentStatus.signed
        : DocumentStatus.readyToSign,
    filePath: json['filePath'] as String?,
  );
}