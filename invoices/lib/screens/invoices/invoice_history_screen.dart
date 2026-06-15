import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/invoice.dart';
import '../../providers/invoice_provider.dart';
import 'invoice_preview_screen.dart';
import 'invoice_stats_screen.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  String _filter = 'alle';
  String _search = '';
  DateTime _statsMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _pickMonth(BuildContext context) async {
    int year = _statsMonth.year;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setDialogState(() => year--),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '$year',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setDialogState(() => year++),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          content: SizedBox(
            width: 280,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: List.generate(12, (i) {
                final month = DateTime(year, i + 1);
                final isSelected = month.year == _statsMonth.year &&
                    month.month == _statsMonth.month;
                return GestureDetector(
                  onTap: () {
                    setState(() => _statsMonth = month);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.borderOf(ctx),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      DateFormat('MMM').format(month),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppTheme.onSurface(ctx),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();
    final invoices = provider.invoices.where((inv) {
      if (_filter != 'alle' && inv.status != _filter) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return inv.invoiceNumber.toLowerCase().contains(q) ||
            inv.clientNaam.toLowerCase().contains(q) ||
            inv.clientKenteken.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: AppTheme.surf(context),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Zoeken op naam, kenteken of nummer...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    fillColor: AppTheme.bg(context),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.borderOf(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.borderOf(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        'alle',
                        'Alle',
                        _filter,
                        () => setState(() => _filter = 'alle'),
                      ),
                      _FilterChip(
                        'concept',
                        'Concept',
                        _filter,
                        () => setState(() => _filter = 'concept'),
                      ),
                      _FilterChip(
                        'verzonden',
                        'Verzonden',
                        _filter,
                        () => setState(() => _filter = 'verzonden'),
                      ),
                      _FilterChip(
                        'betaald',
                        'Betaald',
                        _filter,
                        () => setState(() => _filter = 'betaald'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: AppTheme.surf(context),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Maandoverzicht',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onSurfaceVariant(context),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _pickMonth(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.borderOf(context)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('MMM yyyy').format(_statsMonth),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_drop_down, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _StatsRow(
                  invoices: provider.invoices
                      .where((inv) =>
                          inv.issueDate.year == _statsMonth.year &&
                          inv.issueDate.month == _statsMonth.month)
                      .toList(),
                  onTap: () {
                    final monthInvoices = provider.invoices
                        .where((inv) =>
                            inv.issueDate.year == _statsMonth.year &&
                            inv.issueDate.month == _statsMonth.month)
                        .toList();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => InvoiceStatsScreen(
                        invoices: monthInvoices,
                        month: _statsMonth,
                      ),
                    ));
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: !provider.isLoaded
                ? const Center(child: CircularProgressIndicator())
                : invoices.isEmpty
                ? _EmptyState(filter: _filter, search: _search)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: invoices.length,
                    itemBuilder: (ctx, i) {
                      final invoice = invoices[i];
                      final card = _InvoiceCard(
                        invoice: invoice,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                InvoicePreviewScreen(invoice: invoice),
                          ),
                        ),
                      );
                      if (_filter != 'alle' && _filter != 'concept')
                        return card;
                      final swipeable = _InvoiceCard(
                        invoice: invoice,
                        margin: EdgeInsets.zero,
                        wrapInCard: false,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                InvoicePreviewScreen(invoice: invoice),
                          ),
                        ),
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          elevation: 1,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          color: Theme.of(context).cardColor,
                          child: Dismissible(
                            key: ValueKey(invoice.id),
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              color: Color(0xFF10B981),
                              child: const Icon(
                                Icons.payments_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              color: AppTheme.error,
                              child: const Icon(
                                Icons.delete_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                if (invoice.status == 'betaald') return false;
                                await context
                                    .read<InvoiceProvider>()
                                    .updateStatus(invoice.id, 'betaald');
                                return false;
                              } else {
                                return await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text(
                                          'Factuur verwijderen',
                                        ),
                                        content: Text(
                                          'Wil je ${invoice.invoiceNumber} verwijderen? Dit kan niet ongedaan worden gemaakt.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Annuleren'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppTheme.error,
                                            ),
                                            child: const Text('Verwijderen'),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;
                              }
                            },
                            onDismissed: (direction) {
                              if (direction == DismissDirection.endToStart) {
                                context.read<InvoiceProvider>().deleteInvoice(
                                  invoice.id,
                                );
                              }
                            },
                            child: swipeable,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<Invoice> invoices;
  final VoidCallback? onTap;
  const _StatsRow({required this.invoices, this.onTap});

  static double _fontSize(List<String> values) {
    final longest = values.map((v) => v.length).reduce((a, b) => a > b ? a : b);
    if (longest <= 6) return 15;
    if (longest <= 8) return 13;
    if (longest <= 10) return 11;
    return 9;
  }

  @override
  Widget build(BuildContext context) {
    final total = invoices.fold(0.0, (s, i) => s + i.totaalInclBtw);
    final paid = invoices
        .where((i) => i.status == 'betaald')
        .fold(0.0, (s, i) => s + i.totaalInclBtw);
    final currency = invoices.isNotEmpty ? invoices.first.currency : '€';

    final totalStr = '$currency${total.toStringAsFixed(0)}';
    final paidStr = '$currency${paid.toStringAsFixed(0)}';
    final unpaidStr = '$currency${(total - paid).toStringAsFixed(0)}';
    final countStr = '${invoices.length}';
    final fs = _fontSize([totalStr, paidStr, unpaidStr, countStr]);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _Stat('Totaal', totalStr, AppTheme.onSurface(context), fs),
          ),
          _div(context),
          Expanded(
            flex: 2,
            child: _Stat('Betaald', paidStr, const Color(0xFF10B981), fs),
          ),
          _div(context),
          Expanded(
            flex: 3,
            child: _Stat('Openstaand', unpaidStr, AppTheme.error, fs),
          ),
          _div(context),
          Expanded(
            flex: 2,
            child: _Stat('Aantal', countStr, AppTheme.onSurfaceVariant(context), fs),
          ),
        ],
      ),
    );
  }

  Widget _div(BuildContext context) => Container(
    height: 30,
    width: 1,
    color: AppTheme.borderOf(context),
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  final double fontSize;
  const _Stat(this.label, this.value, this.color, this.fontSize);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
          ),
        ),
      ),
    ],
  );
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  final EdgeInsetsGeometry margin;
  final bool wrapInCard;
  const _InvoiceCard({
    required this.invoice,
    required this.onTap,
    this.margin = const EdgeInsets.only(bottom: 10),
    this.wrapInCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = InkWell(
      onTap: onTap,
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
              child: const Icon(
                Icons.receipt_long,
                color: AppTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        invoice.invoiceNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TappableStatusBadge(invoice: invoice),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    () {
                      final ref = invoice.clientKenteken.isNotEmpty
                          ? invoice.clientKenteken
                          : invoice.clientProductType;
                      return ref.isNotEmpty
                          ? '${invoice.clientNaam} · $ref'
                          : invoice.clientNaam;
                    }(),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    DateFormat('dd-MM-yyyy').format(invoice.issueDate),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${invoice.currency}${invoice.totaalInclBtw.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
    if (!wrapInCard) return content;
    return Card(margin: margin, child: content);
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
          color: selected
              ? AppTheme.primary
              : AppTheme.onSurfaceVariant(context),
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(
          color: selected ? AppTheme.primary : AppTheme.borderOf(context),
        ),
      ),
    );
  }
}

class _TappableStatusBadge extends StatelessWidget {
  final Invoice invoice;
  const _TappableStatusBadge({required this.invoice});

  static const _allStatuses = [
    ('concept', 'Concept'),
    ('verzonden', 'Verzonden'),
    ('betaald', 'Betaald'),
  ];

  static Color _colorFor(String s) => switch (s) {
    'betaald' => const Color(0xFF10B981),
    'verzonden' => AppTheme.primary,
    _ => AppTheme.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(invoice.status);
    final label = invoice.status[0].toUpperCase() + invoice.status.substring(1);

    return PopupMenuButton<String>(
      onSelected: (s) =>
          context.read<InvoiceProvider>().updateStatus(invoice.id, s),
      itemBuilder: (_) => _allStatuses
          .where((s) => s.$1 != invoice.status)
          .map((s) => PopupMenuItem(value: s.$1, child: Text(s.$2)))
          .toList(),
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 12, color: color),
          ],
        ),
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
      case 'betaald':
        color = const Color(0xFF10B981);
        break;
      case 'verzonden':
        color = AppTheme.primary;
        break;
      default:
        color = AppTheme.textSecondary;
    }
    final label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter, search;
  const _EmptyState({required this.filter, required this.search});

  @override
  Widget build(BuildContext context) {
    final isFiltered = filter != 'alle' || search.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppTheme.borderOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'Geen overeenkomende facturen' : 'Nog geen facturen',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Probeer een andere zoekopdracht of filter'
                  : 'Tik op "Nieuwe factuur" om te beginnen',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
