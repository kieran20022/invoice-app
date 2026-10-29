import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../services/purchase_import_service.dart';
import '../../utils/price.dart';

/// Reviews the lines read off a supplier invoice before they go into the
/// Voorraad. Each line shows the product it was matched to and its quantity,
/// both changeable; "Bijboeken" adds the ticked lines to the stock and
/// remembers the shop's wording for every confirmed match. Pops the number of
/// pieces booked.
class PurchaseImportScreen extends StatefulWidget {
  final String fileName;
  final List<PurchaseLine> lines;

  /// The Voorraad's products — the only ones a line can be booked onto.
  final List<Product> products;

  const PurchaseImportScreen({
    super.key,
    required this.fileName,
    required this.lines,
    required this.products,
  });

  @override
  State<PurchaseImportScreen> createState() => _PurchaseImportScreenState();
}

class _Entry {
  final PurchaseLine line;
  final List<({Product product, double score})> ranked;
  Product? product;
  double quantity;
  bool include;

  _Entry(this.line, this.ranked)
      : quantity = line.quantity,
        product = ranked.isNotEmpty && ranked.first.score >= matchThreshold
            ? ranked.first.product
            : null,
        include = ranked.isNotEmpty && ranked.first.score >= matchThreshold;

  double get score =>
      ranked.where((r) => r.product.id == product?.id).firstOrNull?.score ?? 0;
}

class _PurchaseImportScreenState extends State<PurchaseImportScreen> {
  late final List<_Entry> _entries = [
    for (final l in widget.lines) _Entry(l, rankProducts(l, widget.products)),
  ];
  bool _saving = false;

  Iterable<_Entry> get _booked =>
      _entries.where((e) => e.include && e.product != null && e.quantity > 0);

  @override
  Widget build(BuildContext context) {
    final matched = _entries.where((e) => e.product != null).length;
    final booked = _booked.length;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inkoopfactuur'),
            Text(
              widget.fileName,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: booked == 0 || _saving ? null : _book,
            child: Text(booked == 0 ? 'Bijboeken' : 'Bijboeken ($booked)'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            '$matched van ${_entries.length} regels herkend. Controleer de '
            'koppeling en de aantallen; alleen aangevinkte regels worden '
            'bijgeboekt.',
            style: TextStyle(color: AppTheme.onSurfaceVariant(context)),
          ),
          const SizedBox(height: 12),
          for (final e in _entries) ...[
            _LineCard(
              entry: e,
              onChanged: () => setState(() {}),
              onPick: () => _pickProduct(e),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Future<void> _pickProduct(_Entry entry) async {
    final picked = await showModalBottomSheet<({Product? product})>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProductPickerSheet(entry: entry),
    );
    if (picked == null) return;
    setState(() {
      entry.product = picked.product;
      entry.include = picked.product != null;
    });
  }

  Future<void> _book() async {
    setState(() => _saving = true);
    final quantities = <String, double>{};
    final names = <String, Set<String>>{};
    for (final e in _booked) {
      final p = e.product!;
      quantities[p.id] = (quantities[p.id] ?? 0) + e.quantity;
      final name = normalizeSupplierText(e.line.description);
      if (name.isNotEmpty && !p.supplierNames.contains(name)) {
        names.putIfAbsent(p.id, () => {}).add(name);
      }
    }
    try {
      await context
          .read<ProductProvider>()
          .receiveDelivery(quantities, names);
      if (!mounted) return;
      Navigator.pop(context, quantities.values.fold<double>(0, (a, b) => a + b));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bijboeken mislukt: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

class _LineCard extends StatelessWidget {
  final _Entry entry;
  final VoidCallback onChanged;
  final VoidCallback onPick;

  const _LineCard({
    required this.entry,
    required this.onChanged,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final product = entry.product;
    final line = entry.line;
    final score = entry.score;
    final (label, color) = product == null
        ? ('Niet herkend', AppTheme.error)
        : score >= 1
            ? ('Onthouden', AppTheme.cash)
            : score >= 0.85
                ? ('Zeker', AppTheme.cash)
                : ('Controleren', const Color(0xFFF59E0B));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: entry.include && product != null,
                  onChanged: product == null
                      ? null
                      : (v) {
                          entry.include = v ?? false;
                          onChanged();
                        },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.description,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (line.unitPrice != null)
                        Text(
                          '${formatMoney(line.unitPrice!, currency: '€')} per stuk',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant(context),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onPick,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 18,
                              color: product == null
                                  ? AppTheme.onSurfaceVariant(context)
                                  : AppTheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                product?.name ?? 'Kies product…',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: product == null
                                      ? AppTheme.onSurfaceVariant(context)
                                      : AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppTheme.textSecondary,
                    visualDensity: VisualDensity.compact,
                    onPressed: entry.quantity <= 1
                        ? null
                        : () {
                            entry.quantity -= 1;
                            onChanged();
                          },
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _editQuantity(context),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 36),
                      padding: const EdgeInsets.all(6),
                      alignment: Alignment.center,
                      child: Text(
                        formatStock(entry.quantity),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppTheme.primary,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      entry.quantity += 1;
                      onChanged();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editQuantity(BuildContext context) async {
    final ctrl = TextEditingController(text: formatStock(entry.quantity));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) {
        void submit() {
          final v = parseDecimalInput(ctrl.text);
          if (v != null && v > 0) Navigator.pop(ctx, v);
        }

        return AlertDialog(
          title: Text(entry.line.description),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onTap: () => ctrl.selection =
                TextSelection(baseOffset: 0, extentOffset: ctrl.text.length),
            onSubmitted: (_) => submit(),
            decoration: const InputDecoration(labelText: 'Aantal'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuleren'),
            ),
            TextButton(onPressed: submit, child: const Text('Opslaan')),
          ],
        );
      },
    );
    ctrl.dispose();
    if (value != null) {
      entry.quantity = value;
      onChanged();
    }
  }
}

/// Picks the Voorraad product a line is booked onto, best matches first.
/// Pops `(product: null)` for "Niet bijboeken".
class _ProductPickerSheet extends StatefulWidget {
  final _Entry entry;
  const _ProductPickerSheet({required this.entry});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final shown = widget.entry.ranked
        .where((r) => q.isEmpty || r.product.name.toLowerCase().contains(q))
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                widget.entry.line.description,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Zoeken…',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Niet bijboeken'),
              onTap: () => Navigator.pop(context, (product: null)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (_, i) {
                  final r = shown[i];
                  final p = r.product;
                  return ListTile(
                    selected: p.id == widget.entry.product?.id,
                    title: Text(p.name),
                    subtitle: Text(
                      [
                        if (p.category.isNotEmpty)
                          p.subCategory.isEmpty
                              ? p.category
                              : '${p.category} › ${p.subCategory}',
                        'Voorraad ${formatStock(p.stock)}',
                      ].join(' · '),
                    ),
                    trailing: r.score >= 0.2
                        ? Text(
                            '${(r.score * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.onSurfaceVariant(context),
                            ),
                          )
                        : null,
                    onTap: () => Navigator.pop(context, (product: p)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
