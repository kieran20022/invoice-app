import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/invoice.dart';

/// Sends an invoice PDF straight to one WhatsApp contact.
///
/// The share sheet cannot preselect a recipient, so this goes through a
/// platform channel that fires an explicit WhatsApp intent (see MainActivity).
/// Android only — [isAvailable] is false everywhere else.
class WhatsappService {
  static const _channel = MethodChannel('com.bliksemit.Invoices/whatsapp');

  /// Country code assumed for local numbers written without one. The app and
  /// its invoice layouts are Dutch, so numbers like `06-12345678` are Dutch.
  static const defaultCountryCode = '31';

  /// Turns a number as typed into the digits-only international form WhatsApp
  /// expects (`31612345678`). Returns null when nothing usable is left.
  ///
  /// Handles `+31 6 12345678`, `0031612345678`, `06-12345678` and `612345678`.
  static String? normalizePhone(
    String raw, {
    String countryCode = defaultCountryCode,
  }) {
    final isInternational = raw.trimLeft().startsWith('+');
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    if (isInternational) {
      // Already carries its own country code — leave it alone.
    } else if (digits.startsWith('00')) {
      // 00 international prefix → bare country code.
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      // National trunk prefix: drop the 0, prepend the country code.
      digits = '$countryCode${digits.substring(1)}';
    } else if (!digits.startsWith(countryCode)) {
      // Bare subscriber number (the leading 0 was left out).
      digits = '$countryCode$digits';
    }

    // Shortest plausible international number is ~8 digits.
    return digits.length >= 8 ? digits : null;
  }

  /// Whether this device can share to a specific number — i.e. Android with
  /// WhatsApp or WhatsApp Business installed.
  static Future<bool> isAvailable() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens [phone]'s WhatsApp chat with the invoice PDF attached.
  ///
  /// Throws [PlatformException] when WhatsApp is missing or refuses the intent,
  /// and [ArgumentError] when [phone] is not a usable number.
  static Future<void> shareInvoiceToNumber({
    required Invoice invoice,
    required Uint8List pdfBytes,
    required String phone,
    required String text,
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) {
      throw ArgumentError.value(phone, 'phone', 'Geen geldig telefoonnummer');
    }

    // Named temp file so WhatsApp shows the real filename, matching how
    // EmailService shares the same PDF.
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${invoice.pdfFilename}');
    await file.writeAsBytes(pdfBytes);

    await _channel.invokeMethod<bool>('shareFileToNumber', {
      'filePath': file.path,
      'phone': normalized,
      'text': text,
    });
  }
}
