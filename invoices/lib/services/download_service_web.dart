import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Saving a file on the web: the browser's own download, through a blob URL
/// handed to a link that is clicked once and thrown away.
class DownloadService {
  static Future<String> save({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = filename;

    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);

    return filename;
  }
}

/// A download that could not be completed, carrying a message meant for the
/// user rather than a stack trace.
class DownloadException implements Exception {
  final String message;
  const DownloadException(this.message);

  @override
  String toString() => message;
}
