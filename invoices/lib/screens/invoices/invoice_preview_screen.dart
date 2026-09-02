import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/invoice.dart';
import '../../providers/business_provider.dart';
import '../../providers/invoice_provider.dart';
import 'create_invoice_screen.dart';
import '../../services/email_service.dart';
import '../../services/pdf_service.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final Invoice invoice;
  const InvoicePreviewScreen({super.key, required this.invoice});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  late Invoice _invoice;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  @override
  Widget build(BuildContext context) {
    final logoBytes = context.read<BusinessProvider>().logoBytes;

    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice.numberLabel),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleMenu,
            itemBuilder: (_) => [
              if (_invoice.status != 'betaald')
                const PopupMenuItem(
                  value: 'betaald',
                  child: Text('Markeer als betaald'),
                ),
              const PopupMenuItem(
                value: 'download',
                child: Text('PDF Downloaden'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Verwijderen')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Meta bar
          Container(
            color: AppTheme.surf(context),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _MetaChip(label: _clientLabel, icon: Icons.moped_outlined),
                const Spacer(),
                _StatusBadge(status: _invoice.status),
              ],
            ),
          ),
          const Divider(height: 1),

          // Notes bar — no "Notes:" label, just the text
          Container(
            width: double.infinity,
            color: AppTheme.bg(context),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              _invoice.notes.isNotEmpty
                  ? _invoice.notes
                  : 'Geen opmerkingen toegevoegd',
              style: TextStyle(
                color: _invoice.notes.isNotEmpty
                    ? AppTheme.onSurface(context)
                    : AppTheme.onSurfaceVariant(context),
                fontSize: 13,
                fontStyle: _invoice.notes.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
          const Divider(height: 1),

          // PDF Preview
          Expanded(
            child: PdfPreview(
              build: (_) =>
                  PdfService.generatePdf(_invoice, logoBytes: logoBytes),
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: _invoice.pdfFilename,
              actions: const [],
              loadingWidget: const Center(child: CircularProgressIndicator()),
            ),
          ),

          // Actions — pad for the system navigation bar (3-button nav is
          // taller than gesture nav, and would otherwise cover the buttons).
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).viewPadding.bottom,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surf(context),
              border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editInvoice(),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Bewerken'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : () => _shareInvoice(logoBytes),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.share_outlined, size: 18),
                    label: Text(_sending ? 'Bezig...' : 'Versturen'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Name and vehicle reference, joined by a dot. The name is optional — with
  /// none, the kenteken (or product type) stands on its own rather than
  /// hanging off an empty leading dot.
  String get _clientLabel {
    final ref = _invoice.clientKenteken.isNotEmpty
        ? _invoice.clientKenteken
        : _invoice.clientProductType;
    if (_invoice.clientNaam.isEmpty) return ref;
    if (ref.isEmpty) return _invoice.clientNaam;
    return '${_invoice.clientNaam} · $ref';
  }

  Future<void> _editInvoice() async {
    final updated = await Navigator.push<Invoice>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateInvoiceScreen(editInvoice: _invoice, initialStep: 1),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _invoice = updated);
    }
  }

  Future<void> _downloadPdf(Uint8List? logoBytes) async {
    final bytes = await PdfService.generatePdf(_invoice, logoBytes: logoBytes);
    await Printing.sharePdf(bytes: bytes, filename: _invoice.pdfFilename);
  }

  Future<void> _shareInvoice(Uint8List? logoBytes) async {
    setState(() => _sending = true);
    try {
      final businessProvider = context.read<BusinessProvider>();
      final template = businessProvider.businessInfo?.emailTemplate ?? '';
      final subject = EmailService.buildDefaultSubject(_invoice);
      final body = EmailService.renderTemplate(template, _invoice);
      final pdfBytes = await PdfService.generatePdf(
        _invoice,
        logoBytes: logoBytes,
      );

      final shareText = '$subject\n\n$body';
      await Clipboard.setData(ClipboardData(text: shareText));

      await EmailService.shareInvoice(
        invoice: _invoice,
        pdfBytes: pdfBytes,
        subject: subject,
        message: body,
      );
      if (!mounted) return;
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Bericht gekopieerd — plak het in WhatsApp'),
      //     behavior: SnackBarBehavior.floating,
      //     duration: Duration(seconds: 4),
      //   ),
      // );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fout: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _handleMenu(String action) async {
    if (action == 'download') {
      final logoBytes = context.read<BusinessProvider>().logoBytes;
      await _downloadPdf(logoBytes);
      return;
    }
    if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Factuur verwijderen'),
          content: Text(
            'Verwijder ${_invoice.invoiceNumber}? Dit kan niet ongedaan worden gemaakt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuleren'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              child: const Text('Verwijderen'),
            ),
          ],
        ),
      );
      if (confirm == true && mounted) {
        await context.read<InvoiceProvider>().deleteInvoice(_invoice.id);
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } else {
      await context.read<InvoiceProvider>().updateStatus(_invoice.id, action);
      setState(() => _invoice = _invoice.copyWith(status: action));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Factuur gemarkeerd als $action'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MetaChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppTheme.onSurfaceVariant(context)),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.onSurfaceVariant(context),
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'betaald':
        color = const Color(0xFF10B981);
        break;
      default:
        color = AppTheme.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
