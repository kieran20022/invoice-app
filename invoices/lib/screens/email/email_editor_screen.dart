import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/invoice.dart';
import '../../providers/business_provider.dart';
import '../../services/email_service.dart';
import '../../services/pdf_service.dart';

class EmailEditorScreen extends StatefulWidget {
  final Invoice invoice;
  const EmailEditorScreen({super.key, required this.invoice});

  @override
  State<EmailEditorScreen> createState() => _EmailEditorScreenState();
}

class _EmailEditorScreenState extends State<EmailEditorScreen> {
  late final TextEditingController _recipient;
  late final String _subject;
  late String _renderedBody;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _recipient = TextEditingController();
    _subject = EmailService.buildDefaultSubject(widget.invoice);
    _renderedBody = '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_renderedBody.isEmpty) {
      final template =
          context.read<BusinessProvider>().businessInfo?.emailTemplate ?? '';
      _renderedBody = EmailService.renderTemplate(template, widget.invoice);
    }
  }

  @override
  void dispose() {
    _recipient.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final logoBytes = context.read<BusinessProvider>().logoBytes;
      final pdfBytes = await PdfService.generatePdf(
        widget.invoice,
        logoBytes: logoBytes,
      );
      await EmailService.sendViaEmailApp(
        invoice: widget.invoice,
        pdfBytes: pdfBytes,
        subject: _subject,
        body: _renderedBody,
        recipientEmail: _recipient.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fout: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.error,
        ),
      );
      setState(() => _sending = false);
    }
  }

  Future<void> _share() async {
    setState(() => _sending = true);
    try {
      final logoBytes = context.read<BusinessProvider>().logoBytes;
      final pdfBytes = await PdfService.generatePdf(
        widget.invoice,
        logoBytes: logoBytes,
      );
      // WhatsApp ignores EXTRA_TEXT when sharing a PDF document, so copy
      // the message to clipboard first and prompt the user to paste it.
      final shareText = '$_subject\n\n$_renderedBody';
      await Clipboard.setData(ClipboardData(text: shareText));

      await EmailService.shareInvoice(
        invoice: widget.invoice,
        pdfBytes: pdfBytes,
        subject: _subject,
        message: _renderedBody,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bericht gekopieerd — plak het in WhatsApp'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      setState(() => _sending = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fout: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.error,
        ),
      );
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Factuur versturen')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Invoice summary
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
                const Text(
                  'Factuurgegevens',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.invoice.invoiceNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${widget.invoice.clientNaam} · ${widget.invoice.clientKenteken}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.attach_file,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      // Derive a human-readable filename from the invoice
                      // number rather than exposing the raw UUID stored in
                      // pdfFilename.
                      'Factuur_${widget.invoice.invoiceNumber}.pdf',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'E-mailadres ontvanger',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _recipient,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'klant@voorbeeld.nl',
              prefixIcon: Icon(Icons.email_outlined, size: 18),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Berichtvoorbeeld',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              _renderedBody,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bewerk het sjabloon via Instellingen → E-mail sjabloon',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.email_outlined, size: 18),
            label: Text(_sending ? 'Bezig...' : 'Verstuur via e-mail app'),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: _sending ? null : _share,
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Delen (WhatsApp, enz.)'),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
