import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Saving a file to the device's Downloads, on everything that is not the web.
///
/// Android has no writable Downloads path an app may simply open, so the file
/// goes through MediaStore over a platform channel (see MainActivity). The
/// desktop platforms have a real Downloads folder; iOS has none, so the file
/// lands in the app's documents directory, which is what the Files app shows.
class DownloadService {
  static const _channel = MethodChannel('com.bliksemit.Invoices/files');

  /// Writes [bytes] as [filename] and returns where it ended up, phrased for
  /// the user ("Downloads/Inkomsten 2025.xlsx").
  ///
  /// Throws a [DownloadException] when the file could not be written — the
  /// caller shows the message as it is.
  static Future<String> save({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    if (Platform.isAndroid) {
      try {
        final location = await _channel.invokeMethod<String>(
          'saveToDownloads',
          {
            'bytes': bytes,
            'filename': filename,
            'mimeType': mimeType,
          },
        );
        if (location == null || location.isEmpty) {
          throw const DownloadException('Opslaan mislukt');
        }
        return location;
      } on PlatformException catch (e) {
        throw DownloadException(e.message ?? 'Opslaan mislukt');
      } on MissingPluginException {
        throw const DownloadException(
          'Deze versie van de app kan geen bestanden opslaan',
        );
      }
    }

    final dir = await _directory();
    final file = await _uniqueFile(dir, filename);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static Future<Directory> _directory() async {
    if (!Platform.isIOS) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads;
    }
    return getApplicationDocumentsDirectory();
  }

  /// Keeps an earlier export: a second "Inkomsten 2025.xlsx" becomes
  /// "Inkomsten 2025 (1).xlsx", the way a browser numbers a repeat download.
  /// Android's MediaStore does this itself.
  static Future<File> _uniqueFile(Directory dir, String filename) async {
    final dot = filename.lastIndexOf('.');
    final stem = dot == -1 ? filename : filename.substring(0, dot);
    final ext = dot == -1 ? '' : filename.substring(dot);

    var file = File('${dir.path}${Platform.pathSeparator}$filename');
    var n = 1;
    while (await file.exists()) {
      file = File('${dir.path}${Platform.pathSeparator}$stem ($n)$ext');
      n++;
    }
    return file;
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
