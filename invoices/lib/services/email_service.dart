import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../models/invoice.dart';

class EmailService {
  /// Share the invoice PDF with subject + message via the native share sheet.
  /// Email clients receive the subject in the subject field and message in the body.
  /// WhatsApp (and other messengers) receive the text formatted with bold markers.
  static Future<void> shareInvoice({
    required Invoice invoice,
    required Uint8List pdfBytes,
    required String subject,
    required String message,
  }) async {
    // *Subject* on its own line so WhatsApp renders it bold; email clients use
    // the EXTRA_SUBJECT intent extra for the actual subject field.
    final shareText = '*$subject*\n\n$message';

    await Share.shareXFiles(
      [
        XFile.fromData(
          pdfBytes,
          name: 'invoice_${invoice.invoiceNumber}.pdf',
          mimeType: 'application/pdf',
        ),
      ],
      subject: subject,
      text: shareText,
    );
  }

  static Future<bool> sendViaCloudFunction({
    required Invoice invoice,
    required String recipientEmail,
    required String subject,
    required String body,
    required Uint8List pdfBytes,
  }) async {
    final baseUrl = dotenv.env['CLOUD_FUNCTION_BASE_URL'];
    if (baseUrl == null || baseUrl.isEmpty || baseUrl.contains('your_project')) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sendInvoiceEmail'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': recipientEmail,
          'subject': subject,
          'html': body,
          'pdfBase64': base64Encode(pdfBytes),
          'pdfFilename': 'invoice_${invoice.invoiceNumber}.pdf',
          'invoiceNumber': invoice.invoiceNumber,
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String buildEmailBody({
    required Invoice invoice,
    required String customMessage,
  }) {
    return '''<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: -apple-system, sans-serif; color: #1e293b; max-width: 600px; margin: 0 auto; padding: 32px;">
  <div style="border-bottom: 3px solid #2563EB; padding-bottom: 16px; margin-bottom: 24px;">
    <h2 style="margin: 0; color: #2563EB;">${invoice.businessName}</h2>
  </div>

  <p style="font-size: 16px;">${customMessage.replaceAll('\n', '<br>')}</p>

  <div style="background: #f8fafc; border-radius: 8px; padding: 16px; margin: 24px 0; border: 1px solid #e2e8f0;">
    <p style="margin: 0 0 8px 0;"><strong>Invoice:</strong> ${invoice.invoiceNumber}</p>
    <p style="margin: 0 0 8px 0;"><strong>Amount Due:</strong> ${invoice.currency}${invoice.total.toStringAsFixed(2)}</p>
    <p style="margin: 0;"><strong>Due Date:</strong> ${invoice.dueDate.day}/${invoice.dueDate.month}/${invoice.dueDate.year}</p>
  </div>

  <p style="color: #64748b; font-size: 14px;">Please find the invoice attached to this email.</p>

  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;">
  <p style="color: #94a3b8; font-size: 12px; margin: 0;">${invoice.businessName} &bull; ${invoice.businessEmail}</p>
</body>
</html>''';
  }

  static String buildDefaultSubject(Invoice invoice) =>
      'Invoice ${invoice.invoiceNumber} from ${invoice.businessName}';

  static String buildDefaultMessage(Invoice invoice) =>
      'Dear ${invoice.clientName},'
      '\n\nPlease find attached invoice ${invoice.invoiceNumber} for '
      '${invoice.currency}${invoice.total.toStringAsFixed(2)}, due on '
      '${invoice.dueDate.day}/${invoice.dueDate.month}/${invoice.dueDate.year}.'
      '\n\nThank you for your business.'
      '\n\nBest regards,\n${invoice.businessName}';
}
