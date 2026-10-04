import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/invoice.dart';
import '../utils/price.dart';

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

  /// The share sheet handled by MainActivity — see [shareInvoice].
  static const _shareChannel = MethodChannel('com.bliksemit.Invoices/share');

  /// Share PDF via the generic share sheet (fallback / WhatsApp etc.).
  /// Text is formatted as "subject\n\nbody" so WhatsApp shows it cleanly.
  ///
  /// On Android this goes through our own channel rather than share_plus, so
  /// the receiving app keeps read access to the PDF after the share sheet is
  /// gone. Without that WhatsApp shows the document as a bare filename: it
  /// renders the page preview on a background worker, once the intent's own
  /// grant has already lapsed. Everywhere else share_plus does the sharing.
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
    await file.writeAsBytes(pdfBytes, flush: true);

    if (await _shareViaChannel([file.path], subject, shareText)) return;

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: subject,
      text: shareText,
    );
  }

  /// Shares several documents in one go, from the Facturen tab's selection.
  ///
  /// There is no one message that fits them all — the email template speaks
  /// about a single invoice — so they go out under a subject naming the
  /// documents and nothing more. A single document should go through
  /// [shareInvoice] instead, which does carry the message.
  static Future<void> shareInvoices(
    List<({Invoice invoice, Uint8List pdfBytes})> documents,
  ) async {
    final subject = documents.map((d) => d.invoice.numberLabel).join(', ');

    // The web has no temp directory to write to; the browser takes the bytes.
    if (kIsWeb) {
      await Share.shareXFiles(
        [
          for (final d in documents)
            XFile.fromData(
              d.pdfBytes,
              name: d.invoice.pdfFilename,
              mimeType: 'application/pdf',
            ),
        ],
        subject: subject,
        text: subject,
      );
      return;
    }

    // A folder of its own per share, and a repeated name numbered: two
    // quotes for the same customer and vehicle carry the same filename, and
    // one file would otherwise overwrite the other.
    final tempDir = await getTemporaryDirectory();
    final dir = Directory(
      '${tempDir.path}/share_${DateTime.now().millisecondsSinceEpoch}',
    );
    await dir.create(recursive: true);
    final used = <String>{};
    final paths = <String>[];
    for (final d in documents) {
      final name = _uniqueName(d.invoice.pdfFilename, used);
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(d.pdfBytes, flush: true);
      paths.add(file.path);
    }

    if (await _shareViaChannel(paths, subject, subject)) return;

    await Share.shareXFiles(
      [for (final p in paths) XFile(p, mimeType: 'application/pdf')],
      subject: subject,
      text: subject,
    );
  }

  /// [name], or "name (2).pdf" and up once it is already in [used].
  static String _uniqueName(String name, Set<String> used) {
    final dot = name.lastIndexOf('.');
    final stem = dot == -1 ? name : name.substring(0, dot);
    final ext = dot == -1 ? '' : name.substring(dot);
    var candidate = name;
    for (var n = 2; !used.add(candidate); n++) {
      candidate = '$stem ($n)$ext';
    }
    return candidate;
  }

  /// Hands the files to MainActivity's share sheet. False when this is not a
  /// platform it handles, or the call failed — share_plus then takes over.
  static Future<bool> _shareViaChannel(
    List<String> filePaths,
    String subject,
    String text,
  ) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _shareChannel.invokeMethod<bool>('shareFile', {
            'filePaths': filePaths,
            'mimeType': 'application/pdf',
            'subject': subject,
            'text': text,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Replace template variables with actual invoice values.
  ///
  /// The template is written for invoices; a quote reuses it with the word
  /// swapped for what the document actually is, so "Bijgevoegd vindt u
  /// factuur ..." reads correctly on an offerte or a schaderapport without
  /// the user maintaining a template per kind.
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

    final rendered = template
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
          formatMoney(invoice.totaalInclBtw, currency: invoice.currency),
        );

    return invoice.isQuote
        ? _asDocumentWording(rendered, invoice.documentLabel)
        : rendered;
  }

  static final _factuurWord = RegExp(r'\b(F|f)actuur\b');

  static String _asDocumentWording(String text, String label) =>
      text.replaceAllMapped(
        _factuurWord,
        (m) => m[1] == 'F' ? label : label.toLowerCase(),
      );

  static String buildDefaultSubject(Invoice invoice) {
    final ref = invoice.clientKenteken.isNotEmpty
        ? invoice.clientKenteken
        : invoice.clientProductType;
    return ref.isNotEmpty
        ? '${invoice.numberLabel} - $ref'
        : invoice.numberLabel;
  }
}
