import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/invoice.dart';
import '../../providers/invoice_provider.dart';
import 'invoice_preview_screen.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  String _filter = 'all';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();
    final invoices = provider.invoices.where((inv) {
      if (_filter != 'all' && inv.status != _filter) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return inv.invoiceNumber.toLowerCase().contains(q) ||
            inv.clientName.toLowerCase().contains(q) ||
            inv.clientCompany.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Search + Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search invoices...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    fillColor: AppTheme.background,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip('all', 'All', _filter, () => setState(() => _filter = 'all')),
                      _FilterChip('draft', 'Draft', _filter, () => setState(() => _filter = 'draft')),
                      _FilterChip('sent', 'Sent', _filter, () => setState(() => _filter = 'sent')),
                      _FilterChip('paid', 'Paid', _filter, () => setState(() => _filter = 'paid')),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stats row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _StatsRow(invoices: provider.invoices),
          ),

          const Divider(height: 1),

          // Invoice list
          Expanded(
            child: !provider.isLoaded
                ? const Center(child: CircularProgressIndicator())
                : invoices.isEmpty
                    ? _EmptyState(filter: _filter, search: _search)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: invoices.length,
                        itemBuilder: (ctx, i) => _InvoiceCard(
                          invoice: invoices[i],
                          onTap: () => _openInvoice(invoices[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _openInvoice(Invoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoicePreviewScreen(invoice: invoice),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<Invoice> invoices;
  const _StatsRow({required this.invoices});

  @override
  Widget build(BuildContext context) {
    final total = invoices.fold(0.0, (sum, inv) => sum + inv.total);
    final paid = invoices.where((i) => i.status == 'paid').fold(0.0, (s, i) => s + i.total);
    final unpaid = total - paid;
    final currency = invoices.isNotEmpty ? invoices.first.currency : '\$';

    return Row(
      children: [
        _StatItem(
          label: 'Total',
          value: '$currency${total.toStringAsFixed(0)}',
          color: AppTheme.textPrimary,
        ),
        _divider(),
        _StatItem(
          label: 'Paid',
          value: '$currency${paid.toStringAsFixed(0)}',
          color: const Color(0xFF10B981),
        ),
        _divider(),
        _StatItem(
          label: 'Unpaid',
          value: '$currency${unpaid.toStringAsFixed(0)}',
          color: AppTheme.error,
        ),
        _divider(),
        _StatItem(
          label: 'Count',
          value: '${invoices.length}',
          color: AppTheme.textSecondary,
        ),
      ],
    );
  }

  Widget _divider() => Container(
        height: 30,
        width: 1,
        color: AppTheme.border,
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      );
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  const _InvoiceCard({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(invoice.issueDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long,
                    color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(invoice.invoiceNumber,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(width: 8),
                        _StatusBadge(status: invoice.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.clientName +
                          (invoice.clientCompany.isNotEmpty
                              ? ' · ${invoice.clientCompany}'
                              : ''),
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(dateStr,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${invoice.currency}${invoice.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Due ${DateFormat('MMM d').format(invoice.dueDate)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: invoice.dueDate.isBefore(DateTime.now()) &&
                                invoice.status != 'paid'
                            ? AppTheme.error
                            : AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String value, label, current;
  final VoidCallback onTap;

  const _FilterChip(this.value, this.label, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppTheme.primary.withAlpha(26),
        labelStyle: TextStyle(
          color: selected ? AppTheme.primary : AppTheme.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(
            color: selected ? AppTheme.primary : AppTheme.border),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 10),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter, search;
  const _EmptyState({required this.filter, required this.search});

  @override
  Widget build(BuildContext context) {
    final isFiltered = filter != 'all' || search.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 64, color: AppTheme.border),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'No matching invoices' : 'No Invoices Yet',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Try changing your search or filter'
                  : 'Tap the + button to create your first invoice',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
