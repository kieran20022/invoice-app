import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/invoice.dart';

class EmailService {
  /// Sends the invoice directly to the native email composer (no share sheet).
  /// Falls back to [shareInvoice] on web where flutter_email_sender is unavailable.
  static Future<void> sendViaEmailApp({
    required Invoice invoice,
    required Uint8List pdfBytes,
    required String subject,
    required String body,
    String recipientEmail = '',
  }) async {
    if (kIsWeb) {
      await shareInvoice(
        invoice: invoice,
        pdfBytes: pdfBytes,
        subject: subject,
        message: body,
      );
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${invoice.pdfFilename}');
    await file.writeAsBytes(pdfBytes);

    final email = Email(
      subject: subject,
      body: body,
      recipients: recipientEmail.isNotEmpty ? [recipientEmail] : [],
      attachmentPaths: [file.path],
      isHTML: false,
    );

    await FlutterEmailSender.send(email);
  }

  /// Share PDF via the generic share sheet (fallback / WhatsApp etc.).
  /// Text is formatted as "subject\n\nbody" so WhatsApp shows it cleanly.
  static Future<void> shareInvoice({
    required Invoice invoice,
    required Uint8List pdfBytes,
    required String subject,
    required String message,
  }) async {
    final shareText = '$subject\n\n$message';

    // Write to a named temp file so the filename is correct on all platforms
    // (XFile.fromData does not reliably propagate the name on Android).
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${invoice.pdfFilename}');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: subject,
      text: shareText,
    );
  }

  /// Replace template variables with actual invoice values.
  static String renderTemplate(String template, Invoice invoice) {
    String voertuigInfo = '';
    if (invoice.clientKenteken.isNotEmpty) {
      voertuigInfo = 'voor het voertuig met kenteken ${invoice.clientKenteken}';
      if (invoice.clientKmstand.isNotEmpty) {
        voertuigInfo += ' (Km-stand: ${invoice.clientKmstand})';
      }
    } else if (invoice.clientProductType.isNotEmpty) {
      voertuigInfo = 'voor uw ${invoice.clientProductType}';
    }

    return template
        .replaceAll('{naam}', invoice.clientNaam)
        .replaceAll('{kenteken}', invoice.clientKenteken)
        .replaceAll('{producttype}', invoice.clientProductType)
        .replaceAll('{kmstand}', invoice.clientKmstand)
        .replaceAll('{voertuig_info}', voertuigInfo)
        .replaceAll('{factuur_nummer}', invoice.invoiceNumber)
        .replaceAll('{bedrijfsnaam}', invoice.businessName)
        .replaceAll(
          '{datum}',
          DateFormat('dd-MM-yyyy').format(invoice.issueDate),
        )
        .replaceAll(
          '{totaal}',
          '${invoice.currency}${invoice.totaalInclBtw.toStringAsFixed(2)}',
        );
  }

  static String buildDefaultSubject(Invoice invoice) {
    final ref = invoice.clientKenteken.isNotEmpty
        ? invoice.clientKenteken
        : invoice.clientProductType;
    return ref.isNotEmpty
        ? '${invoice.numberLabel} - $ref'
        : invoice.numberLabel;
  }
}
