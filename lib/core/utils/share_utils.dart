import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

const _mimeByExtension = {
  'pdf': 'application/pdf',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'wav': 'audio/wav',
  'bmp': 'image/bmp',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'csv': 'text/csv',
  'json': 'application/json',
  'xml': 'application/xml',
  'zip': 'application/zip',
  'tar': 'application/x-tar',
  'gz': 'application/gzip',
  'tgz': 'application/gzip',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'vcf': 'text/vcard',
};

String mimeTypeForFileName(String filename) {
  final dot = filename.lastIndexOf('.');
  final ext = dot < 0 ? '' : filename.substring(dot + 1).toLowerCase();
  return _mimeByExtension[ext] ?? 'application/octet-stream';
}

/// Shares [bytes] as a file named [filename] with the MIME type taken from its
/// extension. Replaces `Printing.sharePdf`, which labels every file as a PDF.
Future<void> shareFileBytes(Uint8List bytes, String filename) {
  return SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: mimeTypeForFileName(filename))],
      fileNameOverrides: [filename],
    ),
  );
}
