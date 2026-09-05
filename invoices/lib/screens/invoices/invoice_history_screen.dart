import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/invoice.dart';
import '../../providers/business_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../utils/price.dart';
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();
    // Quotes are not invoices: they carry no payment state, so the status
    // filters skip them and the revenue stats leave them out.
    final facturen = provider.invoices.where((i) => !i.isQuote).toList();

    final invoices = provider.invoices.where((inv) {
      if (_filter == 'offerte') {
        if (!inv.isQuote) return false;
      } else if (_filter != 'alle') {
        if (inv.isQuote || inv.status != _filter) return false;
      }
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
                        'betaald',
                        'Betaald',
                        _filter,
                        () => setState(() => _filter = 'betaald'),
                      ),
                      _FilterChip(
                        'offerte',
                        'Offertes',
                        _filter,
                        () => setState(() => _filter = 'offerte'),
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
                Text(
                  'Maandoverzicht',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurfaceVariant(context),
                  ),
                ),
                const SizedBox(height: 8),
                _StatsRow(
                  invoices: facturen
                      .where((inv) =>
                          inv.issueDate.year == DateTime.now().year &&
                          inv.issueDate.month == DateTime.now().month)
                      .toList(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InvoiceStatsScreen(
                        allInvoices: facturen,
                      ),
                    ),
                  ),
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
                      if (_filter != 'alle' && _filter != 'concept') {
                        return card;
                      }
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
                            // Swiping right marks paid, which a quote cannot
                            // be — so it gets no such affordance.
                            background: invoice.isQuote
                                ? const SizedBox.shrink()
                                : Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    color: const Color(0xFF10B981),
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
                                // A quote is not owed, so it cannot be paid.
                                if (invoice.isQuote ||
                                    invoice.status == 'betaald') {
                                  return false;
                                }
                                await context
                                    .read<InvoiceProvider>()
                                    .updateStatus(invoice.id, 'betaald');
                                return false;
                              } else {
                                return await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(
                                          '${invoice.documentLabel} verwijderen',
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
          const Icon(Icons.chevron_right, size: 16, color: AppTheme.textSecondary),
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
                      if (invoice.isQuote)
                        _QuoteBadge(invoice: invoice)
                      else
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
              formatAmountRange(
                invoice.totaalInclBtw,
                invoice.totaalInclBtwMax,
                invoice.currency,
              ),
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
    ('betaald', 'Betaald'),
  ];

  static Color _colorFor(String s) => switch (s) {
    'betaald' => const Color(0xFF10B981),
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

/// A quote has no payment state to toggle, so its badge names the document and
/// offers the one transition it does have: becoming an invoice.
class _QuoteBadge extends StatelessWidget {
  final Invoice invoice;
  const _QuoteBadge({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (_) => convertQuoteToInvoice(context, invoice),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'factuur', child: Text('Omzetten naar factuur')),
      ],
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.primary.withAlpha(26),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              invoice.shortDocumentLabel,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              size: 12,
              color: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Turns [quote] into an invoice, first settling every estimated range: an
/// invoice bills an exact quantity, so "1-4 uur" has to become a number the
/// customer is actually charged for.
Future<void> convertQuoteToInvoice(BuildContext context, Invoice quote) async {
  final ranged = quote.items.where((i) => i.isRange).toList();

  Map<String, double>? quantities = const {};
  if (ranged.isNotEmpty) {
    quantities = await showModalBottomSheet<Map<String, double>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SettleRangesSheet(quote: quote, ranged: ranged),
    );
  } else {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Omzetten naar factuur'),
        content: Text(
          '${quote.documentLabel} ${quote.numberLabel} wordt een factuur en '
          'krijgt het eerstvolgende factuurnummer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Omzetten'),
          ),
        ],
      ),
    );
    if (confirmed != true) quantities = null;
  }

  if (quantities == null || !context.mounted) return;

  final prefix =
      context.read<BusinessProvider>().businessInfo?.invoicePrefix ?? 'F';
  try {
    final invoice = await context.read<InvoiceProvider>().convertToInvoice(
      quote,
      invoicePrefix: prefix,
      quantities: quantities,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Omgezet naar factuur ${invoice.invoiceNumber}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Omzetten mislukt: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.error,
      ),
    );
  }
}

/// Asks for the settled quantity of every estimated item. Each field starts at
/// the low end of its range and has to stay inside it — that span is what the
/// customer was quoted.
class _SettleRangesSheet extends StatefulWidget {
  final Invoice quote;
  final List<InvoiceItem> ranged;
  const _SettleRangesSheet({required this.quote, required this.ranged});

  @override
  State<_SettleRangesSheet> createState() => _SettleRangesSheetState();
}

class _SettleRangesSheetState extends State<_SettleRangesSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final item in widget.ranged)
      item.id: TextEditingController(text: formatPriceInput(item.aantal)),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      for (final entry in _controllers.entries)
        entry.key: double.parse(entry.value.text),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Aantallen vastleggen',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Een factuur rekent een vast aantal. Kies per geschat product '
                'het aantal dat je in rekening brengt.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.onSurfaceVariant(context),
                ),
              ),
              const SizedBox(height: 16),
              ...widget.ranged.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _controllers[item.id],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: item.omschrijving,
                      helperText: 'Geschat: ${item.aantalLabel}',
                      suffixText:
                          '${widget.quote.currency}'
                          '${item.prijsExBtw.toStringAsFixed(2)} p/st',
                    ),
                    validator: (v) {
                      final value = double.tryParse(v ?? '');
                      if (value == null) return 'Ongeldig';
                      if (value < item.aantal || value > item.aantalMax) {
                        return 'Kies tussen ${item.aantalLabel}';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Omzetten naar factuur'),
              ),
            ],
          ),
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
              isFiltered
                  ? 'Geen overeenkomende documenten'
                  : 'Nog geen facturen',
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
