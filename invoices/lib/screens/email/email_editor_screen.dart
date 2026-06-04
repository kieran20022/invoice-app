import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/invoice.dart';
import '../../services/email_service.dart';
import '../../services/pdf_service.dart';

class EmailEditorScreen extends StatefulWidget {
  final Invoice invoice;
  const EmailEditorScreen({super.key, required this.invoice});

  @override
  State<EmailEditorScreen> createState() => _EmailEditorScreenState();
}

class _EmailEditorScreenState extends State<EmailEditorScreen> {
  late final TextEditingController _subject;
  late final TextEditingController _message;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _subject = TextEditingController(
        text: EmailService.buildDefaultSubject(widget.invoice));
    _message = TextEditingController(
        text: EmailService.buildDefaultMessage(widget.invoice));
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final pdfBytes = await PdfService.generatePdf(widget.invoice);

      // Try cloud function first
      final sent = await EmailService.sendViaCloudFunction(
        invoice: widget.invoice,
        recipientEmail: widget.invoice.clientEmail,
        subject: _subject.text,
        body: EmailService.buildEmailBody(
          invoice: widget.invoice,
          customMessage: _message.text,
        ),
        pdfBytes: pdfBytes,
      );

      if (!mounted) return;

      if (sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email sent successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      } else {
        // Fallback: open native share sheet with subject + message
        await EmailService.shareInvoice(
          invoice: widget.invoice,
          pdfBytes: pdfBytes,
          subject: _subject.text,
          message: _message.text,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _share() async {
    setState(() => _sending = true);
    try {
      final pdfBytes = await PdfService.generatePdf(widget.invoice);
      await EmailService.shareInvoice(
        invoice: widget.invoice,
        pdfBytes: pdfBytes,
        subject: _subject.text,
        message: _message.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Invoice'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Recipient info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(13),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withAlpha(51)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sending to',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  widget.invoice.clientName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  widget.invoice.clientEmail,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.attach_file,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'invoice_${widget.invoice.invoiceNumber}.pdf',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text('Subject',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _subject,
            decoration: const InputDecoration(hintText: 'Email subject'),
          ),

          const SizedBox(height: 16),

          const Text('Message',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _message,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Write your message here...',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Subject and message are passed to your email app. '
                    'On WhatsApp the message appears as *Subject*\n\nMessage.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined, size: 18),
            label: Text(_sending ? 'Sending...' : 'Send Invoice'),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: _sending ? null : _share,
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share PDF'),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
