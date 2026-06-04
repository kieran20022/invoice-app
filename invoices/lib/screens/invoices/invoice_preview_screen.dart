import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/invoice.dart';
import '../../providers/invoice_provider.dart';
import '../../services/pdf_service.dart';
import '../email/email_editor_screen.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final Invoice invoice;
  const InvoicePreviewScreen({super.key, required this.invoice});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  late Invoice _invoice;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice.invoiceNumber),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => _handleMenu(v),
            itemBuilder: (_) => [
              if (_invoice.status != 'paid')
                const PopupMenuItem(
                    value: 'paid', child: Text('Mark as Paid')),
              if (_invoice.status == 'paid')
                const PopupMenuItem(
                    value: 'sent', child: Text('Mark as Sent')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Invoice meta bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                _MetaChip(
                  label: _invoice.clientName,
                  icon: Icons.person_outline,
                ),
                const SizedBox(width: 8),
                _MetaChip(
                  label: _totalLabel(),
                  icon: Icons.attach_money,
                  color: AppTheme.primary,
                ),
                const Spacer(),
                _StatusBadge(status: _invoice.status),
              ],
            ),
          ),
          const Divider(height: 1),

          // PDF Preview
          Expanded(
            child: PdfPreview(
              build: (_) => PdfService.generatePdf(_invoice),
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: 'invoice_${_invoice.invoiceNumber}.pdf',
              actions: const [],
              loadingWidget: const Center(child: CircularProgressIndicator()),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _downloadPdf,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Download PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sendEmail,
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: const Text('Send Email'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _totalLabel() =>
      '${_invoice.currency}${_invoice.total.toStringAsFixed(2)}';

  Future<void> _downloadPdf() async {
    final bytes = await PdfService.generatePdf(_invoice);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'invoice_${_invoice.invoiceNumber}.pdf',
    );
  }

  void _sendEmail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmailEditorScreen(invoice: _invoice),
      ),
    );
  }

  void _handleMenu(String action) async {
    if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Invoice'),
          content: Text('Delete ${_invoice.invoiceNumber}? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              child: const Text('Delete'),
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
            content: Text('Invoice marked as $action'),
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
  final Color color;

  const _MetaChip({
    required this.label,
    required this.icon,
    this.color = AppTheme.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'paid':
        color = const Color(0xFF10B981);
        break;
      case 'sent':
        color = AppTheme.primary;
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
            letterSpacing: 0.5),
      ),
    );
  }
}
